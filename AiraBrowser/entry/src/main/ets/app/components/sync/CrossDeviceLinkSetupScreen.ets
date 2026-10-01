import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { loginComponentManager } from '@kit.AccountKit';
import router from '@ohos.router';
import {
  BrowserQrScanCoordinator,
  BrowserQrScanNavigationTarget,
  BrowserQrScanSessionSnapshot,
  BrowserQrScanShell,
  BrowserQrScanSurface,
  DEFAULT_BROWSER_QR_SCAN_SESSION_SNAPSHOT
} from '../../../core/browser/BrowserQrScanCoordinator';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_DIVIDER_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_SETTINGS_ICON_FOREGROUND_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import {
  CrossDeviceLinkProviderKind,
  buildCrossDeviceLinkSteps,
  localizeCrossDeviceLinkCopy
} from '../../../core/sync/CrossDeviceLinkViewModel';
import { AIRA_DISTRIBUTION_CAPABILITY_OWNER } from '../../../common/config/AiraDistributionCapabilityOwner';
import {
  BrowserBoundaryRouteState,
  readBrowserBoundaryRouteState
} from '../../../common/utils/RouteParamUtils';
import {
  SyncDesktopExtensionEntry,
  SyncDesktopExtensionEntryId,
  resolveSyncDesktopExtensionEntries,
  resolveSyncDesktopExtensionEntryActionLabel
} from '../../../services/sync/SyncDesktopExtensionCatalog';
import { BrowserClipboardService } from '../../../services/share/BrowserClipboardService';
import { DEFAULT_THEME_PALETTE } from '../../../features/theme/palettes/DefaultThemePalette';
import {
  BrowserSettingsIconBackgroundTokenSet,
  DEFAULT_BROWSER_SETTINGS_ICON_BACKGROUND_TOKENS
} from '../../../features/theme/BrowserThemePaletteModels';
import { SettingsHdsScaffold } from '../settings/SettingsHdsScaffold';
import {
  SettingsGroupCard,
  SettingsGroupDivider,
  SettingsPresentationScrollBody,
  SettingsSection
} from '../settings/SettingsLayout';
import { SettingsNavigationRow, SettingsRowPosition } from '../settings/SettingsRows';
import { SettingsNavigationCoordinator } from '../../router/SettingsNavigationCoordinator';
import { AiraRenderableIconId } from '../../../core/resources/GeneratedAiraIconCatalog';
import { AppServiceModeGateService } from '../../../services/settings/AppServiceModeGateService';
import {
  sharedAiraSyncConfigStore,
  sharedCrossDeviceLinkGuideRepository,
  sharedHuaweiAccountMutationCoordinator,
  sharedPreferencesRepository
} from '../../bootstrap/BrowserAppRuntime';
import {
  createHiddenCrossDeviceLinkGuideSnapshot,
  CrossDeviceLinkGuideAction,
  CrossDeviceLinkGuideCoordinator,
  CrossDeviceLinkGuideSnapshot
} from '../../../core/onboarding/CrossDeviceLinkGuideCoordinator';
import { CrossDeviceLinkGuideOverlay } from '../onboarding/CrossDeviceLinkGuideOverlay';
import { BrowserSheetActionButton } from '../browser/BrowserModalBottomSheet';
import { applyDesktopDialogSheetChrome } from '../common/DesktopDialogSheetChrome';
import { DesktopLoginConfirmSheetContent } from '../settings/DesktopLoginConfirmSheetContent';
import { HuaweiLoginSheetContent } from '../account/HuaweiLoginSheetContent';
import { BrowserDataBoundaryInput } from '../../../common/models/BrowserModels';
import { SyncSettingsRefreshSignal } from '../../../core/sync/SyncSettingsRefreshSignal';
import { APP_STANDARD_HORIZONTAL_PADDING } from '../common/AppLayoutTokens';

const EXTENSION_GLYPH: AiraRenderableIconId = 'site.setting.externalActions';
const LOCAL_PACKAGE_GLYPH: AiraRenderableIconId = 'settings.downloads';
const STEP_BADGE_SIZE: number = 22;
// Browser store rows show the vendor mark itself, so it keeps the same leading width as
// the round glyph it replaces without drawing a second, brand-less circle behind it.
const BROWSER_BRAND_LEADING_SIZE: number = 34;
const BROWSER_BRAND_ICON_SIZE: number = 26;
const STEP_ROW_HORIZONTAL_PADDING: number = 16;
const STEP_ROW_VERTICAL_PADDING: number = 14;
const SETUP_FOOTER_CLEARANCE: number = 132;


/**
 * The install and pairing recipe, one level below 与电脑互联 so the overview stays a
 * status page. The mode arrives through the route, so this surface needs no sync state
 * of its own, and the page it lives in stays a shell.
 */
@Component
export struct CrossDeviceLinkSetupScreen {
  /**
   * The recipe is an ordinary settings list, so its title bar blurs as that list scrolls.
   * One scroller shared by the title bar and the body is what makes the top gradient follow
   * this page's own scroll, exactly like every other secondary settings page.
   */
  private readonly settingsScroller: Scroller = new Scroller();

  /** Bumped by the owning page's onPageShow, which only an @Entry component receives. */
  @Prop @Watch('handlePageShowRefresh') refreshToken: number = 0;
  /** Embedded in the large-screen settings pane instead of its own routed page. */
  @Prop embedded: boolean = false;
  @Prop desktopPresentation: boolean = false;
  @Prop @Watch('handleEmbeddedProviderChange') providerKind: CrossDeviceLinkProviderKind = 'none';
  /** When embedded, back exits the workspace pane instead of popping the router. */
  onExit?: () => void;
  /** Provided by the PC shell, which opens the link in the browser instead of routing. */
  onOpenExternalUrl?: (url: string) => void;
  /** The hosting page already owns the scanner and its confirm sheets. */
  onScan?: () => void;
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string =
    DEFAULT_THEME_PALETTE.light.accent;
  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY) private storedDividerColor: string = DEFAULT_THEME_PALETTE.light.divider;
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string =
    DEFAULT_THEME_PALETTE.light.pageBackground;
  @StorageProp(BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY) private storedPressedBackgroundColor: string =
    DEFAULT_THEME_PALETTE.light.pressedBackground;
  @StorageProp(BROWSER_THEME_STORAGE_SETTINGS_ICON_FOREGROUND_KEY) private storedSettingsIconForegroundColor: string =
    DEFAULT_THEME_PALETTE.light.settingsIconForeground;
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private storedSurfaceBackgroundColor: string =
    DEFAULT_THEME_PALETTE.light.surfaceBackground;
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string =
    DEFAULT_THEME_PALETTE.light.textPrimary;
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string =
    DEFAULT_THEME_PALETTE.light.textSecondary;
  @State private steps: string[] = [];
  @State private installEntries: SyncDesktopExtensionEntry[] = resolveSyncDesktopExtensionEntries();
  @State private settingsIconBackgrounds: BrowserSettingsIconBackgroundTokenSet =
    DEFAULT_BROWSER_SETTINGS_ICON_BACKGROUND_TOKENS;
  private readonly navigationCoordinator: SettingsNavigationCoordinator = new SettingsNavigationCoordinator();
  private readonly clipboardService: BrowserClipboardService = new BrowserClipboardService();
  private readonly appServiceModeGateService: AppServiceModeGateService =
    new AppServiceModeGateService(sharedPreferencesRepository);
  private boundary: BrowserBoundaryRouteState = {
    dataScope: '',
    privacyMode: '',
    boundarySource: ''
  };
  @State private guideSnapshot: CrossDeviceLinkGuideSnapshot = createHiddenCrossDeviceLinkGuideSnapshot();
  @State private confirmSheetVisible: boolean = false;
  @State private loginSheetVisible: boolean = false;
  @State private qrScanSnapshot: BrowserQrScanSessionSnapshot = DEFAULT_BROWSER_QR_SCAN_SESSION_SNAPSHOT;
  private guideCoordinator: CrossDeviceLinkGuideCoordinator = new CrossDeviceLinkGuideCoordinator(
    sharedCrossDeviceLinkGuideRepository,
    {
      publishState: (snapshot: CrossDeviceLinkGuideSnapshot): void => {
        this.guideSnapshot = snapshot;
      },
      openGuide: (): void => {
        // Already on 互联教程. The lesson's last step only needs to close.
      }
    }
  );
  private scanInFlight: boolean = false;
  private pendingForegroundSheet: 'none' | 'desktop_login' | 'huawei_login' = 'none';
  private huaweiLoginCompleted: boolean = false;
  private preservePendingDesktopLogin: boolean = false;
  private reopenHuaweiLoginOnShow: boolean = false;
  private readonly huaweiLoginController: loginComponentManager.LoginWithHuaweiIDButtonController =
    new loginComponentManager.LoginWithHuaweiIDButtonController()
      .onClickLoginWithHuaweiIDButton((error: BusinessError | undefined, response: loginComponentManager.HuaweiIDCredential): void => {
        this.handleHuaweiLoginResult(error, response);
      })
      .setAgreementStatus(loginComponentManager.AgreementStatus.NOT_ACCEPTED);
  private readonly qrScanShell: BrowserQrScanShell = {
    publishSnapshot: (snapshot: BrowserQrScanSessionSnapshot): void => {
      this.qrScanSnapshot = snapshot;
    },
    showToast: (message: string): void => {
      this.showToast(message);
    },
    openNavigation: (_target: BrowserQrScanNavigationTarget, value: string): void => {
      this.openUrlInBrowser(value);
    },
    requestAccountSignIn: (): boolean => {
      return this.requestHuaweiLoginSheet();
    },
    setSurfaceVisible: (surface: BrowserQrScanSurface, visible: boolean): void => {
      if (surface !== 'desktop_login_confirm') {
        return;
      }
      if (!visible) {
        this.pendingForegroundSheet = 'none';
        this.confirmSheetVisible = false;
        return;
      }
      this.requestForegroundSheet('desktop_login');
    }
  };
  private readonly qrScanCoordinator: BrowserQrScanCoordinator =
    new BrowserQrScanCoordinator(sharedAiraSyncConfigStore, this.qrScanShell);

  aboutToAppear(): void {
    this.refresh();
  }

  private handlePageShowRefresh(): void {
    this.refresh();
    if (this.reopenHuaweiLoginOnShow) {
      this.reopenHuaweiLoginOnShow = false;
      this.loginSheetVisible = true;
    }
    this.flushPendingForegroundSheet();
  }

  build() {
    Stack() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        SettingsHdsScaffold({
          title: $r('app.string.settings_link_tutorial'),
          scrollers: [this.settingsScroller],
          backIconKind: 'back',
          pageBackground: this.storedPageBackgroundColor,
          headerButtonBackground: this.storedPressedBackgroundColor,
          primaryTextColor: this.storedPrimaryTextColor,
          dividerColor: this.storedDividerColor,
          showBackButton: !this.embedded,
          showTitleBar: !this.embedded,
          useTopSafeInset: !this.embedded,
          desktopPresentation: this.desktopPresentation,
          onBack: (): void => {
            this.handleBack();
          }
        }) {
          SettingsPresentationScrollBody({
            scroller: this.settingsScroller,
            desktopPresentation: this.desktopPresentation,
            contentSpace: 16,
            topPadding: 8,
            bottomPadding: SETUP_FOOTER_CLEARANCE
          }) {
            this.buildStepsSection()
            this.buildInstallSection()
          }
        }
      }
      .width('100%')
      .height('100%')

      this.buildFloatingActions()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.storedPageBackgroundColor)

    CrossDeviceLinkGuideOverlay({
      visible: this.guideSnapshot.visible,
      state: this.guideSnapshot,
      desktopPresentation: this.desktopPresentation,
      onAction: (action: CrossDeviceLinkGuideAction): void => {
        this.guideCoordinator.handleAction(action);
      }
    })

    Column()
      .width(0)
      .height(0)
      .bindSheet($$this.confirmSheetVisible, this.buildDesktopLoginConfirmSheet(), applyDesktopDialogSheetChrome({
        preferType: this.desktopPresentation ? SheetType.CENTER : SheetType.BOTTOM,
        height: SheetSize.FIT_CONTENT,
        dragBar: !this.desktopPresentation,
        showClose: false,
        onDisappear: (): void => {
          this.handleConfirmSheetDisappear();
        }
      }, 's', this.desktopPresentation))

    Column()
      .width(0)
      .height(0)
      .bindSheet($$this.loginSheetVisible, this.buildHuaweiLoginSheet(), applyDesktopDialogSheetChrome({
        preferType: this.desktopPresentation ? SheetType.CENTER : SheetType.BOTTOM,
        height: SheetSize.FIT_CONTENT,
        dragBar: !this.desktopPresentation,
        showClose: false,
        onDisappear: (): void => {
          this.handleLoginSheetDisappear();
        }
      }, 'm', this.desktopPresentation))
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildFloatingActions() {
    Column({ space: 4 }) {
      Text($r('app.string.settings_link_view_demo'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.storedAccentColor)
        .height(36)
        .padding({ left: 12, right: 12 })
        .onClick((): void => {
          this.guideCoordinator.replay();
        })

      BrowserSheetActionButton({
        label: $r('app.string.settings_link_scan'),
        emphasis: 'primary',
        stacked: true,
        accentColor: this.storedAccentColor,
        buttonHeight: 48,
        fontSize: 16,
        onAction: (): void => {
          this.startScan();
        }
      })
    }
    .width('100%')
    .padding({
      left: APP_STANDARD_HORIZONTAL_PADDING,
      right: APP_STANDARD_HORIZONTAL_PADDING,
      bottom: 24
    })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  private buildStepsSection() {
    SettingsSection({
      title: $r('app.string.settings_link_steps_section'),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      SettingsGroupCard({
        surfaceColor: this.storedSurfaceBackgroundColor
      }) {
        ForEach(this.steps, (step: string, index: number) => {
          this.buildStepRow(`${index + 1}`, step, index > 0)
        }, (step: string, index: number): string => `${index}-${step}`)
      }
    }
  }

  @Builder
  private buildStepRow(step: string, title: string, withDivider: boolean) {
    Column({ space: 0 }) {
      if (withDivider) {
        SettingsGroupDivider({ dividerColor: this.storedDividerColor })
      }

      Row({ space: 12 }) {
        // Neutral numerals, not a brand-colored badge: the steps are structure, not
        // an action, so they read as plain black on white.
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(STEP_BADGE_SIZE)
            .height(STEP_BADGE_SIZE)
            .borderRadius(STEP_BADGE_SIZE / 2)
            .backgroundColor(this.storedPrimaryTextColor)

          Text(step)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.storedSurfaceBackgroundColor)
        }
        .width(STEP_BADGE_SIZE)
        .height(STEP_BADGE_SIZE)

        Text(localizeCrossDeviceLinkCopy(title))
          .layoutWeight(1)
          .fontSize(15)
          .fontColor(this.storedPrimaryTextColor)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({
        left: STEP_ROW_HORIZONTAL_PADDING,
        right: STEP_ROW_HORIZONTAL_PADDING,
        top: STEP_ROW_VERTICAL_PADDING,
        bottom: STEP_ROW_VERTICAL_PADDING
      })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
  }

  @Builder
  private buildInstallSection() {
    SettingsSection({
      title: $r('app.string.settings_link_install_section'),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      SettingsGroupCard({
        surfaceColor: this.storedSurfaceBackgroundColor
      }) {
        ForEach(this.installEntries, (entry: SyncDesktopExtensionEntry, index: number) => {
          if (index > 0) {
            SettingsGroupDivider({ dividerColor: this.storedDividerColor })
          }
          SettingsNavigationRow({
            title: localizeCrossDeviceLinkCopy(entry.title),
            value: localizeCrossDeviceLinkCopy(resolveSyncDesktopExtensionEntryActionLabel(entry)),
            useCustomLeading: this.isBrowserBrandEntry(entry.id),
            airaIconId: this.isBrowserBrandEntry(entry.id)
              ? undefined
              : (entry.action === 'open_link' ? LOCAL_PACKAGE_GLYPH : EXTENSION_GLYPH),
            iconBackgroundColor: this.isBrowserBrandEntry(entry.id)
              ? undefined
              : (entry.action === 'open_link'
                ? this.settingsIconBackgrounds.downloads
                : this.settingsIconBackgrounds.siteCustomization),
            iconColor: this.storedSettingsIconForegroundColor,
            rowPosition: this.resolveRowPosition(index, this.installEntries.length),
            primaryTextColor: this.storedPrimaryTextColor,
            secondaryTextColor: this.storedSecondaryTextColor,
            pressedBackgroundColor: this.storedPressedBackgroundColor,
            onAction: (): void => {
              this.handleInstallEntry(entry);
            },
            customLeading: () => {
              this.buildBrowserBrandLeading(entry.id);
            }
          })
        }, (entry: SyncDesktopExtensionEntry): string => entry.id)
      }

      Text($r('app.string.settings_link_install_note'))
        .width('100%')
        .fontSize(13)
        .lineHeight(19)
        .fontColor(this.storedSecondaryTextColor)
        .padding({ left: 4, right: 4 })

      Text($r('app.string.settings_link_install_family'))
        .width('100%')
        .fontSize(13)
        .lineHeight(19)
        .fontColor(this.storedSecondaryTextColor)
        .padding({ left: 4, right: 4 })
    }
  }

  private refresh(): void {
    if (!this.appServiceModeGateService.canUseOptionalService()) {
      this.handleBack();
      return;
    }
    const params = router.getParams() as Record<string, string | undefined> | undefined;
    this.boundary = readBrowserBoundaryRouteState(this.boundary);
    // Embedded, the owning host already resolved the mode and passes it as a prop; the
    // routed page keeps reading it from its own route instead.
    const providerKind = this.embedded
      ? this.providerKind
      : this.resolveProviderKind(params?.crossDeviceLinkProvider ?? '');
    this.steps = buildCrossDeviceLinkSteps(
      providerKind,
      AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('aira_cloud')
    );
  }

  private handleEmbeddedProviderChange(): void {
    if (this.embedded) {
      this.refresh();
    }
  }

  private handleBack(): void {
    if (this.onExit !== undefined) {
      this.onExit();
      return;
    }
    this.navigationCoordinator.back();
  }

  private resolveProviderKind(value: string): CrossDeviceLinkProviderKind {
    if (value === 'aira_cloud' || value === 'self_hosted' || value === 'webdav' ||
      value === 'huawei_space' || value === 'none') {
      return value;
    }
    return 'none';
  }

  private resolveRowPosition(index: number, total: number): SettingsRowPosition {
    if (total <= 1) {
      return 'single';
    }
    if (index === 0) {
      return 'first';
    }
    return index === total - 1 ? 'last' : 'middle';
  }

  @Builder
  private buildBrowserBrandLeading(id: SyncDesktopExtensionEntryId) {
    Stack({ alignContent: Alignment.Center }) {
      Image(this.resolveBrowserBrandIcon(id))
        .width(BROWSER_BRAND_ICON_SIZE)
        .height(BROWSER_BRAND_ICON_SIZE)
        .objectFit(ImageFit.Contain)
    }
    .width(BROWSER_BRAND_LEADING_SIZE)
    .height(BROWSER_BRAND_LEADING_SIZE)
  }

  private isBrowserBrandEntry(id: SyncDesktopExtensionEntryId): boolean {
    return id === 'chrome' || id === 'edge' || id === 'firefox';
  }

  private resolveBrowserBrandIcon(id: SyncDesktopExtensionEntryId): Resource {
    if (id === 'edge') {
      return $r('app.media.sync_browser_edge');
    }
    if (id === 'firefox') {
      return $r('app.media.sync_browser_firefox');
    }
    return $r('app.media.sync_browser_chrome');
  }

  private handleInstallEntry(entry: SyncDesktopExtensionEntry): void {
    if (entry.action === 'open_link') {
      this.openLockedPage(entry);
      return;
    }
    if (entry.url.length === 0) {
      this.showToast($r('app.string.settings_link_copy_empty'));
      return;
    }
    void this.clipboardService.copyText({
      value: entry.url,
      emptyMessage: ' ',
      successMessage: ' ',
      failureMessage: ' '
    }).catch((): undefined => undefined).then((result): void => {
      this.showToast(result !== undefined && result.ok
        ? $r('app.string.settings_link_copied')
        : $r('app.string.settings_account_copy_failed'));
    });
  }

  /**
   * The download page is password protected, so the password lands on the clipboard
   * first and a light toast says it is ready to paste as the page opens.
   */
  private openLockedPage(entry: SyncDesktopExtensionEntry): void {
    if (entry.password.length === 0) {
      this.openUrlInBrowser(entry.url);
      return;
    }
    void this.clipboardService.copyText({
      value: entry.password,
      emptyMessage: ' ',
      successMessage: ' ',
      failureMessage: ' '
    }).catch((): undefined => undefined).then((result): void => {
      this.showToast(result !== undefined && result.ok
        ? $r('app.string.settings_link_password_copied')
        : $r('app.string.settings_link_password_failed'));
      this.openUrlInBrowser(entry.url);
    });
  }

  private openUrlInBrowser(url: string): void {
    if (url.length === 0) {
      return;
    }
    // The PC shell hosts settings in the tab's native route, where router.back cannot bring
    // the page forward; it hands us its own opener so the link really opens.
    if (this.onOpenExternalUrl !== undefined) {
      this.onOpenExternalUrl(url);
      return;
    }
    this.navigationCoordinator.openBrowserUrlFromGuide(url, this.boundary);
  }

  private showToast(message: ResourceStr): void {
    this.getUIContext().getPromptAction().showToast({
      message: message,
      duration: 1800
    });
  }

  private startScan(): void {
    if (this.onScan !== undefined) {
      this.onScan();
      return;
    }
    if (this.scanInFlight) {
      return;
    }
    this.scanInFlight = true;
    void this.qrScanCoordinator.scan(this.getHostContext(), false)
      .catch((): undefined => undefined)
      .then((): void => {
        this.scanInFlight = false;
        this.flushPendingForegroundSheet();
      });
  }

  @Builder
  private buildDesktopLoginConfirmSheet() {
    DesktopLoginConfirmSheetContent({
      displayName: this.qrScanSnapshot.desktopLoginDisplayName,
      uid: this.qrScanSnapshot.desktopLoginUid,
      avatarUri: this.qrScanSnapshot.desktopLoginAvatarUri,
      confirming: this.qrScanSnapshot.desktopLoginConfirming,
      onAction: (action): void => {
        this.qrScanCoordinator.handleDesktopLoginConfirmAction(action);
      }
    })
  }

  @Builder
  private buildHuaweiLoginSheet() {
    HuaweiLoginSheetContent({
      controller: this.huaweiLoginController,
      onOpenUserAgreement: (): void => {
        this.openLoginLegalDocument('user_agreement');
      },
      onOpenPrivacyPolicy: (): void => {
        this.openLoginLegalDocument('privacy');
      }
    })
  }

  private requestForegroundSheet(kind: 'desktop_login' | 'huawei_login'): void {
    this.pendingForegroundSheet = kind;
    if (!this.scanInFlight) {
      this.flushPendingForegroundSheet();
    }
  }

  private flushPendingForegroundSheet(): void {
    if (this.pendingForegroundSheet === 'none') {
      return;
    }
    const kind = this.pendingForegroundSheet;
    this.pendingForegroundSheet = 'none';
    if (kind === 'desktop_login') {
      this.confirmSheetVisible = true;
      return;
    }
    this.loginSheetVisible = true;
  }

  private requestHuaweiLoginSheet(): boolean {
    if (!sharedHuaweiAccountMutationCoordinator.canSignIn(this.buildBoundaryInput())) {
      this.showToast($r('app.string.settings_pro_sign_in_private'));
      return true;
    }
    this.requestForegroundSheet('huawei_login');
    return true;
  }

  private buildBoundaryInput(): BrowserDataBoundaryInput {
    return {
      dataScope: this.boundary.dataScope,
      privacyMode: this.boundary.privacyMode
    };
  }

  private openLoginLegalDocument(kind: string): void {
    this.preservePendingDesktopLogin = true;
    this.reopenHuaweiLoginOnShow = true;
    this.loginSheetVisible = false;
    if (kind === 'privacy') {
      this.navigationCoordinator.openPrivacyStatement(this.boundary);
      return;
    }
    this.navigationCoordinator.openLegalWebDocument('user_service_agreement', this.boundary);
  }

  private handleConfirmSheetDisappear(): void {
    if (this.confirmSheetVisible) {
      return;
    }
    if (!this.qrScanSnapshot.desktopLoginConfirming) {
      this.qrScanCoordinator.handleSurfaceDismissed('desktop_login_confirm');
    }
  }

  private handleLoginSheetDisappear(): void {
    if (this.loginSheetVisible) {
      return;
    }
    if (!this.huaweiLoginCompleted && !this.preservePendingDesktopLogin) {
      this.qrScanCoordinator.cancelPendingDesktopLogin();
    }
    this.huaweiLoginCompleted = false;
    this.preservePendingDesktopLogin = false;
  }

  private handleHuaweiLoginResult(
    error: BusinessError | undefined,
    response: loginComponentManager.HuaweiIDCredential
  ): void {
    if (error !== undefined) {
      if (error.code !== 1001502012) {
        this.showToast(error.message.length > 0 ? error.message : $r('app.string.settings_pro_sign_in_failed'));
      }
      return;
    }
    if (response.authorizationCode.trim().length <= 0 && response.openID.trim().length <= 0) {
      this.showToast($r('app.string.settings_pro_sign_in_incomplete'));
      return;
    }
    this.huaweiLoginCompleted = true;
    this.loginSheetVisible = false;
    sharedHuaweiAccountMutationCoordinator.signIn(this.buildBoundaryInput())
      .then((result): void => {
        if (result.type === 'failed') {
          this.showToast(result.message.length > 0 ? result.message : result.title);
          this.qrScanCoordinator.cancelPendingDesktopLogin();
          return;
        }
        new SyncSettingsRefreshSignal().bump();
        this.qrScanCoordinator.resumeDesktopLoginAfterSignIn();
      })
      .catch((): void => {
        this.showToast($r('app.string.settings_pro_sign_in_failed'));
        this.qrScanCoordinator.cancelPendingDesktopLogin();
      });
  }

  private getHostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }
}
