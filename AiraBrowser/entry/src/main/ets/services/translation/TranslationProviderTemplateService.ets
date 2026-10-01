import {
  TranslationProviderTemplate,
  TranslationProviderTemplateId
} from '../../common/models/BrowserModels';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';

export class TranslationProviderTemplateService {
  listTemplates(): TranslationProviderTemplate[] {
    return [
      {
        id: 'aira_system',
        displayName: resolveAppResourceText($r('app.string.translation_template_aira_name')),
        description: resolveAppResourceText($r('app.string.translation_template_aira_desc')),
        setupStatus: 'configured',
        requiresSecret: false,
        supportsDirectClientRequest: false,
        builtIn: true,
        requiresPro: false
      },
      {
        id: 'edge_web',
        displayName: resolveAppResourceText($r('app.string.translation_template_edge_name')),
        description: resolveAppResourceText($r('app.string.translation_template_edge_desc')),
        setupStatus: 'configured',
        requiresSecret: false,
        supportsDirectClientRequest: true,
        builtIn: true,
        requiresPro: false
      },
      {
        id: 'google_web',
        displayName: resolveAppResourceText($r('app.string.translation_template_google_web_name')),
        description: resolveAppResourceText($r('app.string.translation_template_google_web_desc')),
        setupStatus: 'configured',
        requiresSecret: false,
        supportsDirectClientRequest: true,
        builtIn: true,
        requiresPro: false
      },
      {
        id: 'tencent_web',
        displayName: resolveAppResourceText($r('app.string.translation_template_tencent_web_name')),
        description: resolveAppResourceText($r('app.string.translation_template_tencent_web_desc')),
        setupStatus: 'configured',
        requiresSecret: false,
        supportsDirectClientRequest: true,
        builtIn: true,
        requiresPro: false
      },
      {
        id: 'yandex_web',
        displayName: resolveAppResourceText($r('app.string.translation_template_yandex_name')),
        description: resolveAppResourceText($r('app.string.translation_template_yandex_desc')),
        setupStatus: 'configured',
        requiresSecret: false,
        supportsDirectClientRequest: true,
        builtIn: true,
        requiresPro: false
      },
      {
        id: 'custom_http',
        displayName: resolveAppResourceText($r('app.string.translation_template_custom_name')),
        description: resolveAppResourceText($r('app.string.translation_template_custom_desc')),
        setupStatus: 'configured',
        requiresSecret: false,
        supportsDirectClientRequest: true,
        builtIn: false,
        requiresPro: false
      },
      {
        id: 'deepl',
        displayName: 'DeepL',
        description: resolveAppResourceText($r('app.string.translation_template_deepl_desc')),
        setupStatus: 'configured',
        requiresSecret: true,
        supportsDirectClientRequest: true,
        builtIn: false,
        requiresPro: false
      },
      {
        id: 'google_cloud',
        displayName: 'Google Cloud Translation',
        description: resolveAppResourceText($r('app.string.translation_template_google_cloud_desc')),
        setupStatus: 'configured',
        requiresSecret: true,
        supportsDirectClientRequest: true,
        builtIn: false,
        requiresPro: false
      },
      {
        id: 'tencent_cloud',
        displayName: resolveAppResourceText($r('app.string.translation_template_tencent_cloud_name')),
        description: resolveAppResourceText($r('app.string.translation_template_tencent_cloud_desc')),
        setupStatus: 'configured',
        requiresSecret: true,
        supportsDirectClientRequest: true,
        builtIn: false,
        requiresPro: false
      },
      {
        id: 'baidu',
        displayName: resolveAppResourceText($r('app.string.translation_template_baidu_name')),
        description: resolveAppResourceText($r('app.string.translation_template_baidu_desc')),
        setupStatus: 'configured',
        requiresSecret: true,
        supportsDirectClientRequest: true,
        builtIn: false,
        requiresPro: false
      },
      {
        id: 'microsoft',
        displayName: 'Microsoft Translator',
        description: resolveAppResourceText($r('app.string.translation_template_microsoft_desc')),
        setupStatus: 'configured',
        requiresSecret: true,
        supportsDirectClientRequest: true,
        builtIn: false,
        requiresPro: false
      },
      {
        id: 'alibaba_cloud',
        displayName: resolveAppResourceText($r('app.string.translation_template_alibaba_name')),
        description: resolveAppResourceText($r('app.string.translation_template_alibaba_desc')),
        setupStatus: 'configured',
        requiresSecret: true,
        supportsDirectClientRequest: true,
        builtIn: false,
        requiresPro: false
      },
      {
        id: 'volcano',
        displayName: resolveAppResourceText($r('app.string.translation_template_volcano_name')),
        description: resolveAppResourceText($r('app.string.translation_template_volcano_desc')),
        setupStatus: 'configured',
        requiresSecret: true,
        supportsDirectClientRequest: true,
        builtIn: false,
        requiresPro: false
      },
      {
        id: 'youdao',
        displayName: resolveAppResourceText($r('app.string.translation_template_youdao_name')),
        description: resolveAppResourceText($r('app.string.translation_template_youdao_desc')),
        setupStatus: 'configured',
        requiresSecret: true,
        supportsDirectClientRequest: true,
        builtIn: false,
        requiresPro: false
      }
    ];
  }

  listConfigurableTemplates(): TranslationProviderTemplate[] {
    return this.listTemplates().filter((template: TranslationProviderTemplate) => !template.builtIn);
  }

  findTemplate(templateId: TranslationProviderTemplateId): TranslationProviderTemplate {
    const template = this.listTemplates().find((item: TranslationProviderTemplate) => item.id === templateId);
    if (template !== undefined) {
      return template;
    }
    return this.listTemplates()[0];
  }

  buildTemplateLabel(templateId: TranslationProviderTemplateId | string): string {
    const template = this.listTemplates().find((item: TranslationProviderTemplate) => item.id === templateId);
    return template?.displayName ?? resolveAppResourceText($r('app.string.translation_template_custom_name'));
  }
}

export function resolveDisplayedTranslationProviderName(templateId: string, storedName: string): string {
  const stored = storedName.trim();
  const service = new TranslationProviderTemplateService();
  const localized = service.buildTemplateLabel(templateId);
  if (stored.length === 0 || isHistoricalTranslationTemplateName(templateId, stored)) {
    return localized;
  }
  return stored;
}

function isHistoricalTranslationTemplateName(templateId: string, storedName: string): boolean {
  const historicalNames = historicalTranslationTemplateNames(templateId);
  for (let index = 0; index < historicalNames.length; index++) {
    if (historicalNames[index] === storedName) {
      return true;
    }
  }
  return false;
}

function historicalTranslationTemplateNames(templateId: string): string[] {
  switch (templateId) {
    case 'aira_system':
      return ['Aira 系统翻译'];
    case 'edge_web':
      return ['Microsoft Edge 网页翻译'];
    case 'google_web':
      return ['Google 网页翻译'];
    case 'tencent_web':
      return ['腾讯交互翻译'];
    case 'yandex_web':
      return ['Yandex 网页翻译'];
    case 'custom_http':
      return ['自定义接口'];
    case 'deepl':
      return ['DeepL'];
    case 'google_cloud':
      return ['Google Cloud Translation'];
    case 'tencent_cloud':
      return ['腾讯云机器翻译', '腾讯云翻译'];
    case 'baidu':
      return ['百度翻译'];
    case 'microsoft':
      return ['Microsoft Translator'];
    case 'alibaba_cloud':
      return ['阿里云机器翻译', '阿里云翻译'];
    case 'volcano':
      return ['火山引擎机器翻译', '火山翻译'];
    case 'youdao':
      return ['有道智云翻译', '有道智云'];
    default:
      return [];
  }
}
