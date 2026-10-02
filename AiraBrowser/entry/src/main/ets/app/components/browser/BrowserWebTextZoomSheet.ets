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
  onRememberSite: (remember: boolean) => void = (_remember: boolean): void => {};

  build() {
    BrowserZoomAdjustDialogBody({
      title: $r('app.string.web_text_zoom_title'),
      percentLabel: this.state.percentLabel,
      canDecrease: this.state.canDecrease,
      canIncrease: this.state.canIncrease,
      canReset: this.state.ratio !== 100,
      decreaseLabel: $r('app.string.web_text_zoom_decrease'),
      increaseLabel: $r('app.string.web_text_zoom_increase'),
      doneFlat: true,
      showRememberSite: true,
      rememberSite: this.state.rememberSite,
      rememberSiteEnabled: this.state.rememberSiteEnabled,
      rememberSiteLabel: $r('app.string.web_text_zoom_remember_site'),
      onAdjust: (action: 'decrease' | 'increase' | 'reset'): void => {
        this.onAction(action);
      },
      onRememberSiteChange: (remember: boolean): void => {
        this.onRememberSite(remember);
      },
      onDone: (): void => {
        this.controller?.close();
      }
    })
      .attributeModifier(CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER)
  }
}
