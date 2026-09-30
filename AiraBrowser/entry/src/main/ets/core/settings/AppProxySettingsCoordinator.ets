import {
  BrowserDataBoundaryInput,
  BrowserExperimentSettings
} from '../../common/models/BrowserModels';
import { PreferencesRepository } from '../../data/preferences/PreferencesRepository';
import { BrowserPrivacyEffectPolicyService } from '../../services/privacy/BrowserPrivacyEffectPolicyService';
import { ArkWebAppProxyService } from '../../services/web/ArkWebAppProxyService';
import { BrowserProfileBoundaryService } from '../browser/BrowserProfileBoundaryService';
import {
  AppProxyProfileDraft,
  AppProxySettingsPageState,
  AppProxySettingsViewModel
} from './AppProxySettingsViewModel';
import { BrowserExperimentSettingsRefreshSignal } from './BrowserExperimentSettingsRefreshSignal';

export interface AppProxySettingsCoordinatorState {
  experiments: BrowserExperimentSettings;
  pageState: AppProxySettingsPageState;
}

export interface AppProxySettingsMutationResult {
  state: AppProxySettingsCoordinatorState;
  message: ResourceStr;
  success: boolean;
}

export function hasAppProxyUserMessage(message: ResourceStr): boolean {
  return typeof message !== 'string' || message.length > 0;
}

export class AppProxySettingsCoordinator {
  private preferencesRepository: PreferencesRepository;
  private appProxyService: ArkWebAppProxyService;
  private viewModel: AppProxySettingsViewModel;
  private requestRuntimeRefresh: () => void;
  private experimentSettingsRefreshSignal: BrowserExperimentSettingsRefreshSignal;
  private privacyEffectPolicy: BrowserPrivacyEffectPolicyService;
  private profileBoundaryService: BrowserProfileBoundaryService;

  constructor(
    preferencesRepository: PreferencesRepository,
    appProxyService: ArkWebAppProxyService,
    viewModel: AppProxySettingsViewModel = new AppProxySettingsViewModel(),
    requestRuntimeRefresh: () => void = (): void => {},
    experimentSettingsRefreshSignal: BrowserExperimentSettingsRefreshSignal = new BrowserExperimentSettingsRefreshSignal(),
    privacyEffectPolicy: BrowserPrivacyEffectPolicyService = new BrowserPrivacyEffectPolicyService(),
    profileBoundaryService: BrowserProfileBoundaryService = new BrowserProfileBoundaryService()
  ) {
    this.preferencesRepository = preferencesRepository;
    this.appProxyService = appProxyService;
    this.viewModel = viewModel;
    this.requestRuntimeRefresh = requestRuntimeRefresh;
    this.experimentSettingsRefreshSignal = experimentSettingsRefreshSignal;
    this.privacyEffectPolicy = privacyEffectPolicy;
    this.profileBoundaryService = profileBoundaryService;
  }

  buildState(): AppProxySettingsCoordinatorState {
    return this.buildStateFromExperiments(this.preferencesRepository.getPreferences().experiments);
  }

  async selectProfile(
    profileId: string,
    boundaryInput: BrowserDataBoundaryInput
  ): Promise<AppProxySettingsMutationResult> {
    const previous = this.preferencesRepository.getPreferences().experiments;
    if (!previous.appProxyEnabled || previous.appProxyActiveProfileId === profileId) {
      return {
        state: this.buildStateFromExperiments(previous),
        message: '',
        success: true
      };
    }
    const next = this.viewModel.buildSettingsWithActiveProfile(previous, profileId);
    return this.commit(
      previous,
      next,
      boundaryInput,
      () => $r('app.string.proxy_sheet_switched', this.viewModel.buildPageState(next).activeProfileName),
      $r('app.string.proxy_sheet_switch_failed')
    );
  }

  async setGlobalEnabled(
    enabled: boolean,
    boundaryInput: BrowserDataBoundaryInput
  ): Promise<AppProxySettingsMutationResult> {
    const previous = this.preferencesRepository.getPreferences().experiments;
    const next = this.viewModel.buildSettingsWithGlobalEnabled(previous, enabled);
    return this.commit(
      previous,
      next,
      boundaryInput,
      () => enabled ? $r('app.string.proxy_sheet_enabled') : $r('app.string.proxy_sheet_disabled'),
      $r('app.string.proxy_sheet_state_failed')
    );
  }

  async deleteProfile(
    profileId: string,
    boundaryInput: BrowserDataBoundaryInput
  ): Promise<AppProxySettingsMutationResult> {
    const previous = this.preferencesRepository.getPreferences().experiments;
    const next = this.viewModel.buildSettingsWithDeletedProfile(previous, profileId);
    return this.commit(
      previous,
      next,
      boundaryInput,
      () => $r('app.string.proxy_sheet_deleted'),
      $r('app.string.proxy_sheet_delete_failed')
    );
  }

  async saveProfile(
    draft: AppProxyProfileDraft,
    boundaryInput: BrowserDataBoundaryInput
  ): Promise<AppProxySettingsMutationResult> {
    const previous = this.preferencesRepository.getPreferences().experiments;
    const settings = this.viewModel.buildSettingsWithSavedDraft(previous, draft);
    const activeProfile = this.viewModel.findProfile(settings, settings.appProxyActiveProfileId);
    const shouldApplyRuntime = draft.id.length > 0
      ? settings.appProxyActiveProfileId === draft.id
      : activeProfile !== undefined && activeProfile.updatedAt === settings.appProxy.updatedAt;
    return this.commit(
      previous,
      settings,
      boundaryInput,
      () => $r('app.string.proxy_sheet_saved'),
      $r('app.string.proxy_sheet_save_failed'),
      shouldApplyRuntime,
      shouldApplyRuntime
    );
  }

  async saveAuthenticatedProxySettings(
    settings: BrowserExperimentSettings,
    boundaryInput: BrowserDataBoundaryInput
  ): Promise<AppProxySettingsMutationResult> {
    const previous = this.preferencesRepository.getPreferences().experiments;
    return this.commit(
      previous,
      settings,
      boundaryInput,
      () => '',
      $r('app.string.proxy_sheet_auth_failed'),
      true,
      false
    );
  }

  private async commit(
    previous: BrowserExperimentSettings,
    next: BrowserExperimentSettings,
    boundaryInput: BrowserDataBoundaryInput,
    successMessage: () => ResourceStr,
    failureMessage: ResourceStr,
    shouldApplyRuntime: boolean = true,
    shouldRequestRuntimeRefresh: boolean = true
  ): Promise<AppProxySettingsMutationResult> {
    if (!this.canWriteDevicePreference(boundaryInput)) {
      return {
        state: this.buildStateFromExperiments(previous),
        message: failureMessage,
        success: false
      };
    }
    try {
      const preferences = await this.preferencesRepository.updateExperimentSettings(next);
      if (shouldApplyRuntime) {
        await this.appProxyService.applyFromExperimentSettings(preferences.experiments);
      }
      if (shouldRequestRuntimeRefresh) {
        this.experimentSettingsRefreshSignal.bump();
        this.requestRuntimeRefresh();
      }
      return {
        state: this.buildStateFromExperiments(preferences.experiments),
        message: successMessage(),
        success: true
      };
    } catch (_error) {
      return {
        state: this.buildStateFromExperiments(previous),
        message: failureMessage,
        success: false
      };
    }
  }

  private buildStateFromExperiments(experiments: BrowserExperimentSettings): AppProxySettingsCoordinatorState {
    return {
      experiments: experiments,
      pageState: this.viewModel.buildPageState(experiments)
    };
  }

  private canWriteDevicePreference(boundaryInput: BrowserDataBoundaryInput): boolean {
    return this.privacyEffectPolicy.decide({
      intent: 'settings_device_preference_write',
      requestingBoundary: this.profileBoundaryService.buildBoundary(boundaryInput),
      targetScope: 'device_preferences',
      targetIsClear: true
    }).outcome === 'allow';
  }
}
