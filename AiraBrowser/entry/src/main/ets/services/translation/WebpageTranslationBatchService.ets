import { resolveAppResourceText } from '../../core/resources/AppResourceText';
import {
  WebpageTranslationApplyItem,
  WebpageTranslationTextItem
} from '../web/WebpageTranslationRuntimeModels';
import { TranslationProviderConfig } from '../../common/models/BrowserModels';
import { TranslationProviderRequestService } from './TranslationProviderRequestService';
import {
  TranslationProviderError,
  TranslationProviderFailureClassifierService
} from './TranslationProviderFailureClassifierService';
import { TranslationSecretStore } from '../../data/translation/TranslationSecretStore';
import { TranslationProviderSecretService } from './TranslationProviderSecretService';

export class WebpageTranslationBatchService {
  private providerRequestService: TranslationProviderRequestService = new TranslationProviderRequestService();
  private failureClassifier: TranslationProviderFailureClassifierService =
    new TranslationProviderFailureClassifierService();
  private secretService?: TranslationProviderSecretService;

  constructor(secretStore?: TranslationSecretStore) {
    if (secretStore !== undefined) {
      this.secretService = new TranslationProviderSecretService(secretStore);
    }
  }

  cancelActiveRequests(): void {
    this.providerRequestService.cancelActiveRequests();
  }

  async translateBatch(
    provider: TranslationProviderConfig | undefined,
    items: WebpageTranslationTextItem[],
    sourceLanguage: string,
    targetLanguage: string
  ): Promise<WebpageTranslationApplyItem[]> {
    if (provider === undefined || provider.status !== 'configured') {
      throw new TranslationProviderError(this.failureClassifier.buildFailure(
        'missing_provider',
        resolveAppResourceText($r('app.string.translation_provider_none'))
      ));
    }
    if (!this.providerRequestService.supportsProvider(provider.templateId)) {
      throw new TranslationProviderError(this.failureClassifier.buildFailure(
        'missing_provider',
        resolveAppResourceText($r('app.string.translation_provider_not_connected'))
      ));
    }
    const resolvedProvider = this.secretService === undefined
      ? provider
      : await this.secretService.resolveProviderSecrets(provider);
    return this.providerRequestService.translateBatch(
      resolvedProvider,
      items,
      sourceLanguage,
      targetLanguage
    );
  }
}
