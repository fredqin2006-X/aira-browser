import { resolveAppResourceText } from '../../../core/resources/AppResourceText';
import { WebLoadErrorPresentation } from '../../../services/web/WebLoadErrorPresentationService';
import { BrowserWebLoadErrorSurfaceAction } from '../../../core/browser/BrowserWebPageLifecycleApplicationCoordinator';
import { BrowserWebErrorSurface } from './BrowserWebErrorSurface';

@Component
export struct BrowserWebErrorLayer {
  @Prop visible: boolean = false;
  @Prop presentation: WebLoadErrorPresentation = {
    title: '',
    summary: '',
    host: '',
    primaryActionLabel: resolveAppResourceText($r('app.string.browser_ui_browser_large_screen_vertical_tabs_sidebar_010')),
    secondaryActionLabel: resolveAppResourceText($r('app.string.settings_general_open_home')),
    tertiaryActionLabel: resolveAppResourceText($r('app.string.settings_sync_advanced_copy_details')),
    detailLabel: resolveAppResourceText($r('app.string.browser_ui_browser_web_error_surface_003')),
    detailText: '',
    hints: []
  };
  @Prop bottomChromeInsetVp: number = 0;
  onAction: (action: BrowserWebLoadErrorSurfaceAction) => void =
    (_action: BrowserWebLoadErrorSurfaceAction): void => {};

  build() {
    if (this.visible) {
      BrowserWebErrorSurface({
        presentation: this.presentation,
        bottomChromeInsetVp: this.bottomChromeInsetVp,
        onReload: () => {
          this.onAction('reload');
        },
        onSecondaryAction: () => {
          this.onAction('open_network_settings');
        }
      })
        .width('100%')
        .height('100%')
        .zIndex(1)
    }
  }
}
