import { common } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';

export interface NativeVideoFullscreenOrientationReapplyHost {
  getContext: () => common.UIAbilityContext;
  isFullscreenActive: () => boolean;
}

const ORIENTATION_REAPPLY_FIRST_DELAY_MS: number = 120;
const ORIENTATION_REAPPLY_SECOND_DELAY_MS: number = 360;

export class NativeVideoFullscreenWindowService {
  private orientationReapplyFirstTimer: number = -1;
  private orientationReapplySecondTimer: number = -1;
  private restoreOrientationReapplyFirstTimer: number = -1;
  private restoreOrientationReapplySecondTimer: number = -1;

  async resolveRestoreOrientation(
    context: common.UIAbilityContext,
    selectedOrientation: window.Orientation
  ): Promise<window.Orientation> {
    const followsSystem = selectedOrientation === window.Orientation.AUTO_ROTATION_RESTRICTED ||
      selectedOrientation === window.Orientation.AUTO_ROTATION_UNSPECIFIED;
    if (!followsSystem) {
      return selectedOrientation;
    }
    try {
      // Read before the first await. A portrait takeover can rotate the window while
      // getLastWindow is pending, and a late snapshot would restore portrait.
      const mainWindow = this.resolveMainWindow(context) ?? await window.getLastWindow(context);
      return this.resolveSystemRestoreOrientation(this.readDisplayOrientation(mainWindow));
    } catch (_error) {
      return window.Orientation.AUTO_ROTATION_UNSPECIFIED;
    }
  }

  private resolveMainWindow(context: common.UIAbilityContext): window.Window | undefined {
    try {
      return context.windowStage.getMainWindowSync();
    } catch (_error) {
      return undefined;
    }
  }

  private readDisplayOrientation(mainWindow: window.Window): display.Orientation {
    const windowProperties = mainWindow.getWindowProperties();
    const currentDisplay = windowProperties.displayId === undefined ?
      display.getDefaultDisplaySync() :
      display.getDisplayByIdSync(windowProperties.displayId);
    return currentDisplay.orientation;
  }

  scheduleOrientationReapply(
    orientation: window.Orientation,
    host: NativeVideoFullscreenOrientationReapplyHost
  ): void {
    this.cancelOrientationReapply();
    this.orientationReapplyFirstTimer = setTimeout(() => {
      this.orientationReapplyFirstTimer = -1;
      this.reapplyOrientation(orientation, host);
    }, ORIENTATION_REAPPLY_FIRST_DELAY_MS);
    this.orientationReapplySecondTimer = setTimeout(() => {
      this.orientationReapplySecondTimer = -1;
      this.reapplyOrientation(orientation, host);
    }, ORIENTATION_REAPPLY_SECOND_DELAY_MS);
  }

  cancelOrientationReapply(): void {
    if (this.orientationReapplyFirstTimer >= 0) {
      clearTimeout(this.orientationReapplyFirstTimer);
      this.orientationReapplyFirstTimer = -1;
    }
    if (this.orientationReapplySecondTimer >= 0) {
      clearTimeout(this.orientationReapplySecondTimer);
      this.orientationReapplySecondTimer = -1;
    }
    this.cancelRestoreOrientationReapply();
  }

  async enterFullscreenWindow(
    context: common.UIAbilityContext,
    orientation: window.Orientation,
    restoreOrientation: window.Orientation
  ): Promise<boolean> {
    this.cancelRestoreOrientationReapply();
    try {
      const mainWindow = await window.getLastWindow(context);
      await mainWindow.setWindowLayoutFullScreen(true);
      // The navigation bar and the orientation lock are best-effort: a 2-in-1/PC
      // window has no navigation bar and rejects an orientation lock, and that
      // must not abort the full-screen transition (nor stop the large-screen
      // chrome from collapsing) on that form factor.
      try {
        await mainWindow.setSpecificSystemBarEnabled('navigation', false, true);
      } catch (_navigationError) {
      }
      await this.applyPreferredOrientation(mainWindow, orientation);
      return true;
    } catch (_error) {
      await this.restoreFullscreenWindow(context, restoreOrientation);
      return false;
    }
  }

  async restoreFullscreenWindow(
    context: common.UIAbilityContext,
    orientation: window.Orientation
  ): Promise<void> {
    this.cancelRestoreOrientationReapply();
    try {
      const mainWindow = await window.getLastWindow(context);
      try {
        await mainWindow.setPreferredOrientation(orientation);
      } catch (_orientationError) {
      }
      try {
        await mainWindow.setSpecificSystemBarEnabled('navigation', true, true);
      } catch (_navigationError) {
      }
      try {
        await mainWindow.setWindowLayoutFullScreen(true);
      } catch (_layoutError) {
      }
    } catch (_windowError) {
    }
    // Exiting element fullscreen can write orientation after this call. Reapply the
    // pre-takeover direction so a portrait video does not leave a landscape tablet portrait.
    this.scheduleRestoreOrientationReapply(context, orientation);
  }

  private async applyPreferredOrientation(
    mainWindow: window.Window,
    orientation: window.Orientation
  ): Promise<void> {
    try {
      await mainWindow.setPreferredOrientation(orientation);
    } catch (_orientationError) {
    }
  }

  private reapplyOrientation(
    orientation: window.Orientation,
    host: NativeVideoFullscreenOrientationReapplyHost
  ): void {
    if (!host.isFullscreenActive()) {
      return;
    }
    window.getLastWindow(host.getContext())
      .then((mainWindow: window.Window) => {
        void mainWindow.setPreferredOrientation(orientation)
          .catch((_error: Error) => {
          });
      })
      .catch((_error: Error) => {
      });
  }

  private scheduleRestoreOrientationReapply(
    context: common.UIAbilityContext,
    orientation: window.Orientation
  ): void {
    this.restoreOrientationReapplyFirstTimer = setTimeout(() => {
      this.restoreOrientationReapplyFirstTimer = -1;
      this.reapplyRestoreOrientation(context, orientation);
    }, ORIENTATION_REAPPLY_FIRST_DELAY_MS);
    this.restoreOrientationReapplySecondTimer = setTimeout(() => {
      this.restoreOrientationReapplySecondTimer = -1;
      this.reapplyRestoreOrientation(context, orientation);
    }, ORIENTATION_REAPPLY_SECOND_DELAY_MS);
  }

  private cancelRestoreOrientationReapply(): void {
    if (this.restoreOrientationReapplyFirstTimer >= 0) {
      clearTimeout(this.restoreOrientationReapplyFirstTimer);
      this.restoreOrientationReapplyFirstTimer = -1;
    }
    if (this.restoreOrientationReapplySecondTimer >= 0) {
      clearTimeout(this.restoreOrientationReapplySecondTimer);
      this.restoreOrientationReapplySecondTimer = -1;
    }
  }

  private reapplyRestoreOrientation(
    context: common.UIAbilityContext,
    orientation: window.Orientation
  ): void {
    window.getLastWindow(context)
      .then((mainWindow: window.Window) => {
        void mainWindow.setPreferredOrientation(orientation)
          .catch((_error: Error) => {
          });
      })
      .catch((_error: Error) => {
      });
  }

  private resolveSystemRestoreOrientation(
    orientation: display.Orientation
  ): window.Orientation {
    switch (orientation) {
      case display.Orientation.PORTRAIT:
      case display.Orientation.PORTRAIT_INVERTED:
        return window.Orientation.USER_ROTATION_PORTRAIT;
      case display.Orientation.LANDSCAPE:
      case display.Orientation.LANDSCAPE_INVERTED:
        // USER_ROTATION_LANDSCAPE snaps the window back to landscape, then follows the
        // sensor. AUTO_ROTATION_UNSPECIFIED does not snap, so a portrait takeover left
        // the page portrait after returning to the web page.
        return window.Orientation.USER_ROTATION_LANDSCAPE;
      default:
        return window.Orientation.AUTO_ROTATION_UNSPECIFIED;
    }
  }
}
