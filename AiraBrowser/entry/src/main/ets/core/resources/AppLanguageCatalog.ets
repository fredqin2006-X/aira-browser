/**
 * The languages the app ships UI strings for, and the identity the preference stores.
 *
 * This module is deliberately free of platform imports: the preferences layer validates a
 * stored language through it, and a platform dependency there would drag the localization
 * kit into every consumer that only wants to check a string. The platform calls live in
 * {@link AppLanguageService}.
 *
 * `base` and `zh_CN` carry the same Chinese values, so Simplified Chinese is one option,
 * not two. `zh_Hant` carries the Traditional Chinese catalog and covers both Taiwan and
 * Hong Kong system locales. Every other system language falls back to `base`, which is why
 * the picker offers exactly these and why `default` (follow the system) is the default
 * choice.
 */
export const APP_LANGUAGE_SIMPLIFIED_CHINESE: string = 'zh-Hans';
export const APP_LANGUAGE_TRADITIONAL_CHINESE: string = 'zh-Hant';
export const APP_LANGUAGE_ENGLISH: string = 'en';
/** Sentinel meaning "follow the system language". */
export const APP_LANGUAGE_FOLLOW_SYSTEM: string = 'default';

const SUPPORTED_APP_LANGUAGES: string[] = [
  APP_LANGUAGE_FOLLOW_SYSTEM,
  APP_LANGUAGE_SIMPLIFIED_CHINESE,
  APP_LANGUAGE_TRADITIONAL_CHINESE,
  APP_LANGUAGE_ENGLISH
];

/** True when the stored preference is one the picker can offer. */
export function isSupportedAppLanguage(value: string): boolean {
  return SUPPORTED_APP_LANGUAGES.indexOf(`${value ?? ''}`.trim()) >= 0;
}

/**
 * Maps the stored preference onto the value `setAppPreferredLanguage` accepts.
 *
 * The stored value and the API value are the same today; the mapping exists so the
 * preference stays a stable app-level identity if the platform's language id ever differs.
 */
export function resolveAppPreferredLanguage(preference: string): string {
  return isSupportedAppLanguage(preference) ? `${preference}`.trim() : APP_LANGUAGE_FOLLOW_SYSTEM;
}
