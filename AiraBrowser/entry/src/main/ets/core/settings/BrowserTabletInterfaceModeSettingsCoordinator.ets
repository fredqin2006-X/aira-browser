import { resolveAppResourceText } from '../resources/AppResourceText';
import { BrowserDataBoundaryInput } from '../../common/models/BrowserModels';
import { BrowserTabletInterfaceMode } from '../../common/models/BrowserDevicePresentationModels';
import { BrowserTabletInterfaceModeRepository } from '../../data/preferences/BrowserTabletInterfaceModeRepository';
import {
  BrowserDeviceFormFactor,
  BrowserDeviceFormFactorCoordinator
} from '../browser/BrowserDeviceFormFactorCoordinator';
import { BrowserTabletInterfaceModePolicy } from '../browser/BrowserTabletInterfaceModePolicy';
import { BrowserWindowPresentationProfileInputService } from '../../services/browser/BrowserWindowPresentationProfileInputService';
import { BrowserPrivacyEffectPolicyService } from '../../services/privacy/BrowserPrivacyEffectPolicyService';
import { BrowserProfileBoundaryService } from '../browser/BrowserProfileBoundaryService';
import {
  BrowserTabletInterfaceModeTransitionConsumer,
  sharedBrowserTabletInterfaceModeTransitionOwner
} from './BrowserTabletInterfaceModeTransitionOwner';

export interface BrowserTabletInterfaceModeOptionState {
  mode: BrowserTabletInterfaceMode;
  title: string;
}

export interface BrowserTabletInterfaceModeSettingsState {
  visible: boolean;
  detectedFormFactor: BrowserDeviceFormFactor;
  selectedMode: BrowserTabletInterfaceMode;
  selectedLabel: string;
  options: BrowserTabletInterfaceModeOptionState[];
  footerText: string;
}

interface BrowserTabletInterfaceModeDeviceFacts {
  detectedFormFactor: BrowserDeviceFormFactor;
  foldableDevice: boolean;
  smallFoldableDevice: boolean;
}

export class BrowserTabletInterfaceModeSettingsCoordinator {
  private readonly repository: BrowserTabletInterfaceModeRepository;
  private readonly privacyEffectPolicy: BrowserPrivacyEffectPolicyService;
  private readonly profileBoundaryService: BrowserProfileBoundaryService;
  private readonly deviceFormFactorCoordinator: BrowserDeviceFormFactorCoordinator =
    new BrowserDeviceFormFactorCoordinator();
  private readonly interfaceModePolicy: BrowserTabletInterfaceModePolicy =
    new BrowserTabletInterfaceModePolicy();
  private readonly presentationInputService: BrowserWindowPresentationProfileInputService =
    new BrowserWindowPresentationProfileInputService();

  constructor(
    repository: BrowserTabletInterfaceModeRepository,
    privacyEffectPolicy: BrowserPrivacyEffectPolicyService = new BrowserPrivacyEffectPolicyService(),
    profileBoundaryService: BrowserProfileBoundaryService = new BrowserProfileBoundaryService()
  ) {
    this.repository = repository;
    this.privacyEffectPolicy = privacyEffectPolicy;
    this.profileBoundaryService = profileBoundaryService;
  }

  buildState(): BrowserTabletInterfaceModeSettingsState {
    return this.buildStateForMode(this.repository.getMode());
  }

  buildStateForMode(mode: BrowserTabletInterfaceMode): BrowserTabletInterfaceModeSettingsState {
    const device = this.resolveDeviceFacts();
    const selectedMode = this.resolveSelectedModeForDevice(mode, device);
    return {
      visible: this.isSettingVisible(device.detectedFormFactor, mode),
      detectedFormFactor: device.detectedFormFactor,
      selectedMode: selectedMode,
      selectedLabel: this.resolveLabel(selectedMode),
      options: this.resolveOptions(device),
      footerText: this.resolveFooterText(device)
    };
  }

  setMode(
    mode: BrowserTabletInterfaceMode,
    boundaryInput: BrowserDataBoundaryInput,
    consumer: BrowserTabletInterfaceModeTransitionConsumer = 'phone_native_settings_handoff'
  ): Promise<BrowserTabletInterfaceModeSettingsState> {
    if (!this.canWriteDevicePreference(boundaryInput)) {
      return Promise.reject(new Error('Tablet interface mode device preference write privacy effect was not allowed.'));
    }
    if (this.repository.getMode() === mode) {
      return Promise.resolve(this.buildStateForMode(mode));
    }
    const transitionId = sharedBrowserTabletInterfaceModeTransitionOwner.begin(mode, consumer);
    return this.repository.setMode(mode)
      .then((savedMode: BrowserTabletInterfaceMode): BrowserTabletInterfaceModeSettingsState => {
        return this.buildStateForMode(savedMode);
      })
      .catch((error: Error): BrowserTabletInterfaceModeSettingsState => {
        sharedBrowserTabletInterfaceModeTransitionOwner.cancel(transitionId);
        throw error;
      });
  }

  requiresDesktopModeConfirmation(mode: BrowserTabletInterfaceMode): boolean {
    const device = this.resolveDeviceFacts();
    return mode === 'desktop' && device.detectedFormFactor === 'phone' && !device.foldableDevice;
  }

  private resolveDeviceFacts(): BrowserTabletInterfaceModeDeviceFacts {
    const detectedFormFactor = this.resolveDetectedFormFactor();
    const foldFacts = this.presentationInputService.resolveFoldPresentationFacts();
    const foldableDevice = foldFacts.capabilityConfirmed;
    // The setting describes the same device the runtime switches, so it reuses
    // the policy's identity match rather than re-deriving the foldable size.
    const smallFoldableDevice = detectedFormFactor === 'phone' && foldableDevice &&
      this.interfaceModePolicy.isKnownSmallFoldable(
        this.presentationInputService.resolveDeviceMarketName(),
        this.presentationInputService.resolveDeviceProductModel()
      );
    return {
      detectedFormFactor: detectedFormFactor,
      foldableDevice: foldableDevice,
      smallFoldableDevice: smallFoldableDevice
    };
  }

  private resolveDetectedFormFactor(): BrowserDeviceFormFactor {
    // Device type is the primary signal; when the platform reports an
    // unrecognized type (notably emulators, which report "default"), fall back
    // to the display width — a screen ≥ 840vp is treated as a tablet. Mirrors
    // the large-screen shell eligibility (resolveShellEligibility) so this
    // setting stays in sync with the shell that actually switches modes.
    return this.deviceFormFactorCoordinator.resolveShellEligibility({
      platformDeviceType: this.presentationInputService.resolvePlatformDeviceType(),
      windowWidthVp: this.presentationInputService.resolveDisplayWidthVp()
    }).detectedFormFactor;
  }

  private isSettingVisible(
    detectedFormFactor: BrowserDeviceFormFactor,
    mode: BrowserTabletInterfaceMode
  ): boolean {
    return this.interfaceModePolicy.resolve({
      detectedFormFactor: detectedFormFactor,
      selectedMode: mode,
      pointerAvailable: false,
      foldState: 'unknown'
    }).settingVisible;
  }

  private resolveLabel(mode: BrowserTabletInterfaceMode): string {
    if (mode === 'touch') {
      return resolveAppResourceText($r('app.string.settings_appearance_touch'));
    }
    if (mode === 'desktop') {
      return resolveAppResourceText($r('app.string.settings_appearance_desktop'));
    }
    return resolveAppResourceText($r('app.string.settings_appearance_auto'));
  }

  private resolveSelectedModeForDevice(
    mode: BrowserTabletInterfaceMode,
    device: BrowserTabletInterfaceModeDeviceFacts
  ): BrowserTabletInterfaceMode {
    if (device.detectedFormFactor === 'phone' && !device.foldableDevice && mode === 'auto') {
      return 'touch';
    }
    return mode;
  }

  private resolveOptions(
    device: BrowserTabletInterfaceModeDeviceFacts
  ): BrowserTabletInterfaceModeOptionState[] {
    if (device.detectedFormFactor === 'phone' && !device.foldableDevice) {
      return [
        { mode: 'touch', title: resolveAppResourceText($r('app.string.settings_appearance_touch')) },
        { mode: 'desktop', title: resolveAppResourceText($r('app.string.settings_appearance_desktop')) }
      ];
    }
    return [
      { mode: 'auto', title: resolveAppResourceText($r('app.string.settings_appearance_auto')) },
      { mode: 'touch', title: resolveAppResourceText($r('app.string.settings_appearance_touch')) },
      { mode: 'desktop', title: resolveAppResourceText($r('app.string.settings_appearance_desktop')) }
    ];
  }

  private resolveFooterText(
    device: BrowserTabletInterfaceModeDeviceFacts
  ): string {
    if (device.detectedFormFactor === 'phone' && !device.foldableDevice) {
      return resolveAppResourceText($r('app.string.tablet_touch_warning'));
    }
    if (device.smallFoldableDevice) {
      return resolveAppResourceText($r('app.string.tablet_fold_note'));
    }
    if (device.foldableDevice) {
      return resolveAppResourceText($r('app.string.tablet_auto_fold'));
    }
    return resolveAppResourceText($r('app.string.tablet_auto_pointer'));
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
