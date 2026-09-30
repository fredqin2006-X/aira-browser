import router from '@ohos.router';
import { BrowserBoundaryRouteState } from '../../common/utils/RouteParamUtils';
import { showCenteredAlertDialog } from '../components/common/CenteredDialogSurface';
import { SettingsHdsScaffold } from '../components/settings/SettingsHdsScaffold';
import { SettingsScrollBody, SettingsGroupCard } from '../components/settings/SettingsLayout';
import { SettingsActionButton, SettingsNavigationRow } from '../components/settings/SettingsRows';
import { SyncFormField } from '../components/sync/SyncFormFields';
import {
  sharedAiraSyncConfigStore,
  sharedSyncExperienceCoordinator
} from '../bootstrap/BrowserAppRuntime';
import { SettingsNavigationCoordinator } from '../router/SettingsNavigationCoordinator';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_DIVIDER_KEY,
  BROWSER_THEME_STORAGE_ON_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../core/theme/BrowserThemeStorageKeys';
import {
  AiraPersonalServerConfig,
  AiraSyncSettings,
  resolveAiraPersonalServerConfig
} from '../../common/models/AiraSyncModels';
import {
  AIRA_PERSONAL_SERVER_INSTANCE_SERVICE,
  AiraPersonalServerPairingResult
} from '../../services/sync/AiraPersonalServerInstanceService';
import { SyncExperienceActionOutcome } from '../../core/sync/SyncExperienceCoordinator';
import { SyncSettingsRefreshSignal } from '../../core/sync/SyncSettingsRefreshSignal';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';

@Entry
@Component
struct SyncPersonalServerConfigPage {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY) private storedDividerColor: string = '#E3E8EF';
  @StorageProp(BROWSER_THEME_STORAGE_ON_PRIMARY_KEY) private storedOnPrimaryColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = '#F6F8FB';
  @StorageProp(BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY) private storedPressedBackgroundColor: string = '#DDE4EC';
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private storedSurfaceBackgroundColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  private navigationCoordinator: SettingsNavigationCoordinator = new SettingsNavigationCoordinator();
  private refreshSignal: SyncSettingsRefreshSignal = new SyncSettingsRefreshSignal();
  private activateExperienceAfterPair: boolean = false;
  @State private baseUrl: string = '';
  @State private pairingCode: string = '';
  @State private deviceName: string = 'Aira HarmonyOS';
  @State private instanceId: string = '';
  @State private isBusy: boolean = false;
  @State private isConfigured: boolean = false;
  @State private statusText: string = resolveAppResourceText($r('app.string.settings_sync_self_host_status_disconnected'));

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string | undefined> | undefined;
    this.activateExperienceAfterPair = params?.syncActivateExperience === 'true';
    void sharedAiraSyncConfigStore.initialize()
      .then((settings: AiraSyncSettings): void => {
        this.applyConfig(resolveAiraPersonalServerConfig(settings));
      })
      .catch((error: Error): void => {
        this.statusText = this.stringifyError(error);
      });
  }

  onBackPress(): boolean {
    return this.isBusy;
  }

  build() {
    Column() {
      SettingsHdsScaffold({
        title: $r('app.string.settings_sync_self_host_title'),
        backIconKind: 'back',
        pageBackground: this.storedPageBackgroundColor,
        headerButtonBackground: this.storedPressedBackgroundColor,
        primaryTextColor: this.storedPrimaryTextColor,
        dividerColor: this.storedDividerColor,
        contentKind: 'readable',
        onBack: () => {
          if (!this.isBusy) {
            this.navigationCoordinator.back();
          }
        }
      }) {
        SettingsScrollBody({ contentSpace: 18, topPadding: 8, bottomPadding: 28 }) {
          // The row sits on its own surface, not straight on the page background:
          // every other settings entry on this page is a card, and a bare row here
          // read as a floating label above the form rather than a tappable entry.
          SettingsGroupCard({
            surfaceColor: this.storedSurfaceBackgroundColor
          }) {
            SettingsNavigationRow({
              title: $r('app.string.settings_sync_self_host_view_guide'),
              value: $r('app.string.settings_sync_self_host_view_guide_value'),
              airaIconId: 'settings.webdav',
              iconBackgroundColor: this.storedAccentColor,
              iconColor: this.storedOnPrimaryColor,
              rowPosition: 'single',
              primaryTextColor: this.storedPrimaryTextColor,
              secondaryTextColor: this.storedSecondaryTextColor,
              pressedBackgroundColor: this.storedPressedBackgroundColor,
              onAction: () => {
                this.navigationCoordinator.openSyncDesktopBookmarkGuide(this.buildBoundaryState());
              }
            })
          }

          SyncFormField({
            label: $r('app.string.settings_sync_self_host_server_address'),
            placeholder: 'https://sync.example.com',
            text: $baseUrl,
            inputType: InputType.URL,
            isEnabled: !this.isBusy,
            onChange: (_value: string) => {}
          })

          SyncFormField({
            label: $r('app.string.settings_sync_self_host_pairing_code'),
            placeholder: $r('app.string.settings_sync_self_host_pairing_code_placeholder'),
            text: $pairingCode,
            secure: true,
            isEnabled: !this.isBusy,
            onChange: (_value: string) => {}
          })

          SyncFormField({
            label: $r('app.string.settings_sync_self_host_device_name'),
            placeholder: 'Aira HarmonyOS',
            text: $deviceName,
            isEnabled: !this.isBusy,
            onChange: (_value: string) => {}
          })

          Text($r('app.string.settings_sync_self_host_pairing_note'))
            .width('100%')
            .fontSize(13)
            .lineHeight(19)
            .fontColor(this.storedSecondaryTextColor)
            .padding({ left: 6, right: 6 })

          if (this.isConfigured) {
            Text(`${this.statusText}\n${resolveAppResourceText(
              $r('app.string.settings_sync_self_host_instance'), this.instanceId)}`)
              .width('100%')
              .fontSize(13)
              .lineHeight(19)
              .fontColor(this.storedSecondaryTextColor)
              .padding({ left: 6, right: 6 })
          }

          Button(this.isBusy
            ? $r('app.string.settings_sync_self_host_connecting')
            : (this.isConfigured
              ? $r('app.string.settings_sync_self_host_pair_again')
              : $r('app.string.settings_sync_self_host_connect_and_pair')))
            .width('100%')
            .height(48)
            .type(ButtonType.Normal)
            .enabled(this.canPair())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.storedOnPrimaryColor)
            .backgroundColor(this.storedAccentColor)
            .borderRadius(24)
            .stateEffect(true)
            .onClick(() => {
              this.pair();
            })

          if (this.isConfigured) {
            SettingsActionButton({
              title: $r('app.string.settings_sync_self_host_disconnect'),
              emphasis: 'danger',
              isEnabled: !this.isBusy,
              pressedBackgroundColor: this.storedPressedBackgroundColor,
              onAction: () => {
                this.confirmDisconnect();
              }
            })
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.storedPageBackgroundColor)
  }

  private canPair(): boolean {
    return !this.isBusy && this.baseUrl.trim().length > 0 && this.pairingCode.trim().length > 0 &&
      this.deviceName.trim().length > 0;
  }

  /**
   * The guide is a normal settings route, so it has to travel with the same data
   * boundary this page was opened under. This page is reached from more than one
   * surface, so it reads the boundary from its own route params instead of
   * assuming a single caller.
   */
  private buildBoundaryState(): BrowserBoundaryRouteState {
    const params = router.getParams() as Record<string, string | undefined> | undefined;
    return {
      dataScope: params?.dataScope ?? '',
      privacyMode: params?.privacyMode ?? '',
      boundarySource: params?.boundarySource ?? ''
    };
  }

  private pair(): void {
    if (!this.canPair()) {
      return;
    }
    this.isBusy = true;
    this.statusText = resolveAppResourceText($r('app.string.settings_sync_self_host_status_connecting'));
    void this.pairAndPersist().finally((): void => {
      this.isBusy = false;
    });
  }

  private async pairAndPersist(): Promise<void> {
    try {
      const settings = await sharedAiraSyncConfigStore.initialize();
      const result: AiraPersonalServerPairingResult = await AIRA_PERSONAL_SERVER_INSTANCE_SERVICE.pair(
        this.baseUrl,
        this.pairingCode,
        settings.sourceId,
        this.deviceName
      );
      await sharedAiraSyncConfigStore.savePersonalServerConfig(
        result.config.baseUrl,
        result.config.instanceId,
        result.config.protocolVersion,
        result.config.credentialId,
        result.config.deviceToken,
        result.config.deviceName
      );
      if (this.activateExperienceAfterPair) {
        const outcome: SyncExperienceActionOutcome =
          await sharedSyncExperienceCoordinator.completeConfiguredGoal('self_hosted');
        if (outcome.type !== 'completed') {
          this.statusText = resolveAppResourceText($r('app.string.settings_sync_self_host_status_sync_incomplete'));
          showCenteredAlertDialog({
            title: outcome.title,
            message: outcome.message,
            autoCancel: true,
            secondaryButton: { value: $r('app.string.settings_sync_self_host_got_it'), action: () => {} }
          });
          return;
        }
      }
      this.pairingCode = '';
      this.applyConfig(result.config);
      this.statusText = this.activateExperienceAfterPair
        ? resolveAppResourceText($r('app.string.settings_sync_self_host_status_connected_sync'))
        : resolveAppResourceText($r('app.string.settings_sync_self_host_status_connected'));
      this.refreshSignal.bump();
      showCenteredAlertDialog({
        title: $r('app.string.settings_sync_self_host_connected_title'),
        message: this.activateExperienceAfterPair
          ? $r('app.string.settings_sync_self_host_connected_sync_message')
          : $r('app.string.settings_sync_self_host_connected_credentials_message'),
        autoCancel: true,
        secondaryButton: {
          value: $r('app.string.settings_sync_self_host_done'),
          action: () => { this.navigationCoordinator.back(); }
        }
      });
    } catch (error) {
      this.statusText = this.stringifyError(error as Error);
      showCenteredAlertDialog({
        title: $r('app.string.settings_sync_self_host_connect_failed_title'),
        message: this.statusText,
        autoCancel: true,
        secondaryButton: { value: $r('app.string.settings_sync_self_host_got_it'), action: () => {} }
      });
    }
  }

  private applyConfig(config: AiraPersonalServerConfig): void {
    this.baseUrl = config.baseUrl;
    this.deviceName = config.deviceName.trim().length > 0 ? config.deviceName : 'Aira HarmonyOS';
    this.instanceId = config.instanceId;
    this.isConfigured = config.instanceId.trim().length > 0 && config.deviceToken.trim().length > 0;
    this.statusText = this.isConfigured
      ? resolveAppResourceText($r('app.string.settings_sync_self_host_status_connected'))
      : resolveAppResourceText($r('app.string.settings_sync_self_host_status_disconnected'));
  }

  private confirmDisconnect(): void {
    showCenteredAlertDialog({
      title: $r('app.string.settings_sync_self_host_disconnect_confirm_title'),
      message: $r('app.string.settings_sync_self_host_disconnect_confirm_message'),
      autoCancel: true,
      primaryButton: { value: $r('app.string.settings_sync_self_host_cancel'), action: () => {} },
      secondaryButton: {
        value: $r('app.string.settings_sync_self_host_disconnect_confirm'),
        action: () => { this.disconnect(); }
      }
    });
  }

  private disconnect(): void {
    if (this.isBusy) {
      return;
    }
    this.isBusy = true;
    void sharedAiraSyncConfigStore.clearPersonalServerConfig()
      .then((): void => {
        this.applyConfig(AIRA_PERSONAL_SERVER_INSTANCE_SERVICE.clearConfig());
        this.refreshSignal.bump();
      })
      .catch((error: Error): void => {
        showCenteredAlertDialog({
          title: $r('app.string.settings_sync_self_host_disconnect_failed_title'),
          message: this.stringifyError(error),
          autoCancel: true,
          secondaryButton: { value: $r('app.string.settings_sync_self_host_got_it'), action: () => {} }
        });
      })
      .finally((): void => {
        this.isBusy = false;
      });
  }

  private stringifyError(error: Error): string {
    return error.message !== undefined && error.message.length > 0 ? error.message : JSON.stringify(error);
  }
}
