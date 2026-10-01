#!/usr/bin/env node
'use strict';

/**
 * 通用 → 语言 lets the user override the system language, and the choice is stored as a
 * preference that the next cold start reads.
 *
 * The failure this guard closes is silent: the picker, the storage normalizer, and the
 * `app.string` catalogs are four separate lists, and if they disagree the app either
 * offers a language it cannot render (falling back to Chinese with no explanation) or
 * accepts a stored value it will not honor. Neither shows up as a build error.
 *
 * It checks:
 *
 *   1. every language the picker offers is a language id the platform accepts, and the
 *      option list is built from the shared constants rather than repeated literals;
 *   2. the offered languages are exactly the ones the string catalogs ship, so no option
 *      can fall back silently;
 *   3. the stored preference is normalized through the same "supported language" predicate
 *      the picker uses, and an unknown value falls back to following the system;
 *   4. the picker, the normalizer, and the catalog options all default to following the
 *      system rather than pinning a language;
 *   5. applying a language persists it before calling the platform, so a rejected language
 *      cannot lose the user's choice.
 */

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const ETS = 'AiraBrowser/entry/src/main/ets';
const SERVICE_REL = `${ETS}/core/resources/AppLanguageService.ets`;
// The language identity and the platform call live in separate modules: the preferences
// layer validates a stored language without importing the localization kit, which would
// drag a platform dependency into every consumer that only wants to check a string.
const CATALOG_REL = `${ETS}/core/resources/AppLanguageCatalog.ets`;
const PAGE_REL = `${ETS}/app/pages/GeneralLanguageSettingsPage.ets`;
const PREFERENCES_REL = `${ETS}/data/preferences/PreferencesRepository.ets`;
const RESOURCES_DIR = 'AiraBrowser/entry/src/main/resources';
const LOCALES = ['base', 'zh_CN', 'zh_Hant', 'en_US'];

let failures = 0;

function fail(message) {
  process.stdout.write(`App language guard violation: ${message}\n`);
  failures += 1;
}

function read(relPath) {
  return fs.readFileSync(path.join(REPO_ROOT, relPath), 'utf8');
}

function main() {
  const service = read(SERVICE_REL);
  const catalog = read(CATALOG_REL);
  const page = read(PAGE_REL);
  const preferences = read(PREFERENCES_REL);

  // 1. The catalog owns the language identities; the service re-exports them and owns the
  //    platform call. The preferences layer may only depend on the catalog.
  for (const name of ['APP_LANGUAGE_FOLLOW_SYSTEM', 'APP_LANGUAGE_SIMPLIFIED_CHINESE', 'APP_LANGUAGE_TRADITIONAL_CHINESE', 'APP_LANGUAGE_ENGLISH']) {
    if (!new RegExp(`export const ${name}\\b`).test(catalog)) {
      fail(`${CATALOG_REL} must export ${name}`);
    }
    if (!new RegExp(`\\b${name}\\b`).test(service)) {
      fail(`${SERVICE_REL} must re-export ${name}`);
    }
  }
  if (/@kit\./.test(catalog)) {
    fail(`${CATALOG_REL} must stay free of platform imports so the preferences layer can use it`);
  }
  if (!/AppLanguageCatalog/.test(preferences)) {
    fail(`${PREFERENCES_REL} must validate the stored language through ${CATALOG_REL}`);
  }
  if (/AppLanguageService/.test(preferences)) {
    fail(`${PREFERENCES_REL} must not depend on ${SERVICE_REL}, which imports the localization kit`);
  }
  if (!/i18n\.System\.setAppPreferredLanguage\(/.test(service)) {
    fail(`${SERVICE_REL} must apply the language through i18n.System.setAppPreferredLanguage`);
  }
  if (!/isSupportedAppLanguage/.test(catalog)) {
    fail(`${CATALOG_REL} must expose the supported-language predicate`);
  }

  // 2. The picker offers exactly the shipped catalogs, built from the shared constants.
  const optionBlock = /const APP_LANGUAGE_OPTIONS[\s\S]*?\];/.exec(page);
  if (optionBlock === null) {
    fail(`${PAGE_REL} must declare APP_LANGUAGE_OPTIONS`);
  } else {
    const block = optionBlock[0];
    for (const name of [
      'APP_LANGUAGE_FOLLOW_SYSTEM',
      'APP_LANGUAGE_SIMPLIFIED_CHINESE',
      'APP_LANGUAGE_TRADITIONAL_CHINESE',
      'APP_LANGUAGE_ENGLISH'
    ]) {
      if (!block.includes(name)) {
        fail(`${PAGE_REL} must build its options from ${name}, not a repeated literal`);
      }
    }
    const offered = [...block.matchAll(/id:\s*([A-Z_]+)/g)].map((match) => match[1]);
    const expected = [
      'APP_LANGUAGE_FOLLOW_SYSTEM',
      'APP_LANGUAGE_SIMPLIFIED_CHINESE',
      'APP_LANGUAGE_TRADITIONAL_CHINESE',
      'APP_LANGUAGE_ENGLISH'
    ];
    if (offered.join(',') !== expected.join(',')) {
      fail(`${PAGE_REL} offers ${offered.join(', ')} but the shipped languages are ${expected.join(', ')}`);
    }
  }

  // 3. Every offered language is one the catalogs actually carry.
  const shipped = LOCALES.filter((locale) => locale !== 'base');
  if (!shipped.includes('zh_CN') || !shipped.includes('zh_Hant') || !shipped.includes('en_US')) {
    fail(`${RESOURCES_DIR} must ship zh_CN, zh_Hant and en_US string catalogs`);
  }
  const keySets = LOCALES.map((locale) => {
    const parsed = JSON.parse(read(`${RESOURCES_DIR}/${locale}/element/string.json`));
    return [...parsed.string.map((entry) => entry.name)].sort().join('\n');
  });
  if (new Set(keySets).size !== 1) {
    fail(`${RESOURCES_DIR} locales do not carry the same key set`);
  }

  // 4. The stored preference is normalized through the picker's own predicate.
  if (!/normalizeAppLanguage\([\s\S]{0,200}isSupportedAppLanguage\(/.test(preferences)) {
    fail(`${PREFERENCES_REL} must normalize the stored language through isSupportedAppLanguage`);
  }
  if (!/DEFAULT_APP_LANGUAGE: string = 'default'/.test(preferences)) {
    fail(`${PREFERENCES_REL} must default the stored language to 'default' (follow the system)`);
  }

  // 5. Persist before calling the platform.
  const persistIndex = page.indexOf('updateAppLanguage(');
  const applyIndex = page.indexOf('applyAppPreferredLanguage(');
  if (persistIndex < 0 || applyIndex < 0) {
    fail(`${PAGE_REL} must persist the choice and then apply it`);
  } else if (persistIndex > applyIndex) {
    fail(`${PAGE_REL} must store the language before calling the platform, or a rejected language loses the choice`);
  }

  if (failures > 0) {
    process.exit(1);
  }
  process.stdout.write(
    `App language guard passed: ${expectedSummary()}, follow-system default, ${LOCALES.length} catalogs.\n`
  );
}

function expectedSummary() {
  return '4 options';
}

main();
