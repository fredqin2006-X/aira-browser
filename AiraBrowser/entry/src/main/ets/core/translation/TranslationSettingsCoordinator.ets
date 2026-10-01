import { resolveAppResourceText } from '../resources/AppResourceText';
import {
  BrowserDataScope,
  BrowserSessionPrivacyMode,
  TranslationProviderConfig,
  TranslationSettings,
  TranslationSettingsPreferences
} from '../../common/models/BrowserModels';
import { TranslationSettingsRepository } from '../../data/translation/TranslationSettingsRepository';
import { TranslationSecretStore } from '../../data/translation/TranslationSecretStore';
import { BrowserPrivacyEffectPolicyService } from '../../services/privacy/BrowserPrivacyEffectPolicyService';
import { TranslationProviderError } from '../../services/translation/TranslationProviderFailureClassifierService';
import { TranslationProviderRequestService } from '../../services/translation/TranslationProviderRequestService';
import { resolveDisplayedTranslationProviderName } from '../../services/translation/TranslationProviderTemplateService';
import { TranslationProviderSecretService } from '../../services/translation/TranslationProviderSecretService';
import { WebpageTranslationTextItem } from '../../services/web/WebpageTranslationRuntimeModels';
import { BrowserProfileBoundaryService } from '../browser/BrowserProfileBoundaryService';
import { TranslationProviderEditDraft, TranslationProviderEditViewModel } from './TranslationProviderEditViewModel';
import { WebpageTranslationSettingsViewModel } from './WebpageTranslationSettingsViewModel';

export class TranslationSettingsBoundary {
  dataScope: BrowserDataScope | string;
  privacyMode: BrowserSessionPrivacyMode | string;

  constructor(dataScope: BrowserDataScope | string, privacyMode: BrowserSessionPrivacyMode | string) {
    this.dataScope = dataScope;
    this.privacyMode = privacyMode;
  }
}

export interface TranslationSettingsMutationResult {
  allowed: boolean;
  settings: TranslationSettings;
}

export interface TranslationProviderConfigSaveResult {
  ok: boolean;
  message: string;
}

export class TranslationSettingsCoordinator {
  private repository: TranslationSettingsRepository;
  private editViewModel: TranslationProviderEditViewModel = new TranslationProviderEditViewModel();
  private settingsViewModel: WebpageTranslationSettingsViewModel = new WebpageTranslationSettingsViewModel();
  private requestService: TranslationProviderRequestService = new TranslationProviderRequestService();
  private secretService?: TranslationProviderSecretService;
  private privacyEffectPolicy: BrowserPrivacyEffectPolicyService;
  private profileBoundaryService: BrowserProfileBoundaryService;

  constructor(
    repository: TranslationSettingsRepository,
    secretStore: TranslationSecretStore | undefined,
    privacyEffectPolicy: BrowserPrivacyEffectPolicyService = new BrowserPrivacyEffectPolicyService(),
    profileBoundaryService: BrowserProfileBoundaryService = new BrowserProfileBoundaryService()
  ) {
    this.repository = repository;
    this.secretService = secretStore === undefined ? undefined : new TranslationProviderSecretService(secretStore);
    this.privacyEffectPolicy = privacyEffectPolicy;
    this.profileBoundaryService = profileBoundaryService;
  }

  async updatePreference(
    key: 'enabled' | 'allowInPrivateTabs' | 'preferredTargetLanguage',
    value: boolean | string | number,
    boundary: TranslationSettingsBoundary
  ): Promise<TranslationSettingsMutationResult> {
    const currentSettings = this.repository.getSettings();
    const nextPreferences = this.settingsViewModel.buildPreferencesPatch(
      currentSettings.preferences,
      key,
      value
    );
    return this.updatePreferences(nextPreferences, boundary);
  }

  async updatePreferences(
    preferences: TranslationSettingsPreferences,
    boundary: TranslationSettingsBoundary
  ): Promise<TranslationSettingsMutationResult> {
    if (!this.canWriteDevicePreference(boundary)) {
      return this.buildDeniedMutationResult();
    }
    return {
      allowed: true,
      settings: await this.repository.updatePreferences(preferences)
    };
  }

  async selectProvider(
    providerId: string,
    boundary: TranslationSettingsBoundary
  ): Promise<TranslationSettingsMutationResult> {
    if (!this.canWriteDevicePreference(boundary)) {
      return this.buildDeniedMutationResult();
    }
    const settings = await this.repository.setActiveProvider(providerId);
    return {
      allowed: true,
      settings: await this.syncTargetLanguageForProvider(settings, boundary)
    };
  }

  buildSaveConfirmationMessage(provider: TranslationProviderConfig): string {
    if (provider.templateId === 'custom_http') {
      return resolveAppResourceText($r(
        'app.string.translation_settings_save_disclosure_endpoint',
        resolveDisplayedTranslationProviderName(provider.templateId, provider.displayName),
        provider.endpoint
      ));
    }
    return resolveAppResourceText($r(
      'app.string.translation_settings_save_disclosure',
      resolveDisplayedTranslationProviderName(provider.templateId, provider.displayName)
    ));
  }

  async buildEditableProvider(
    provider: TranslationProviderConfig,
    boundary: TranslationSettingsBoundary
  ): Promise<TranslationProviderConfig> {
    if (!this.canReadDevicePreference(boundary)) {
      throw new Error(resolveAppResourceText($r('app.string.translation_settings_read_denied')));
    }
    return this.requireSecretService().buildEditableProvider(provider);
  }

  async saveConfiguredProvider(
    draft: TranslationProviderEditDraft,
    boundary: TranslationSettingsBoundary
  ): Promise<TranslationProviderConfigSaveResult> {
    const provider = this.buildProviderWithStableId(draft);
    try {
      await this.testProviderConnection(provider);
      if (!this.canWriteDevicePreference(boundary)) {
        return { ok: false, message: resolveAppResourceText($r('app.string.translation_settings_save_denied')) };
      }
      const securedProvider = await this.requireSecretService().secureProviderForSave(provider, this.repository);
      if (!this.canWriteDevicePreference(boundary)) {
        return { ok: false, message: resolveAppResourceText($r('app.string.translation_settings_save_denied')) };
      }
      const settings = await this.repository.saveUserProvider(securedProvider);
      await this.syncTargetLanguageForProvider(settings, boundary);
      return { ok: true, message: '' };
    } catch (error) {
      return { ok: false, message: this.stringifyProviderError(error) };
    }
  }

  private buildDeniedMutationResult(): TranslationSettingsMutationResult {
    return {
      allowed: false,
      settings: this.repository.getSettings()
    };
  }

  private canWriteDevicePreference(boundary: TranslationSettingsBoundary): boolean {
    return this.isDevicePreferenceEffectAllowed('settings_device_preference_write', boundary);
  }

  private canReadDevicePreference(boundary: TranslationSettingsBoundary): boolean {
    return this.isDevicePreferenceEffectAllowed('settings_device_preference_read', boundary);
  }

  private isDevicePreferenceEffectAllowed(
    intent: 'settings_device_preference_read' | 'settings_device_preference_write',
    boundary: TranslationSettingsBoundary
  ): boolean {
    return this.privacyEffectPolicy.decide({
      intent: intent,
      requestingBoundary: this.profileBoundaryService.buildBoundary({
        dataScope: boundary.dataScope,
        privacyMode: boundary.privacyMode
      }),
      targetScope: 'device_preferences',
      targetIsClear: true
    }).outcome === 'allow';
  }

  private async testProviderConnection(provider: TranslationProviderConfig): Promise<void> {
    const testItem: WebpageTranslationTextItem = {
      id: 'provider_connection_test',
      text: 'Hello',
      charLength: 5,
      order: 0,
      score: 1,
      nearViewport: true,
      top: 0
    };
    const result = await this.requestService.translateBatch(provider, [testItem], 'en', 'zh-CN');
    const translatedText = result[0]?.translatedText?.trim() ?? '';
    if (translatedText.length === 0) {
      throw new Error(resolveAppResourceText($r('app.string.translation_settings_empty_result')));
    }
  }

  private buildProviderWithStableId(draft: TranslationProviderEditDraft): TranslationProviderConfig {
    const provider = this.editViewModel.buildProvider(draft);
    if (provider.id.length > 0) {
      return provider;
    }
    const providerId = this.requireSecretService().buildUserProviderId(
      this.repository.getSettings(),
      provider.templateId,
      provider.id
    );
    return {
      id: providerId,
      templateId: provider.templateId,
      displayName: provider.displayName,
      endpoint: provider.endpoint,
      apiKey: provider.apiKey,
      appId: provider.appId,
      secretKey: provider.secretKey,
      region: provider.region,
      model: provider.model,
      optionsJson: provider.optionsJson,
      secretRefsJson: provider.secretRefsJson,
      status: provider.status,
      failureReason: provider.failureReason,
      updatedAt: provider.updatedAt
    };
  }

  private async syncTargetLanguageForProvider(
    settings: TranslationSettings,
    boundary: TranslationSettingsBoundary
  ): Promise<TranslationSettings> {
    const activeProvider = settings.providers.find((provider: TranslationProviderConfig) => {
      return provider.id === settings.activeProviderId;
    });
    const nextLanguage = this.settingsViewModel.normalizePreferredTargetLanguageForProvider(
      activeProvider,
      settings.preferences.preferredTargetLanguage
    );
    if (nextLanguage === settings.preferences.preferredTargetLanguage) {
      return settings;
    }
    const nextPreferences: TranslationSettingsPreferences = this.settingsViewModel.buildPreferencesPatch(
      settings.preferences,
      'preferredTargetLanguage',
      nextLanguage
    );
    const result = await this.updatePreferences(nextPreferences, boundary);
    return result.settings;
  }

  private requireSecretService(): TranslationProviderSecretService {
    if (this.secretService === undefined) {
      throw new Error('Translation secret store is required for provider configuration.');
    }
    return this.secretService;
  }

  private stringifyProviderError(error: Error | Object): string {
    if (error instanceof TranslationProviderError) {
      return error.failure.message;
    }
    if (error instanceof Error && error.message.length > 0) {
      return error.message;
    }
    return resolveAppResourceText($r('app.string.translation_settings_connect_failed'));
  }
}
