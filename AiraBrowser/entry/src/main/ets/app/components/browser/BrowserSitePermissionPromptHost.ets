import { resolveAppResourceText } from '../../../core/resources/AppResourceText';
import {
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import {
  BrowserSitePermissionDialogPresentation,
  BrowserSitePermissionPromptAction
} from '../../../core/browser/BrowserWebCapabilityPromptApplicationCoordinator';
import { BrowserSheetActionButton } from './BrowserModalBottomSheet';
import {
  resolveCenteredDialogControllerWidth,
  resolveCenteredDialogSurfaceColor,
  CENTERED_DIALOG_CORNER_RADIUS_VP,
  CENTERED_DIALOG_SYSTEM_COMPACT_SURFACE_MODIFIER
} from '../common/CenteredDialogSurface';

@CustomDialog
struct BrowserSitePermissionPromptDialog {
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  controller?: CustomDialogController;
  @Link presentation: BrowserSitePermissionDialogPresentation;
  onAction: (action: BrowserSitePermissionPromptAction) => void =
    (_action: BrowserSitePermissionPromptAction): void => {};

  build() {
    Column({ space: 8 }) {
      Text(this.presentation.title.length > 0 ? this.presentation.title : resolveAppResourceText($r('app.string.browser_ui_browser_site_permission_prompt_host_004')))
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.storedPrimaryTextColor)
        .textAlign(TextAlign.Center)

      Text(this.presentation.message)
        .width('100%')
        .fontSize(14)
        .lineHeight(20)
        .fontColor(this.storedSecondaryTextColor)
        .textAlign(TextAlign.Center)

      Column({ space: 4 }) {
        this.buildActionButton(resolveAppResourceText($r('app.string.browser_ui_browser_site_permission_prompt_host_002')), 'allow_during_use')
        this.buildActionButton(resolveAppResourceText($r('app.string.browser_ui_browser_site_permission_prompt_host_003')), 'allow_for_session')
        this.buildActionButton(resolveAppResourceText($r('app.string.browser_ui_browser_site_permission_prompt_host_001')), 'deny')
      }
      .width('100%')
    }
    .attributeModifier(CENTERED_DIALOG_SYSTEM_COMPACT_SURFACE_MODIFIER)
  }

  @Builder
  private buildActionButton(label: string, action: BrowserSitePermissionPromptAction) {
    BrowserSheetActionButton({
      label: label,
      buttonHeight: 40,
      fontSize: 15,
      fillAvailableWidth: false,
      buttonWidth: '100%',
      onAction: () => {
        this.onAction(action);
      }
    })
  }
}

@Component
export struct BrowserSitePermissionPromptHost {
  @Link @Watch('syncVisibility') visible: boolean;
  @Link presentation: BrowserSitePermissionDialogPresentation;
  onAction: (action: BrowserSitePermissionPromptAction) => Promise<boolean> =
    (_action: BrowserSitePermissionPromptAction): Promise<boolean> => Promise.resolve(false);
  onDismiss: () => void = (): void => {};
  private dialogOpen: boolean = false;
  private decisionCommitted: boolean = false;
  private dialogController: CustomDialogController = new CustomDialogController({
    alignment: DialogAlignment.Center,
    builder: BrowserSitePermissionPromptDialog({
      presentation: $presentation,
      onAction: (action: BrowserSitePermissionPromptAction): void => this.handleAction(action)
    }),
    customStyle: false,
    backgroundColor: resolveCenteredDialogSurfaceColor(),
    backgroundBlurStyle: BlurStyle.NONE,
    cornerRadius: CENTERED_DIALOG_CORNER_RADIUS_VP,
    width: resolveCenteredDialogControllerWidth('s'),
    autoCancel: true,
    onWillDismiss: (dismissDialogAction: DismissDialogAction): void => {
      if (this.decisionCommitted) {
        return;
      }
      this.handleInteractiveDismiss();
      dismissDialogAction.dismiss();
    }
  });

  aboutToAppear(): void {
    this.syncVisibility();
  }

  aboutToDisappear(): void {
    if (this.dialogOpen && !this.decisionCommitted) {
      this.decisionCommitted = true;
      this.visible = false;
      this.onDismiss();
    }
    this.closeDialog();
  }

  build() {
    Row()
      .width(0)
      .height(0)
      .hitTestBehavior(HitTestMode.None)
  }

  private syncVisibility(): void {
    if (this.visible) {
      if (!this.dialogOpen) {
        this.decisionCommitted = false;
        this.dialogOpen = true;
        this.dialogController.open();
      }
      return;
    }
    this.closeDialog();
  }

  private handleAction(action: BrowserSitePermissionPromptAction): void {
    if (this.decisionCommitted) {
      return;
    }
    this.decisionCommitted = true;
    this.onAction(action)
      .then((keepDialogOpen: boolean) => {
        if (keepDialogOpen && this.visible && this.dialogOpen) {
          this.decisionCommitted = false;
          return;
        }
        this.visible = false;
        this.closeDialog();
      })
      .catch(() => {
        this.visible = false;
        this.closeDialog();
        this.onDismiss();
      });
  }

  private handleInteractiveDismiss(): void {
    this.dialogOpen = false;
    this.visible = false;
    if (this.decisionCommitted) {
      return;
    }
    this.decisionCommitted = true;
    this.onDismiss();
  }

  private closeDialog(): void {
    if (!this.dialogOpen) {
      return;
    }
    this.dialogOpen = false;
    try {
      this.dialogController.close();
    } catch (_error) {
    }
  }
}
