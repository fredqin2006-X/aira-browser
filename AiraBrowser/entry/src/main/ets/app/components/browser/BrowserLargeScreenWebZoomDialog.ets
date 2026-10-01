import {
  BrowserLargeScreenWebZoomAction,
  BrowserLargeScreenWebZoomSnapshot
} from '../../../core/browser/BrowserLargeScreenWebZoomCoordinator';
import { CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER } from '../common/CenteredDialogSurface';
import { BrowserZoomAdjustDialogBody } from './BrowserZoomAdjustDialogBody';

@CustomDialog
export struct BrowserLargeScreenWebZoomDialog {
  controller?: CustomDialogController;
  @Link snapshot: BrowserLargeScreenWebZoomSnapshot;
  onAction: (action: BrowserLargeScreenWebZoomAction) => void =
    (_action: BrowserLargeScreenWebZoomAction): void => {};
  onClose: () => void = (): void => {};

  build() {
    BrowserZoomAdjustDialogBody({
      title: $r('app.string.web_text_zoom_dialog_title'),
      percentLabel: this.snapshot.percentLabel,
      canDecrease: this.snapshot.canDecrease,
      canIncrease: this.snapshot.canIncrease,
      canReset: this.snapshot.available && (!this.snapshot.percentKnown || this.snapshot.percent !== 100),
      decreaseLabel: $r('app.string.web_text_zoom_decrease_page'),
      increaseLabel: $r('app.string.web_text_zoom_increase_page'),
      onAdjust: (action: 'decrease' | 'increase' | 'reset'): void => {
        this.onAction(action);
      },
      onDone: (): void => {
        this.onClose();
        this.controller?.close();
      }
    })
      .attributeModifier(CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER)
  }
}
