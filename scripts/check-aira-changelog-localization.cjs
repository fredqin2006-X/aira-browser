#!/usr/bin/env node
'use strict';

/**
 * The changelog ships in two languages: `changelog.md` / `community-changelog.md` are the
 * Chinese documents and `changelog_en.md` / `community-changelog_en.md` are their English
 * counterparts. `release_notice.json` / `release_notice_en.json` follow the same pairing.
 *
 * An English device reads the English document and falls back to Chinese only for a version
 * the English file does not carry, so the English file is expected to translate every
 * version the Chinese one still ships. The failure this guard closes is a new `## <version>`
 * section added to one language only: the app builds, the Chinese changelog is complete, and
 * an English device silently gets a Chinese section — or a shorter changelog.
 *
 * It checks:
 *
 *   1. each English document exists;
 *   2. both documents carry the same version headings, in the same order;
 *   3. each shared version carries the same bullet count, so no item is dropped in translation;
 *   4. the English document carries a summary line for every version;
 *   5. each release notice exists in both languages with matching item counts;
 *   6. the English release notice's noticeId agrees with the base one, so the pair cannot
 *      drift onto different releases.
 *
 * A version that exists only in the English file is allowed (a forward-dated entry), and the
 * service appends it; a version that exists only in the base file is reported, because that
 * is the case the fallback would hide.
 */

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const RAWFILE = 'AiraBrowser/entry/src/main/resources/rawfile';
const DOCUMENT_PAIRS = [
  { base: 'changelog.md', english: 'changelog_en.md' },
  { base: 'community-changelog.md', english: 'community-changelog_en.md' }
];
const NOTICE_PAIRS = [
  { base: 'release_notice.json', english: 'release_notice_en.json' }
];

let failures = 0;

function fail(message) {
  process.stdout.write(`Changelog localization violation: ${message}\n`);
  failures += 1;
}

function readRawFile(name) {
  return fs.readFileSync(path.join(REPO_ROOT, RAWFILE, name), 'utf8');
}

function rawFileExists(name) {
  return fs.existsSync(path.join(REPO_ROOT, RAWFILE, name));
}

const VERSION_HEADING = /^##\s+(\S+)\s+\((\d+)\)\s*$/;
const DATE_LINE = /^\d{4}-\d{2}-\d{2}$/;

/** Splits a changelog into its `## <version> (<code>)` sections. */
function splitSections(markdown) {
  const sections = [];
  let current = undefined;
  for (const line of markdown.split(/\r?\n/)) {
    const match = VERSION_HEADING.exec(line.trim());
    if (match !== null) {
      current = { versionName: match[1], versionCode: match[2], summary: '', bullets: [] };
      sections.push(current);
      continue;
    }
    if (current === undefined) {
      continue;
    }
    const trimmed = line.trim();
    if (trimmed.length === 0 || DATE_LINE.test(trimmed)) {
      continue;
    }
    if (trimmed.startsWith('- ')) {
      current.bullets.push(trimmed.substring(2).trim());
      continue;
    }
    if (current.summary.length === 0) {
      current.summary = trimmed;
    }
  }
  return sections;
}

function sectionKey(section) {
  return `${section.versionName} (${section.versionCode})`;
}

function checkDocumentPair(pair) {
  for (const name of [pair.base, pair.english]) {
    if (!rawFileExists(name)) {
      fail(`${RAWFILE}/${name} is missing`);
      return;
    }
  }
  const baseSections = splitSections(readRawFile(pair.base));
  const englishSections = splitSections(readRawFile(pair.english));
  if (baseSections.length === 0) {
    fail(`${RAWFILE}/${pair.base} has no version section`);
    return;
  }

  const englishByKey = new Map();
  for (const section of englishSections) {
    englishByKey.set(sectionKey(section), section);
  }

  const untranslated = [];
  for (const section of baseSections) {
    const key = sectionKey(section);
    const english = englishByKey.get(key);
    if (english === undefined) {
      untranslated.push(key);
      continue;
    }
    if (english.summary.length === 0) {
      fail(`${RAWFILE}/${pair.english} ${key} has no summary line`);
    }
    // The bullet count must match the base exactly. A base section with no bullet (an
    // early release that only had a summary line) legitimately translates to none, so the
    // count is the contract and an absolute minimum would reject a faithful translation.
    if (english.bullets.length !== section.bullets.length) {
      fail(
        `${RAWFILE}/${pair.english} ${key} has ${english.bullets.length} bullet(s) but ` +
        `${RAWFILE}/${pair.base} has ${section.bullets.length}`
      );
    }
  }
  if (untranslated.length > 0) {
    fail(
      `${RAWFILE}/${pair.english} does not translate ${untranslated.length} version(s) that ` +
      `${RAWFILE}/${pair.base} still ships: ${untranslated.join(', ')}`
    );
  }

  // An English-only version is legal, but it must be a complete section too.
  const baseKeys = new Set(baseSections.map(sectionKey));
  for (const section of englishSections) {
    if (baseKeys.has(sectionKey(section))) {
      continue;
    }
    if (section.summary.length === 0) {
      fail(`${RAWFILE}/${pair.english} ${sectionKey(section)} is English-only and has no summary`);
    }
  }

  const baseOrder = baseSections.map(sectionKey).join(' | ');
  const englishOrder = englishSections
    .map(sectionKey)
    .filter((key) => baseKeys.has(key))
    .join(' | ');
  if (englishOrder !== baseOrder) {
    fail(
      `${RAWFILE}/${pair.english} orders the shared versions differently from ` +
      `${RAWFILE}/${pair.base}`
    );
  }
}

function checkNoticePair(pair) {
  for (const name of [pair.base, pair.english]) {
    if (!rawFileExists(name)) {
      fail(`${RAWFILE}/${name} is missing`);
      return;
    }
  }
  let base;
  let english;
  try {
    base = JSON.parse(readRawFile(pair.base));
    english = JSON.parse(readRawFile(pair.english));
  } catch (error) {
    fail(`${RAWFILE}/${pair.base} or ${RAWFILE}/${pair.english} is not valid JSON: ${error.message}`);
    return;
  }
  const baseItems = Array.isArray(base.items) ? base.items : [];
  const englishItems = Array.isArray(english.items) ? english.items : [];
  if (englishItems.length !== baseItems.length) {
    fail(
      `${RAWFILE}/${pair.english} carries ${englishItems.length} item(s) but ` +
      `${RAWFILE}/${pair.base} carries ${baseItems.length}`
    );
  }
  for (const field of ['summary', 'title', 'actionLabel']) {
    const value = `${english[field] ?? ''}`.trim();
    if (value.length === 0) {
      fail(`${RAWFILE}/${pair.english} has no ${field}`);
    }
  }
  const baseNoticeId = `${base.noticeId ?? ''}`.trim();
  const englishNoticeId = `${english.noticeId ?? ''}`.trim();
  if (baseNoticeId !== englishNoticeId) {
    fail(
      `${RAWFILE}/${pair.english} noticeId ${JSON.stringify(englishNoticeId)} does not match ` +
      `${RAWFILE}/${pair.base} noticeId ${JSON.stringify(baseNoticeId)}`
    );
  }
}

function main() {
  for (const pair of DOCUMENT_PAIRS) {
    checkDocumentPair(pair);
  }
  for (const pair of NOTICE_PAIRS) {
    checkNoticePair(pair);
  }
  if (failures > 0) {
    process.exit(1);
  }
  const counts = DOCUMENT_PAIRS.map((pair) => {
    return `${pair.base}=${splitSections(readRawFile(pair.base)).length}`;
  });
  process.stdout.write(`Changelog localization guard passed: ${counts.join(', ')}, both languages.\n`);
}

main();
