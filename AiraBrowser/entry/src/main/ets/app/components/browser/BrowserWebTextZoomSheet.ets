import {
  BrowserWebTextZoomAction,
  BrowserWebTextZoomState
} from '../../../core/browser/BrowserWebTextZoomViewModel';
import { CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER } from '../common/CenteredDialogSurface';
import { BrowserZoomAdjustDialogBody } from './BrowserZoomAdjustDialogBody';

@CustomDialog
export struct BrowserWebTextZoomSheet {
  controller?: CustomDialogController;
  @Link state: BrowserWebTextZoomState;
  onAction: (action: BrowserWebTextZoomAction) => void = (_action: BrowserWebTextZoomAction) => {};

  build() {
    BrowserZoomAdjustDialogBody({
      title: $r('app.string.web_text_zoom_title'),
      percentLabel: this.state.percentLabel,
      canDecrease: this.state.canDecrease,
      canIncrease: this.state.canIncrease,
      canReset: this.state.ratio !== 100,
      decreaseLabel: $r('app.string.web_text_zoom_decrease'),
      increaseLabel: $r('app.string.web_text_zoom_increase'),
      onDecrease: (): void => {
        this.onAction('decrease');
      },
      onIncrease: (): void => {
        this.onAction('increase');
      },
      onReset: (): void => {
        this.onAction('reset');
      },
      onDone: (): void => {
        this.controller?.close();
      }
    })
      .attributeModifier(CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER)
  }
}
