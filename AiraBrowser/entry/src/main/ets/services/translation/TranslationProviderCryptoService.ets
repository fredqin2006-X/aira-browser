import { resolveAppResourceText } from '../../core/resources/AppResourceText';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

export class TranslationProviderCryptoService {
  private encoder: util.TextEncoder = util.TextEncoder.create('utf-8');
  private base64Helper: util.Base64Helper = new util.Base64Helper();

  md5Hex(value: string): string {
    return this.digestHex('MD5', value);
  }

  sha256Hex(value: string): string {
    return this.digestHex('SHA256', value);
  }

  hmacSha1Base64(key: string, value: string): string {
    return this.base64Helper.encodeToStringSync(this.hmac('SHA1', key, value));
  }

  hmacSha256Hex(key: string, value: string): string {
    return this.toHex(this.hmac('SHA256', key, value));
  }

  hmacSha256Bytes(key: Uint8Array, value: string): Uint8Array {
    return this.hmacBytes('SHA256', key, this.encoder.encodeInto(value));
  }

  utf8(value: string): Uint8Array {
    return this.encoder.encodeInto(value);
  }

  toHex(bytes: Uint8Array): string {
    let result = '';
    for (let index = 0; index < bytes.length; index += 1) {
      result += bytes[index].toString(16).padStart(2, '0');
    }
    return result;
  }

  private digestHex(algorithm: string, value: string): string {
    const md = cryptoFramework.createMd(algorithm);
    md.updateSync({ data: this.encoder.encodeInto(value) });
    return this.toHex(this.readBlobData(md.digestSync(), resolveAppResourceText($r('app.string.translation_crypto_digest_label', algorithm))));
  }

  private hmac(algorithmName: string, key: string, value: string): Uint8Array {
    return this.hmacBytes(algorithmName, this.encoder.encodeInto(key), this.encoder.encodeInto(value));
  }

  private hmacBytes(algorithmName: string, key: Uint8Array, value: Uint8Array): Uint8Array {
    const blockSize = 64;
    let normalizedKey = key;
    if (normalizedKey.length > blockSize) {
      normalizedKey = this.digestBytes(algorithmName, normalizedKey);
    }
    const paddedKey = new Uint8Array(blockSize);
    paddedKey.set(normalizedKey, 0);
    const outerKeyPad = new Uint8Array(blockSize);
    const innerKeyPad = new Uint8Array(blockSize);
    for (let index = 0; index < blockSize; index += 1) {
      outerKeyPad[index] = paddedKey[index] ^ 0x5c;
      innerKeyPad[index] = paddedKey[index] ^ 0x36;
    }
    const innerDigest = this.digestBytes(algorithmName, this.concatBytes(innerKeyPad, value));
    return this.digestBytes(algorithmName, this.concatBytes(outerKeyPad, innerDigest));
  }

  private digestBytes(algorithm: string, value: Uint8Array): Uint8Array {
    try {
      const md = cryptoFramework.createMd(algorithm);
      md.updateSync({ data: value });
      return this.readBlobData(md.digestSync(), resolveAppResourceText($r('app.string.translation_crypto_digest_label', algorithm)));
    } catch (error) {
      throw new Error(resolveAppResourceText($r(
        'app.string.translation_crypto_digest_unavailable',
        algorithm,
        this.stringifyErrorDetail(error)
      )));
    }
  }

  private concatBytes(left: Uint8Array, right: Uint8Array): Uint8Array {
    const merged = new Uint8Array(left.length + right.length);
    merged.set(left, 0);
    merged.set(right, left.length);
    return merged;
  }

  private readBlobData(blob: Object | null, label: string): Uint8Array {
    if (blob === null || blob === undefined) {
      throw new Error(resolveAppResourceText($r('app.string.translation_crypto_empty_result', label)));
    }
    const data = (blob as cryptoFramework.DataBlob).data;
    if (data === null || data === undefined) {
      throw new Error(resolveAppResourceText($r('app.string.translation_crypto_no_data', label)));
    }
    return data;
  }

  private stringifyErrorDetail(error: Object): string {
    if (error instanceof Error && error.message.length > 0) {
      return `（${error.message}）`;
    }
    return '';
  }
}
