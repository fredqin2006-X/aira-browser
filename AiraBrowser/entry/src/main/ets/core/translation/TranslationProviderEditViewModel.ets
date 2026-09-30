import {
  TranslationProviderConfig,
  TranslationProviderTemplate,
  TranslationProviderTemplateId
} from '../../common/models/BrowserModels';
import { TranslationProviderTemplateService } from '../../services/translation/TranslationProviderTemplateService';
import { resolveAppResourceText } from '../resources/AppResourceText';

export interface TranslationProviderEditFieldView {
  key: string;
  label: string;
  placeholder: string;
  secure: boolean;
}

export interface TranslationProviderEditDraft {
  providerId: string;
  templateId: TranslationProviderTemplateId;
  displayName: string;
  endpoint: string;
  apiKey: string;
  appId: string;
  secretKey: string;
  region: string;
  model: string;
}

export interface TranslationProviderEditState {
  title: string;
  displayName: string;
  endpoint: string;
  apiKey: string;
  appId: string;
  secretKey: string;
  region: string;
  model: string;
  description: string;
  helperText: string;
  errorMessage: string;
  saveEnabled: boolean;
  fields: TranslationProviderEditFieldView[];
}

export class TranslationProviderEditViewModel {
  private templateService: TranslationProviderTemplateService = new TranslationProviderTemplateService();

  buildInitialDraft(templateId: TranslationProviderTemplateId = 'custom_http'): TranslationProviderEditDraft {
    return this.buildDraftForTemplate(templateId);
  }

  buildDraftForTemplate(templateId: TranslationProviderTemplateId): TranslationProviderEditDraft {
    const template = this.templateService.findTemplate(templateId);
    return {
      providerId: '',
      templateId: template.id,
      displayName: template.displayName,
      endpoint: '',
      apiKey: '',
      appId: '',
      secretKey: '',
      region: '',
      model: ''
    };
  }

  updateDraft(
    draft: TranslationProviderEditDraft,
    key: 'displayName' | 'endpoint' | 'apiKey' | 'appId' | 'secretKey' | 'region' | 'model',
    value: string
  ): TranslationProviderEditDraft {
    return {
      providerId: draft.providerId,
      templateId: draft.templateId,
      displayName: key === 'displayName' ? value : draft.displayName,
      endpoint: key === 'endpoint' ? value : draft.endpoint,
      apiKey: key === 'apiKey' ? value : draft.apiKey,
      appId: key === 'appId' ? value : draft.appId,
      secretKey: key === 'secretKey' ? value : draft.secretKey,
      region: key === 'region' ? value : draft.region,
      model: key === 'model' ? value : draft.model
    };
  }

  buildState(draft: TranslationProviderEditDraft, persistedError: string = ''): TranslationProviderEditState {
    const template = this.templateService.findTemplate(draft.templateId);
    const validationError = persistedError.length > 0 ? persistedError : this.buildValidationError(draft);
    return {
      title: resolveAppResourceText($r('app.string.settings_web_translation_config_title')),
      displayName: draft.displayName,
      endpoint: draft.endpoint,
      apiKey: draft.apiKey,
      appId: draft.appId,
      secretKey: draft.secretKey,
      region: draft.region,
      model: draft.model,
      description: template.description,
      helperText: this.buildHelperText(template),
      errorMessage: validationError,
      saveEnabled: validationError.length === 0,
      fields: this.buildFields(template.id)
    };
  }

  buildProvider(draft: TranslationProviderEditDraft): TranslationProviderConfig {
    const template = this.templateService.findTemplate(draft.templateId);
    return {
      id: draft.providerId.trim(),
      templateId: template.id,
      displayName: draft.displayName.trim().length > 0 ? draft.displayName.trim() : template.displayName,
      endpoint: draft.endpoint.trim(),
      apiKey: draft.apiKey.trim(),
      appId: draft.appId.trim(),
      secretKey: draft.secretKey.trim(),
      region: draft.region.trim(),
      model: draft.model.trim(),
      optionsJson: '{}',
      secretRefsJson: '{}',
      status: 'configured',
      failureReason: '',
      updatedAt: Date.now()
    };
  }

  buildDraftFromProvider(provider: TranslationProviderConfig): TranslationProviderEditDraft {
    return {
      providerId: provider.id,
      templateId: provider.templateId,
      displayName: provider.displayName,
      endpoint: provider.endpoint,
      apiKey: provider.apiKey,
      appId: provider.appId,
      secretKey: provider.secretKey,
      region: provider.region,
      model: provider.model
    };
  }

  private buildFields(templateId: TranslationProviderTemplateId): TranslationProviderEditFieldView[] {
    switch (templateId) {
      case 'custom_http':
        return [
          { key: 'displayName', label: resolveAppResourceText($r('app.string.settings_web_translation_field_name')), placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_name_custom')), secure: false },
          { key: 'endpoint', label: 'HTTPS Endpoint', placeholder: 'https://api.example.com/translate', secure: false }
        ];
      case 'baidu':
      case 'youdao':
        return [
          { key: 'displayName', label: resolveAppResourceText($r('app.string.settings_web_translation_field_name')), placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_name_provider', '百度翻译')), secure: false },
          { key: 'appId', label: 'App ID', placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_app_id_placeholder')), secure: false },
          { key: 'secretKey', label: resolveAppResourceText($r('app.string.settings_web_translation_field_secret')), placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_secret_placeholder')), secure: true }
        ];
      case 'tencent_cloud':
        return [
          { key: 'displayName', label: resolveAppResourceText($r('app.string.settings_web_translation_field_name')), placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_name_provider', '腾讯云翻译')), secure: false },
          { key: 'appId', label: 'SecretId', placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_name_provider', 'SecretId')), secure: false },
          { key: 'secretKey', label: 'SecretKey', placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_name_provider', 'SecretKey')), secure: true },
          { key: 'region', label: resolveAppResourceText($r('app.string.settings_web_translation_field_region')), placeholder: 'ap-shanghai', secure: false }
        ];
      case 'alibaba_cloud':
        return [
          { key: 'displayName', label: resolveAppResourceText($r('app.string.settings_web_translation_field_name')), placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_name_provider', '阿里云翻译')), secure: false },
          { key: 'appId', label: 'AccessKey ID', placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_name_provider', 'AccessKey ID')), secure: false },
          { key: 'secretKey', label: 'AccessKey Secret', placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_access_secret_placeholder')), secure: true },
          { key: 'region', label: resolveAppResourceText($r('app.string.settings_web_translation_field_region')), placeholder: 'cn-hangzhou', secure: false }
        ];
      case 'volcano':
        return [
          { key: 'displayName', label: resolveAppResourceText($r('app.string.settings_web_translation_field_name')), placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_name_provider', '火山翻译')), secure: false },
          { key: 'appId', label: 'Access Key', placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_access_placeholder')), secure: false },
          { key: 'secretKey', label: 'Secret Key', placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_secret_key_placeholder')), secure: true },
          { key: 'region', label: resolveAppResourceText($r('app.string.settings_web_translation_field_area')), placeholder: 'cn-north-1', secure: false }
        ];
      case 'microsoft':
        return [
          { key: 'displayName', label: resolveAppResourceText($r('app.string.settings_web_translation_field_name')), placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_name_provider', 'Microsoft Translator')), secure: false },
          { key: 'apiKey', label: resolveAppResourceText($r('app.string.settings_web_translation_field_subscription_key')), placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_subscription_placeholder')), secure: true },
          { key: 'region', label: resolveAppResourceText($r('app.string.settings_web_translation_field_area')), placeholder: 'eastasia', secure: false }
        ];
      case 'google_cloud':
        return [
          { key: 'displayName', label: resolveAppResourceText($r('app.string.settings_web_translation_field_name')), placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_name_provider', 'Google Cloud')), secure: false },
          { key: 'apiKey', label: 'API Key', placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_api_key_placeholder')), secure: true },
          { key: 'model', label: resolveAppResourceText($r('app.string.settings_web_translation_field_model')), placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_optional')), secure: false }
        ];
      default:
        return [
          { key: 'displayName', label: resolveAppResourceText($r('app.string.settings_web_translation_field_name')), placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_name_provider', 'DeepL')), secure: false },
          { key: 'apiKey', label: 'API Key', placeholder: resolveAppResourceText($r('app.string.settings_web_translation_field_api_key_placeholder')), secure: true }
        ];
    }
  }

  private buildValidationError(draft: TranslationProviderEditDraft): string {
    if (draft.displayName.trim().length === 0) {
      return resolveAppResourceText($r('app.string.settings_web_translation_validation_name'));
    }
    if (draft.templateId === 'custom_http') {
      const endpoint = draft.endpoint.trim();
      if (!endpoint.toLowerCase().startsWith('https://')) {
        return resolveAppResourceText($r('app.string.settings_web_translation_validation_https'));
      }
      const lowerEndpoint = endpoint.toLowerCase();
      if (lowerEndpoint.indexOf('?') >= 0 &&
        (lowerEndpoint.indexOf('key=') >= 0 || lowerEndpoint.indexOf('token=') >= 0 ||
          lowerEndpoint.indexOf('secret=') >= 0 || lowerEndpoint.indexOf('password=') >= 0)) {
        return resolveAppResourceText($r('app.string.settings_web_translation_validation_url_secret'));
      }
      return '';
    }
    switch (draft.templateId) {
      case 'deepl':
      case 'google_cloud':
      case 'microsoft':
        return draft.apiKey.trim().length > 0 ? '' : resolveAppResourceText($r('app.string.settings_web_translation_validation_api_key'));
      case 'baidu':
      case 'youdao':
        return draft.appId.trim().length > 0 && draft.secretKey.trim().length > 0
          ? ''
          : resolveAppResourceText($r('app.string.settings_web_translation_validation_app'));
      case 'tencent_cloud':
        return draft.appId.trim().length > 0 && draft.secretKey.trim().length > 0
          ? ''
          : resolveAppResourceText($r('app.string.settings_web_translation_validation_tencent'));
      case 'alibaba_cloud':
      case 'volcano':
        return draft.appId.trim().length > 0 && draft.secretKey.trim().length > 0
          ? ''
          : resolveAppResourceText($r('app.string.settings_web_translation_validation_access'));
      default:
        return '';
    }
    return '';
  }

  private buildHelperText(template: TranslationProviderTemplate): string {
    if (template.id === 'custom_http') {
      return resolveAppResourceText($r('app.string.settings_web_translation_helper_custom'));
    }
    return resolveAppResourceText($r('app.string.settings_web_translation_helper_official'));
  }
}
