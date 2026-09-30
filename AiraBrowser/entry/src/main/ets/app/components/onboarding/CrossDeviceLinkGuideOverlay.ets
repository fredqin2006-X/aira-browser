import {
  createHiddenCrossDeviceLinkGuideSnapshot,
  CrossDeviceLinkGuideAction,
  CrossDeviceLinkGuideSnapshot
} from '../../../core/onboarding/CrossDeviceLinkGuideCoordinator';
import { BROWSER_THEME_STORAGE_FLOATING_SURFACE_KEY } from '../../../core/theme/BrowserThemeStorageKeys';
import { applyDesktopDialogSheetChrome } from '../common/DesktopDialogSheetChrome';
import { CrossDeviceLinkGuideSheet } from './CrossDeviceLinkGuideSheet';

/**
 * The one-time lesson shown the first time 与电脑互联 is opened. On a phone it is the
 * system's tallest bottom sheet, edge to edge. It does not replace the page.
 */
@Component
export struct CrossDeviceLinkGuideOverlay {
  @StorageProp(BROWSER_THEME_STORAGE_FLOATING_SURFACE_KEY) private storedFloatingSurfaceColor: string = '#FFFFFF';
  @Prop @Watch('syncSheetVisible') visible: boolean = false;
  @Prop state: CrossDeviceLinkGuideSnapshot = createHiddenCrossDeviceLinkGuideSnapshot();
  @Prop desktopPresentation: boolean = false;
  onAction: (action: CrossDeviceLinkGuideAction) => void = (_action: CrossDeviceLinkGuideAction) => {};
  @State private sheetVisible: boolean = false;

  aboutToAppear(): void {
    this.syncSheetVisible();
  }

  build() {
    Column()
      .width(0)
      .height(0)
      .bindSheet($$this.sheetVisible, this.buildGuideSheet(), applyDesktopDialogSheetChrome({
        preferType: SheetType.BOTTOM,
        height: SheetSize.LARGE,
        dragBar: false,
        showClose: false,
        backgroundColor: this.storedFloatingSurfaceColor,
        onWillDismiss: (action: DismissSheetAction): void => {
          if (action.reason === DismissReason.TOUCH_OUTSIDE) {
            return;
          }
          action.dismiss();
        },
        onDisappear: (): void => {
          this.sheetVisible = false;
          if (this.visible) {
            this.onAction('dismiss');
          }
        }
      }, 'l', this.desktopPresentation, true))
  }

  @Builder
  private buildGuideSheet() {
    CrossDeviceLinkGuideSheet({
      state: this.state,
      onAction: (action: CrossDeviceLinkGuideAction): void => {
        this.onAction(action);
      }
    })
  }

  private syncSheetVisible(): void {
    this.sheetVisible = this.visible;
  }
}
