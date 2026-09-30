import {
  BrowserDataBoundaryInput,
  BrowserGeneralSettings
} from '../../common/models/BrowserModels';
import { PreferencesRepository } from '../../data/preferences/PreferencesRepository';
import {
  BrowserFingerprintPrivacyPolicyService,
  BrowserFingerprintPrivacyPolicyState,
  BrowserTrackingProtectionMode
} from '../../services/privacy/BrowserFingerprintPrivacyPolicyService';
import { BrowserPrivacyEffectPolicyService } from '../../services/privacy/BrowserPrivacyEffectPolicyService';
import { BrowserProfileBoundaryService } from '../browser/BrowserProfileBoundaryService';

export interface BrowserTrackingProtectionOptionState {
  mode: BrowserTrackingProtectionMode;
  title: ResourceStr;
}

export interface BrowserTrackingProtectionSettingsState extends BrowserFingerprintPrivacyPolicyState {
  selectedLabel: ResourceStr;
  options: BrowserTrackingProtectionOptionState[];
  footerText: ResourceStr;
  limitationText: ResourceStr;
}

export class BrowserTrackingProtectionSettingsCoordinator {
  private readonly preferencesRepository: PreferencesRepository;
  private readonly fingerprintPolicyService: BrowserFingerprintPrivacyPolicyService;
  private readonly privacyEffectPolicy: BrowserPrivacyEffectPolicyService;
  private readonly profileBoundaryService: BrowserProfileBoundaryService;

  constructor(
    preferencesRepository: PreferencesRepository,
    fingerprintPolicyService: BrowserFingerprintPrivacyPolicyService,
    privacyEffectPolicy: BrowserPrivacyEffectPolicyService = new BrowserPrivacyEffectPolicyService(),
    profileBoundaryService: BrowserProfileBoundaryService = new BrowserProfileBoundaryService()
  ) {
    this.preferencesRepository = preferencesRepository;
    this.fingerprintPolicyService = fingerprintPolicyService;
    this.privacyEffectPolicy = privacyEffectPolicy;
    this.profileBoundaryService = profileBoundaryService;
  }

  buildState(): BrowserTrackingProtectionSettingsState {
    return this.buildStateFromPolicy(
      this.fingerprintPolicyService.buildState(this.preferencesRepository.getPreferences())
    );
  }

  setMode(
    mode: BrowserTrackingProtectionMode,
    boundaryInput: BrowserDataBoundaryInput
  ): Promise<BrowserTrackingProtectionSettingsState> {
    if (!this.canWriteDevicePreference(boundaryInput)) {
      return Promise.reject(new Error('Tracking protection device preference write was not allowed.'));
    }
    const current = this.preferencesRepository.getPreferences().general;
    const next: BrowserGeneralSettings = {
      startupRestorePolicy: current.startupRestorePolicy,
      tabAutoClosePolicy: current.tabAutoClosePolicy,
      privateTabRestorePolicy: current.privateTabRestorePolicy,
      privateModeAuthenticationEnabled: current.privateModeAuthenticationEnabled,
      alwaysUsePrivateMode: current.alwaysUsePrivateMode === true,
      privateModePreserveCookiesOnClose: current.privateModePreserveCookiesOnClose,
      privateModeThemeEnabled: current.privateModeThemeEnabled,
      enhancedTrackingProtectionEnabled: mode === 'enhanced'
    };
    return this.preferencesRepository.updateGeneralSettings(next)
      .then((): BrowserTrackingProtectionSettingsState => {
        const applied = this.fingerprintPolicyService.applyRuntime(this.preferencesRepository.getPreferences());
        return this.buildStateFromPolicy(applied);
      });
  }

  private buildStateFromPolicy(
    policy: BrowserFingerprintPrivacyPolicyState
  ): BrowserTrackingProtectionSettingsState {
    return {
      mode: policy.mode,
      enhanced: policy.enhanced,
      clientHintsEnabled: policy.clientHintsEnabled,
      thirdPartyCookiesAllowed: policy.thirdPartyCookiesAllowed,
      stableBrowserIdentityEnabled: policy.stableBrowserIdentityEnabled,
      clientHintsRuntimeApplied: policy.clientHintsRuntimeApplied,
      cookiePolicyRuntimeApplied: policy.cookiePolicyRuntimeApplied,
      runtimeApplied: policy.runtimeApplied,
      message: policy.message,
      selectedLabel: policy.enhanced ?
        $r('app.string.settings_privacy_protection_tracking_enhanced') :
        $r('app.string.settings_site_info_fingerprint_standard'),
      options: [
        { mode: 'standard', title: $r('app.string.settings_site_info_fingerprint_standard') },
        { mode: 'enhanced', title: $r('app.string.settings_privacy_protection_tracking_enhanced_option') }
      ],
      footerText: policy.enhanced
        ? $r('app.string.settings_privacy_protection_tracking_footer_enhanced')
        : $r('app.string.settings_privacy_protection_tracking_footer_standard'),
      limitationText: policy.runtimeApplied
        ? $r('app.string.settings_privacy_protection_tracking_limit_applied')
        : $r('app.string.settings_privacy_protection_tracking_limit_partial', this.resolvePolicyMessage(policy.message))
    };
  }

  private resolvePolicyMessage(message: string): ResourceStr {
    if (message === '部分防跟踪策略未能应用，请重启 Aira 后重试。') {
      return $r('app.string.settings_privacy_protection_tracking_partial');
    }
    if (message === '防跟踪策略已应用。') {
      return $r('app.string.settings_privacy_protection_tracking_applied');
    }
    return message;
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
