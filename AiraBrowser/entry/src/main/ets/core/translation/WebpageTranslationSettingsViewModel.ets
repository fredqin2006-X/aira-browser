import {
  TranslationProviderConfig,
  TranslationProviderTemplateId,
  TranslationSettings,
  TranslationSettingsPreferences
} from '../../common/models/BrowserModels';
import { TranslationProviderTemplateService } from '../../services/translation/TranslationProviderTemplateService';
import { resolveAppResourceText } from '../resources/AppResourceText';

export interface TranslationProviderRowView {
  id: string;
  templateId: TranslationProviderTemplateId;
  title: string;
  subtitle: string;
  statusText: string;
  isActive: boolean;
  isConfigured: boolean;
  requiresPro: boolean;
  isEditable: boolean;
}

export interface TranslationLanguageOptionView {
  code: string;
  label: string;
  helperText: string;
}

export interface WebpageTranslationSettingsViewState {
  enabled: boolean;
  allowInPrivateTabs: boolean;
  preferredTargetLanguage: string;
  preferredTargetLanguageLabel: string;
  targetLanguageDescription: string;
  targetLanguageSheetHelperText: string;
  targetLanguageOptions: TranslationLanguageOptionView[];
  providerStatusText: string;
  hasActiveProvider: boolean;
  providers: TranslationProviderRowView[];
}

export class WebpageTranslationSettingsViewModel {
  private templateService: TranslationProviderTemplateService = new TranslationProviderTemplateService();

  buildState(settings: TranslationSettings): WebpageTranslationSettingsViewState {
    const activeProvider = this.resolveActiveProvider(settings);
    const preferredTargetLanguage = this.normalizePreferredTargetLanguageForProvider(
      activeProvider,
      settings.preferences.preferredTargetLanguage
    );
    return {
      enabled: settings.preferences.enabled,
      allowInPrivateTabs: settings.preferences.allowInPrivateTabs,
      preferredTargetLanguage: preferredTargetLanguage,
      preferredTargetLanguageLabel: this.buildLanguageLabel(preferredTargetLanguage),
      targetLanguageDescription: this.buildTargetLanguageDescription(),
      targetLanguageSheetHelperText: this.buildTargetLanguageSheetHelperText(),
      targetLanguageOptions: this.buildTargetLanguageOptions(),
      providerStatusText: this.buildProviderStatusText(activeProvider),
      hasActiveProvider: activeProvider !== undefined && activeProvider.status === 'configured',
      providers: this.buildProviderRows(settings)
    };
  }

  private buildProviderRows(settings: TranslationSettings): TranslationProviderRowView[] {
    const rows: TranslationProviderRowView[] = settings.providers.map((provider: TranslationProviderConfig): TranslationProviderRowView => {
      return {
        id: provider.id,
        templateId: provider.templateId,
        title: provider.displayName,
        subtitle: this.buildProviderSubtitle(provider),
        statusText: this.buildProviderStatusText(provider),
        isActive: provider.id === settings.activeProviderId,
        isConfigured: provider.status === 'configured',
        requiresPro: this.templateService.findTemplate(provider.templateId).requiresPro,
        isEditable: !this.templateService.findTemplate(provider.templateId).builtIn
      };
    });
    const configuredTemplateIds: string[] = rows.map((row: TranslationProviderRowView) => row.templateId);
    this.templateService.listConfigurableTemplates().forEach((template) => {
      if (configuredTemplateIds.indexOf(template.id) >= 0) {
        return;
      }
      rows.push({
        id: `template_${template.id}`,
        templateId: template.id,
        title: template.displayName,
        subtitle: resolveAppResourceText(template.id === 'custom_http'
          ? $r('app.string.settings_web_translation_subtitle_custom_endpoint')
          : $r('app.string.settings_web_translation_subtitle_credentials_required')),
        statusText: resolveAppResourceText($r('app.string.settings_web_translation_status_unconfigured')),
        isActive: false,
        isConfigured: false,
        requiresPro: template.requiresPro,
        isEditable: !template.builtIn
      });
    });
    return this.sortProviderRows(rows);
  }

  private sortProviderRows(rows: TranslationProviderRowView[]): TranslationProviderRowView[] {
    return rows.slice().sort((left: TranslationProviderRowView, right: TranslationProviderRowView): number => {
      return this.resolveProviderRowOrder(left) - this.resolveProviderRowOrder(right);
    });
  }

  private resolveProviderRowOrder(row: TranslationProviderRowView): number {
    if (row.templateId === 'aira_system') {
      return 0;
    }
    if (row.templateId === 'edge_web') {
      return 10;
    }
    if (row.templateId === 'google_web') {
      return 11;
    }
    if (row.templateId === 'tencent_web') {
      return 12;
    }
    if (row.templateId === 'yandex_web') {
      return 13;
    }
    if (row.templateId === 'custom_http') {
      return 200;
    }
    return 100;
  }

  buildPreferencesPatch(
    current: TranslationSettingsPreferences,
    key: 'enabled' | 'allowInPrivateTabs' | 'preferredTargetLanguage',
    value: boolean | string | number
  ): TranslationSettingsPreferences {
    return {
      enabled: key === 'enabled' && typeof value === 'boolean' ? value : current.enabled,
      offerToTranslate: current.offerToTranslate,
      allowInPrivateTabs: key === 'allowInPrivateTabs' && typeof value === 'boolean'
        ? value
        : current.allowInPrivateTabs,
      preferredTargetLanguage: key === 'preferredTargetLanguage' && typeof value === 'string'
        ? value
        : current.preferredTargetLanguage,
      firstCloudDisclosureAcceptedAt: current.firstCloudDisclosureAcceptedAt
    };
  }

  private resolveActiveProvider(settings: TranslationSettings): TranslationProviderConfig | undefined {
    return settings.providers.find((provider: TranslationProviderConfig) => provider.id === settings.activeProviderId);
  }

  private buildProviderStatusText(provider: TranslationProviderConfig | undefined): string {
    if (provider === undefined) {
      return resolveAppResourceText($r('app.string.settings_web_translation_status_unconfigured'));
    }
    if (provider.status === 'configured') {
      return resolveAppResourceText($r('app.string.settings_web_translation_status_configured'));
    }
    if (provider.status === 'failed') {
      return provider.failureReason.length > 0
        ? resolveAppResourceText($r('app.string.settings_web_translation_status_failed_detail', provider.failureReason))
        : resolveAppResourceText($r('app.string.settings_web_translation_status_failed'));
    }
    if (provider.status === 'unavailable') {
      return provider.failureReason.length > 0
        ? resolveAppResourceText($r('app.string.settings_web_translation_status_unavailable_detail', provider.failureReason))
        : resolveAppResourceText($r('app.string.settings_web_translation_status_unavailable'));
    }
    return resolveAppResourceText($r('app.string.settings_web_translation_status_incomplete'));
  }

  private buildProviderSubtitle(provider: TranslationProviderConfig): string {
    if (provider.templateId === 'aira_system') {
      return resolveAppResourceText($r('app.string.settings_web_translation_subtitle_aira'));
    }
    if (provider.templateId === 'edge_web' || provider.templateId === 'google_web' ||
      provider.templateId === 'tencent_web' || provider.templateId === 'yandex_web') {
      return resolveAppResourceText($r('app.string.settings_web_translation_subtitle_public'));
    }
    if (provider.status === 'configured') {
      return resolveAppResourceText($r('app.string.settings_web_translation_subtitle_credentials'));
    }
    return this.templateService.buildTemplateLabel(provider.templateId);
  }

  buildLanguageLabel(languageCode: string): string {
    switch (languageCode) {
      case 'zh-CN':
        return resolveAppResourceText($r('app.string.settings_lang_zh_cn'));
      case 'zh-TW':
        return resolveAppResourceText($r('app.string.settings_lang_zh_tw'));
      case 'en':
        return resolveAppResourceText($r('app.string.settings_lang_en'));
      case 'ja':
        return resolveAppResourceText($r('app.string.settings_lang_ja'));
      case 'ko':
        return resolveAppResourceText($r('app.string.settings_lang_ko'));
      case 'fr':
        return resolveAppResourceText($r('app.string.settings_lang_fr'));
      case 'de':
        return resolveAppResourceText($r('app.string.settings_lang_de'));
      case 'es':
        return resolveAppResourceText($r('app.string.settings_lang_es'));
      case 'pt':
        return resolveAppResourceText($r('app.string.settings_lang_pt'));
      case 'ru':
        return resolveAppResourceText($r('app.string.settings_lang_ru'));
      default:
        return languageCode.trim().length > 0
          ? languageCode
          : resolveAppResourceText($r('app.string.settings_lang_zh_cn'));
    }
  }

  isTargetLanguageSupportedByProvider(
    _provider: TranslationProviderConfig | undefined,
    _languageCode: string
  ): boolean {
    return true;
  }

  normalizePreferredTargetLanguageForProvider(
    _provider: TranslationProviderConfig | undefined,
    languageCode: string
  ): string {
    return languageCode.trim().length > 0 ? languageCode : 'zh-CN';
  }

  private buildTargetLanguageDescription(): string {
    return resolveAppResourceText($r('app.string.settings_web_translation_target_desc'));
  }

  buildTargetLanguageSheetHelperText(): string {
    return resolveAppResourceText($r('app.string.settings_web_translation_target_helper'));
  }

  buildTargetLanguageOptions(): TranslationLanguageOptionView[] {
    return [
      this.languageOption('zh-CN', $r('app.string.settings_lang_zh_cn'), $r('app.string.settings_lang_helper_zh_cn')),
      this.languageOption('zh-TW', $r('app.string.settings_lang_zh_tw'), $r('app.string.settings_lang_helper_zh_tw')),
      this.languageOption('en', $r('app.string.settings_lang_en'), $r('app.string.settings_lang_helper_en')),
      this.languageOption('ja', $r('app.string.settings_lang_ja'), $r('app.string.settings_lang_helper_ja')),
      this.languageOption('ko', $r('app.string.settings_lang_ko'), $r('app.string.settings_lang_helper_ko')),
      this.languageOption('fr', $r('app.string.settings_lang_fr'), $r('app.string.settings_lang_helper_fr')),
      this.languageOption('de', $r('app.string.settings_lang_de'), $r('app.string.settings_lang_helper_de')),
      this.languageOption('es', $r('app.string.settings_lang_es'), $r('app.string.settings_lang_helper_es')),
      this.languageOption('pt', $r('app.string.settings_lang_pt'), $r('app.string.settings_lang_helper_pt')),
      this.languageOption('ru', $r('app.string.settings_lang_ru'), $r('app.string.settings_lang_helper_ru'))
    ];
  }

  private languageOption(code: string, label: ResourceStr, helperText: ResourceStr): TranslationLanguageOptionView {
    return {
      code: code,
      label: resolveAppResourceText(label),
      helperText: resolveAppResourceText(helperText)
    };
  }
}
