const crypto = require('crypto');
const fs = require('fs');
const { db } = require('./db/database');
const { pairingCodeTtlMs, setupCodePath } = require('./config');
const { fail } = require('./errors');

const DEVICE_ID_PATTERN = /^[A-Za-z0-9._-]{1,160}$/;
const getInstanceStatement = db.prepare('SELECT instance_id, created_at FROM instance_meta WHERE singleton = 1');
const insertInstanceStatement = db.prepare(
  'INSERT INTO instance_meta(singleton, instance_id, created_at) VALUES(1, ?, ?)'
);
const insertPairingCodeStatement = db.prepare(`
  INSERT INTO pairing_codes(code_hash, kind, created_by_device_id, created_at, expires_at, used_at)
  VALUES(@code_hash, @kind, @created_by_device_id, @created_at, @expires_at, 0)
`);
const consumePairingCodeStatement = db.prepare(`
  UPDATE pairing_codes SET used_at = @used_at
  WHERE code_hash = @code_hash AND used_at = 0 AND expires_at >= @used_at
`);
const getPairingCodeStatement = db.prepare(
  'SELECT kind FROM pairing_codes WHERE code_hash = ? AND used_at = 0 AND expires_at >= ?'
);
const getOwnerCodeStatement = db.prepare(
  "SELECT code_hash FROM pairing_codes WHERE kind = 'owner' AND used_at = 0 LIMIT 1"
);
const promoteBootstrapCodeStatement = db.prepare(`
  UPDATE pairing_codes
  SET kind = 'owner', used_at = 0, expires_at = ?
  WHERE code_hash = ? AND kind = 'bootstrap'
`);
const deleteOwnerCodesStatement = db.prepare("DELETE FROM pairing_codes WHERE kind = 'owner'");
const getDeviceByIdStatement = db.prepare('SELECT device_id FROM devices WHERE device_id = ?');
const replaceDeviceCredentialStatement = db.prepare(`
  UPDATE devices
  SET credential_id = @credential_id,
      token_hash = @token_hash,
      name = @name,
      device_kind = @device_kind,
      last_seen_at = @last_seen_at,
      rotated_at = @rotated_at,
      revoked_at = 0
  WHERE device_id = @device_id
`);
const OWNER_CODE_EXPIRES_AT = 9007199254740991;
const insertDeviceStatement = db.prepare(`
  INSERT INTO devices(
    device_id, credential_id, token_hash, name, created_at, last_seen_at, rotated_at, revoked_at, device_kind
  ) VALUES(@device_id, @credential_id, @token_hash, @name, @created_at, @last_seen_at, 0, 0, @device_kind)
`);
const authenticateStatement = db.prepare(`
  SELECT device_id, credential_id, name, created_at, last_seen_at, rotated_at, device_kind
  FROM devices WHERE token_hash = ? AND revoked_at = 0
`);
const touchDeviceStatement = db.prepare('UPDATE devices SET last_seen_at = ? WHERE device_id = ? AND revoked_at = 0');
const listDevicesStatement = db.prepare(`
  SELECT device_id, credential_id, name, created_at, last_seen_at, rotated_at, revoked_at, device_kind
  FROM devices ORDER BY created_at ASC, device_id ASC
`);
const revokeDeviceStatement = db.prepare(
  'UPDATE devices SET revoked_at = ? WHERE device_id = ? AND revoked_at = 0'
);
const rotateDeviceStatement = db.prepare(`
  UPDATE devices SET credential_id = @credential_id, token_hash = @token_hash, rotated_at = @rotated_at
  WHERE device_id = @device_id AND revoked_at = 0
`);

function initializeInstance() {
  const existing = getInstanceStatement.get();
  if (existing) {
    ensureOwnerPairingCode();
    return existing;
  }
  const now = Date.now();
  const instanceId = `aira_${crypto.randomUUID()}`;
  const setupCode = createReadableCode();
  db.transaction(() => {
    insertInstanceStatement.run(instanceId, now);
    insertOwnerPairingCode(setupCode, now);
  })();
  writeSetupCodeFile(setupCode, false);
  return { instance_id: instanceId, created_at: now, setupCode };
}

function ensureOwnerPairingCode() {
  const fileCode = readSetupCodeFile();
  const fileHash = fileCode ? hashSecret(fileCode) : '';
  const owner = getOwnerCodeStatement.get();
  if (owner && fileHash === owner.code_hash) return;
  if (fileHash && promoteBootstrapCodeStatement.run(OWNER_CODE_EXPIRES_AT, fileHash).changes === 1) return;
  if (fileHash && getOwnerCodeStatement.get()?.code_hash === fileHash) return;
  replaceOwnerPairingCode();
}

function replaceOwnerPairingCode() {
  const now = Date.now();
  const setupCode = createReadableCode();
  db.transaction(() => {
    deleteOwnerCodesStatement.run();
    insertOwnerPairingCode(setupCode, now);
  })();
  writeSetupCodeFile(setupCode, true);
}

function insertOwnerPairingCode(setupCode, now) {
  insertPairingCodeStatement.run({
    code_hash: hashSecret(setupCode),
    kind: 'owner',
    created_by_device_id: '',
    created_at: now,
    expires_at: OWNER_CODE_EXPIRES_AT,
  });
}

function readSetupCodeFile() {
  try {
    return fs.readFileSync(setupCodePath, 'utf8').trim();
  } catch {
    return '';
  }
}

function writeSetupCodeFile(setupCode, overwrite) {
  fs.writeFileSync(setupCodePath, `${setupCode}\n`, {
    encoding: 'utf8',
    mode: 0o600,
    flag: overwrite ? 'w' : 'wx',
  });
  fs.chmodSync(setupCodePath, 0o600);
}

function exchangePairingCode(body) {
  const code = requireString(body.code, 'missing_pairing_code', 'Pairing code is required.', 128);
  const deviceId = requireDeviceId(body.deviceId);
  const deviceName = requireString(body.deviceName, 'missing_device_name', 'Device name is required.', 128);
  const deviceKind = normalizeDeviceKind(body.deviceKind);
  const now = Date.now();
  const codeHash = hashSecret(code);
  const pairing = getPairingCodeStatement.get(codeHash, now);
  if (!pairing) fail(401, 'invalid_pairing_code', 'Pairing code is invalid, expired, or already used.');
  const token = crypto.randomBytes(32).toString('base64url');
  const credentialId = crypto.randomUUID();
  try {
    db.transaction(() => {
      if (pairing.kind !== 'owner' &&
        consumePairingCodeStatement.run({ code_hash: codeHash, used_at: now }).changes !== 1) {
        fail(409, 'pairing_code_used', 'Pairing code was already used.');
      }
      const credential = {
        device_id: deviceId,
        credential_id: credentialId,
        token_hash: hashSecret(token),
        name: deviceName,
        device_kind: deviceKind,
        created_at: now,
        last_seen_at: now,
        rotated_at: now,
      };
      if (getDeviceByIdStatement.get(deviceId)) {
        if (replaceDeviceCredentialStatement.run(credential).changes !== 1) {
          fail(404, 'device_not_found', 'Paired device was not found.');
        }
        return;
      }
      insertDeviceStatement.run(credential);
    })();
  } catch (error) {
    if (String(error && error.code || '').startsWith('SQLITE_CONSTRAINT')) {
      fail(409, 'device_already_paired', 'This device ID is already paired.');
    }
    throw error;
  }
  return {
    instanceId: getInstance().instanceId,
    protocolVersion: 1,
    deviceId,
    deviceKind,
    credentialId,
    token,
  };
}

function authenticate(request) {
  const value = String(request.headers.authorization || '').trim();
  if (!value.startsWith('Bearer ')) fail(401, 'missing_device_credential', 'Device credential is required.');
  const token = value.slice('Bearer '.length).trim();
  if (!token) fail(401, 'missing_device_credential', 'Device credential is required.');
  const device = authenticateStatement.get(hashSecret(token));
  if (!device) fail(401, 'invalid_device_credential', 'Device credential is invalid or revoked.');
  touchDeviceStatement.run(Date.now(), device.device_id);
  return toDevice(device);
}

function createPairingCode(device) {
  const now = Date.now();
  const code = createReadableCode();
  insertPairingCodeStatement.run({
    code_hash: hashSecret(code),
    kind: 'device',
    created_by_device_id: device.deviceId,
    created_at: now,
    expires_at: now + pairingCodeTtlMs,
  });
  return { code, expiresAt: now + pairingCodeTtlMs };
}

function listDevices() {
  return listDevicesStatement.all().map(toDevice);
}

function revokeDevice(deviceId) {
  const normalized = requireDeviceId(deviceId);
  if (revokeDeviceStatement.run(Date.now(), normalized).changes !== 1) {
    fail(404, 'device_not_found', 'Active device was not found.');
  }
}

function rotateCredential(device) {
  const token = crypto.randomBytes(32).toString('base64url');
  const credentialId = crypto.randomUUID();
  const now = Date.now();
  if (rotateDeviceStatement.run({
    credential_id: credentialId,
    token_hash: hashSecret(token),
    rotated_at: now,
    device_id: device.deviceId,
  }).changes !== 1) {
    fail(404, 'device_not_found', 'Active device was not found.');
  }
  return { deviceId: device.deviceId, credentialId, token, rotatedAt: now };
}

function getInstance() {
  const row = getInstanceStatement.get();
  return { instanceId: row.instance_id, createdAt: row.created_at };
}

function hashSecret(value) {
  return crypto.createHash('sha256').update(value, 'utf8').digest('hex');
}

function createReadableCode() {
  return crypto.randomBytes(18).toString('base64url').toUpperCase();
}

function requireDeviceId(value) {
  const normalized = String(value || '').trim();
  if (!DEVICE_ID_PATTERN.test(normalized)) {
    fail(400, 'invalid_device_id', 'Device ID must use 1-160 letters, numbers, dots, underscores, or hyphens.');
  }
  return normalized;
}

function requireString(value, code, message, maxLength) {
  const normalized = String(value || '').trim();
  if (!normalized || normalized.length > maxLength) fail(400, code, message);
  return normalized;
}

function normalizeDeviceKind(value) {
  const normalized = String(value || 'phone').trim().toLowerCase();
  if (normalized !== 'phone' && normalized !== 'desktop') {
    fail(400, 'invalid_device_kind', 'Device kind must be phone or desktop.');
  }
  return normalized;
}

function toDevice(row) {
  return {
    deviceId: row.device_id,
    credentialId: row.credential_id,
    name: row.name,
    deviceKind: row.device_kind === 'desktop' ? 'desktop' : 'phone',
    createdAt: Number(row.created_at || 0),
    lastSeenAt: Number(row.last_seen_at || 0),
    rotatedAt: Number(row.rotated_at || 0),
    revokedAt: Number(row.revoked_at || 0),
  };
}

module.exports = {
  authenticate,
  createPairingCode,
  exchangePairingCode,
  getInstance,
  initializeInstance,
  listDevices,
  revokeDevice,
  rotateCredential,
};
