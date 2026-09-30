import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BrowserScreenOrientationMode } from '../../core/browser/BrowserScreenOrientationViewModel';

export interface BrowserScreenOrientationApplyResult {
  mode: BrowserScreenOrientationMode;
  message: ResourceStr;
}

export class BrowserScreenOrientationService {
  async applyMode(
    context: common.UIAbilityContext,
    mode: BrowserScreenOrientationMode
  ): Promise<BrowserScreenOrientationApplyResult> {
    const mainWindow = await window.getLastWindow(context);
    await mainWindow.setPreferredOrientation(this.resolveWindowOrientation(mode));
    return {
      mode: mode,
      message: this.resolveSuccessMessage(mode)
    };
  }

  resolveWindowOrientation(mode: BrowserScreenOrientationMode): window.Orientation {
    if (mode === 'portrait') {
      return window.Orientation.PORTRAIT;
    }
    if (mode === 'landscape') {
      return window.Orientation.LANDSCAPE;
    }
    return window.Orientation.AUTO_ROTATION_UNSPECIFIED;
  }

  private resolveSuccessMessage(mode: BrowserScreenOrientationMode): ResourceStr {
    if (mode === 'portrait') {
      return $r('app.string.settings_screen_orientation_applied_portrait');
    }
    if (mode === 'landscape') {
      return $r('app.string.settings_screen_orientation_applied_landscape');
    }
    return $r('app.string.settings_screen_orientation_applied_system');
  }
}
