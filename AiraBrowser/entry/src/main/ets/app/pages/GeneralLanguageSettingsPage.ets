import { DEFAULT_THEME_PALETTE } from '../../features/theme/palettes/DefaultThemePalette';
import {
  sharedPreferencesRepository
} from '../bootstrap/BrowserAppRuntime';
import { SettingsOptionRow } from '../components/settings/SettingsRows';
import { SettingsHdsScaffold } from '../components/settings/SettingsHdsScaffold';
import {
  SettingsFooterText,
  SettingsGroupCard,
  SettingsGroupDivider,
  SettingsScrollBody,
  SettingsSection
} from '../components/settings/SettingsLayout';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_DIVIDER_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../core/theme/BrowserThemeStorageKeys';
import { SettingsNavigationCoordinator } from '../router/SettingsNavigationCoordinator';
import { readBrowserBoundaryRouteState } from '../../common/utils/RouteParamUtils';
import { AppModeSwitchRestartService } from '../../services/settings/AppModeSwitchRestartService';
import {
  APP_LANGUAGE_ENGLISH,
  APP_LANGUAGE_FOLLOW_SYSTEM,
  APP_LANGUAGE_SIMPLIFIED_CHINESE
} from '../../core/resources/AppLanguageCatalog';
import {
  applyAppPreferredLanguage,
  resolveEffectiveAppLanguage
} from '../../core/resources/AppLanguageService';

interface AppLanguageOption {
  id: string;
  title: ResourceStr;
}

/**
 * The languages the app ships. `default` follows the system; the other two are the
 * catalogs that exist. A language the app does not carry is not offered, because picking
 * it would silently fall back to Chinese.
 */
const APP_LANGUAGE_OPTIONS: AppLanguageOption[] = [
  { id: APP_LANGUAGE_FOLLOW_SYSTEM, title: $r('app.string.settings_general_language_follow_system') },
  { id: APP_LANGUAGE_SIMPLIFIED_CHINESE, title: $r('app.string.settings_general_language_chinese') },
  { id: APP_LANGUAGE_ENGLISH, title: $r('app.string.settings_general_language_english') }
];

@Entry
@Component
struct GeneralLanguageSettingsPage {
  private navigationCoordinator: SettingsNavigationCoordinator = new SettingsNavigationCoordinator();
  private restartService: AppModeSwitchRestartService = new AppModeSwitchRestartService();
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY) private storedDividerColor: string = '#E3E8EF';
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = DEFAULT_THEME_PALETTE.light.pageBackground;
  @StorageProp(BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY) private storedPressedBackgroundColor: string = '#DDE4EC';
  @StorageProp(BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY) private storedResolvedThemeMode: string = 'light';
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private storedSurfaceBackgroundColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  @State private languagePreference: string = sharedPreferencesRepository.getPreferences().appLanguage;
  @State private dataScope: string = '';
  @State private privacyMode: string = '';
  @State private boundarySource: string = '';

  aboutToAppear(): void {
    this.syncBoundaryRouteState();
    this.languagePreference = sharedPreferencesRepository.getPreferences().appLanguage;
  }

  build() {
    Column() {
      SettingsHdsScaffold({
        title: $r('app.string.settings_general_language'),
        backIconKind: 'back',
        pageBackground: this.storedPageBackgroundColor,
        headerButtonBackground: this.storedPressedBackgroundColor,
        primaryTextColor: this.storedPrimaryTextColor,
        dividerColor: this.storedDividerColor,
        onBack: () => {
          this.navigationCoordinator.back();
        }
      }) {
        SettingsScrollBody({ topPadding: 16 }) {
          this.buildSection()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.storedPageBackgroundColor)
  }

  @Builder
  private buildSection() {
    SettingsSection({
      title: $r('app.string.settings_general_language_section'),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
        ForEach(APP_LANGUAGE_OPTIONS, (option: AppLanguageOption, index: number) => {
          SettingsOptionRow({
            title: option.title,
            helperText: '',
            rowPosition: this.resolveRowPosition(index, APP_LANGUAGE_OPTIONS.length),
            isSelected: this.languagePreference === option.id,
            selectedIndicatorColor: this.storedAccentColor,
            onAction: () => {
              this.selectLanguage(option.id);
            }
          })
          if (index < APP_LANGUAGE_OPTIONS.length - 1) {
            SettingsGroupDivider({ dividerColor: this.storedDividerColor })
          }
        }, (option: AppLanguageOption) => this.resolveOptionRenderKey(option))
      }

      SettingsFooterText({
        text: this.buildFooterText(),
        secondaryTextColor: this.storedSecondaryTextColor
      })
    }
  }

  /**
   * The platform applies a preferred language on the next cold start, so the footer states
   * the restart requirement rather than pretending the switch is instant.
   */
  private buildFooterText(): ResourceStr {
    if (this.languagePreference === APP_LANGUAGE_FOLLOW_SYSTEM) {
      return $r('app.string.settings_general_language_footer_follow_system');
    }
    const effective = resolveEffectiveAppLanguage(this.languagePreference);
    if (effective === this.languagePreference) {
      return $r('app.string.settings_general_language_footer');
    }
    return $r('app.string.settings_general_language_footer_restart');
  }

  private selectLanguage(language: string): void {
    if (this.languagePreference === language) {
      return;
    }
    const previousLanguage = this.languagePreference;
    this.languagePreference = language;
    // The preference is written first: a failed platform call must not lose the user's
    // choice, and the stored value is what the next cold start reads.
    sharedPreferencesRepository.updateAppLanguage(language)
      .then(() => {
        if (!applyAppPreferredLanguage(language)) {
          this.languagePreference = previousLanguage;
          sharedPreferencesRepository.updateAppLanguage(previousLanguage);
          this.showToast($r('app.string.settings_general_language_failed'));
          return;
        }
        this.restartService.scheduleRestartForModeSwitch();
      })
      .catch((_error: Error) => {
        this.languagePreference = previousLanguage;
        this.showToast($r('app.string.settings_general_language_failed'));
      });
  }

  private showToast(message: ResourceStr): void {
    this.getUIContext().getPromptAction().showToast({
      message: message,
      duration: 1800
    });
  }

  private resolveOptionRenderKey(option: AppLanguageOption): string {
    return `${this.resolveThemeRenderKey()}:${option.id}:${this.languagePreference === option.id ? '1' : '0'}`;
  }

  private resolveThemeRenderKey(): string {
    return `${this.storedResolvedThemeMode}:${this.storedPageBackgroundColor}:${this.storedSurfaceBackgroundColor}:` +
      `${this.storedPressedBackgroundColor}:${this.storedAccentColor}:${this.storedPrimaryTextColor}:` +
      `${this.storedSecondaryTextColor}:${this.storedDividerColor}`;
  }

  private syncBoundaryRouteState(): void {
    const boundary = readBrowserBoundaryRouteState({
      dataScope: this.dataScope,
      privacyMode: this.privacyMode,
      boundarySource: this.boundarySource
    });
    this.dataScope = boundary.dataScope;
    this.privacyMode = boundary.privacyMode;
    this.boundarySource = boundary.boundarySource;
  }

  private resolveRowPosition(index: number, count: number): 'single' | 'first' | 'middle' | 'last' {
    if (count <= 1) {
      return 'single';
    }
    if (index <= 0) {
      return 'first';
    }
    if (index >= count - 1) {
      return 'last';
    }
    return 'middle';
  }
}
