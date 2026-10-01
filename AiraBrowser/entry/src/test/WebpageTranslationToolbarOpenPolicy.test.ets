import { describe, expect, it } from '@ohos/hypium';
import {
  TranslationProviderConfig,
  TranslationRule,
  TranslationSettings,
  TranslationSettingsPreferences
} from '../main/ets/common/models/BrowserModels';
import {
  WebpageTranslationPolicyService,
  WebpageTranslationToolbarOpenTranslationInput
} from '../main/ets/services/translation/WebpageTranslationPolicyService';

function preferences(
  acceptedAt: number,
  language: string,
  enabled: boolean = true,
  allowInPrivateTabs: boolean = false
): TranslationSettingsPreferences {
  return {
    enabled: enabled,
    offerToTranslate: false,
    allowInPrivateTabs: allowInPrivateTabs,
    preferredTargetLanguage: language,
    firstCloudDisclosureAcceptedAt: acceptedAt
  };
}

function provider(): TranslationProviderConfig {
  return {
    id: 'aira_system_translation',
    templateId: 'aira_system',
    displayName: 'Aira 系统翻译',
    endpoint: '',
    apiKey: '',
    appId: '',
    secretKey: '',
    region: '',
    model: '',
    optionsJson: '{}',
    secretRefsJson: '{}',
    status: 'configured',
    failureReason: '',
    updatedAt: 1
  };
}

function settings(
  prefs: TranslationSettingsPreferences,
  rules: TranslationRule[] = []
): TranslationSettings {
  return {
    preferences: prefs,
    activeProviderId: 'aira_system_translation',
    providers: [provider()],
    rules: rules,
    updatedAt: 1
  };
}

function input(
  translationSettings: TranslationSettings,
  panelStatus: string = 'idle',
  translatedCount: number = 0,
  canRestore: boolean = false,
  canCancel: boolean = false,
  privateMode: boolean = false,
  appServiceModeFull: boolean = true,
  currentUrl: string = 'https://example.com/article'
): WebpageTranslationToolbarOpenTranslationInput {
  return {
    manual: {
      settings: translationSettings,
      appServiceModeFull: appServiceModeFull,
      privateMode: privateMode,
      currentUrl: currentUrl
    },
    panelStatus: panelStatus,
    translatedCount: translatedCount,
    canRestore: canRestore,
    canCancel: canCancel
  };
}

export default function webpageTranslationToolbarOpenPolicyTest(): void {
  const policy = new WebpageTranslationPolicyService();

  describe('shouldTranslateWhenOpeningFromToolbar', () => {
    it('keeps the first open on the confirm-and-choose-language path', 0, () => {
      expect(policy.shouldTranslateWhenOpeningFromToolbar(input(
        settings(preferences(0, 'zh-CN'))
      ))).assertFalse();
      expect(policy.shouldTranslateWhenOpeningFromToolbar(input(
        settings(preferences(1, ''))
      ))).assertFalse();
      expect(policy.shouldTranslateWhenOpeningFromToolbar(input(
        settings(preferences(1, '   '))
      ))).assertFalse();
    });

    it('starts translation after disclosure was accepted and a target language exists', 0, () => {
      expect(policy.shouldTranslateWhenOpeningFromToolbar(input(
        settings(preferences(1, 'zh-CN'))
      ))).assertTrue();
      expect(policy.shouldTranslateWhenOpeningFromToolbar(input(
        settings(preferences(1, 'en')),
        'restored',
        3,
        true
      ))).assertTrue();
      expect(policy.shouldTranslateWhenOpeningFromToolbar(input(
        settings(preferences(1, 'ja')),
        'error'
      ))).assertTrue();
    });

    it('does not restart an applied translation or an in-progress task', 0, () => {
      expect(policy.shouldTranslateWhenOpeningFromToolbar(input(
        settings(preferences(1, 'zh-CN')),
        'translated',
        4,
        true
      ))).assertFalse();
      expect(policy.shouldTranslateWhenOpeningFromToolbar(input(
        settings(preferences(1, 'zh-CN')),
        'partially_translated',
        1,
        false
      ))).assertFalse();
      expect(policy.shouldTranslateWhenOpeningFromToolbar(input(
        settings(preferences(1, 'zh-CN')),
        'translating',
        0,
        false,
        true
      ))).assertFalse();
    });

    it('does not start when translation is disabled, private, or blocked for the site', 0, () => {
      expect(policy.shouldTranslateWhenOpeningFromToolbar(input(
        settings(preferences(1, 'zh-CN', false))
      ))).assertFalse();
      expect(policy.shouldTranslateWhenOpeningFromToolbar(input(
        settings(preferences(1, 'zh-CN')),
        'idle',
        0,
        false,
        false,
        true
      ))).assertFalse();
      expect(policy.shouldTranslateWhenOpeningFromToolbar(input(
        settings(preferences(1, 'zh-CN')),
        'idle',
        0,
        false,
        false,
        false,
        false
      ))).assertFalse();
      const blockedSite: TranslationRule = {
        type: 'never_translate_site',
        languageCode: '',
        host: 'example.com',
        targetLanguageCode: '',
        createdAt: 1
      };
      expect(policy.shouldTranslateWhenOpeningFromToolbar(input(
        settings(preferences(1, 'zh-CN'), [blockedSite])
      ))).assertFalse();
    });
  });
}
