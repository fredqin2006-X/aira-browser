import { i18n } from '@kit.LocalizationKit';

/**
 * The system language in lower case, or `''` when it cannot be read.
 *
 * `rawfile` does not take part in resource-qualifier matching the way `string.json` does,
 * so a document that ships in more than one language has to pick its file explicitly. This
 * is that decision's only input, and it is read once per call so a language change lands on
 * the next document build rather than on the next launch.
 */
export function resolveSystemLanguage(): string {
  try {
    return i18n.System.getSystemLanguage().trim().toLowerCase();
  } catch (_error) {
    return '';
  }
}

/** True when the system language is English. */
export function isEnglishSystemLanguage(): boolean {
  return resolveSystemLanguage().startsWith('en');
}

/**
 * Picks between a base document and its English counterpart, mirroring the `base` /
 * `en_US` relationship the string catalogs use: English reads the English file, every
 * other language reads the base file. The base file is the Chinese one, matching
 * `string.json`, where `base` and `zh_CN` carry the same values.
 */
export function resolveLocalizedRawFileName(baseName: string, englishName: string): string {
  return isEnglishSystemLanguage() ? englishName : baseName;
}
