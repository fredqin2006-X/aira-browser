import { i18n } from '@kit.LocalizationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  APP_LANGUAGE_FOLLOW_SYSTEM,
  isSupportedAppLanguage,
  resolveAppPreferredLanguage
} from './AppLanguageCatalog';

export {
  APP_LANGUAGE_ENGLISH,
  APP_LANGUAGE_FOLLOW_SYSTEM,
  APP_LANGUAGE_SIMPLIFIED_CHINESE,
  APP_LANGUAGE_TRADITIONAL_CHINESE,
  isSupportedAppLanguage,
  resolveAppPreferredLanguage
} from './AppLanguageCatalog';

/**
 * Reads the language the app is actually rendering in right now.
 *
 * `getAppPreferredLanguage` returns `default` when the app follows the system, and the
 * platform's own language id otherwise. A failed read returns the raw preference, so the
 * picker can still show the user's stored choice rather than an empty label.
 */
export function resolveEffectiveAppLanguage(preference: string): string {
  try {
    const effective = i18n.System.getAppPreferredLanguage().trim();
    return effective.length > 0 ? effective : preference;
  } catch (_error) {
    return preference;
  }
}

/**
 * Applies a language preference to the running app.
 *
 * The platform takes the change on the next cold start, so the caller is responsible for
 * telling the user that a restart is required. Setting `default` restores the follow-system
 * behavior. Returns true when the platform accepted the value.
 */
export function applyAppPreferredLanguage(preference: string): boolean {
  const language: string = isSupportedAppLanguage(preference)
    ? resolveAppPreferredLanguage(preference)
    : APP_LANGUAGE_FOLLOW_SYSTEM;
  try {
    i18n.System.setAppPreferredLanguage(language);
    return true;
  } catch (error) {
    const businessError = error as BusinessError;
    console.error(`setAppPreferredLanguage failed: ${businessError.code} ${businessError.message}`);
    return false;
  }
}
