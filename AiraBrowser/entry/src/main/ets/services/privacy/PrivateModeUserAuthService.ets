import { userAuth } from '@kit.UserAuthenticationKit';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';

export type PrivateModeUserAuthStatus =
  'success' |
  'cancelled' |
  'failed' |
  'unavailable';

export interface PrivateModeUserAuthResult {
  status: PrivateModeUserAuthStatus;
  code: number;
  message: string;
}

export type PrivateModeUserAuthCallback = (result: PrivateModeUserAuthResult) => void;

export class PrivateModeUserAuthService {
  private authInstance?: userAuth.UserAuthInstance;
  private active: boolean = false;

  authenticate(callback: PrivateModeUserAuthCallback): void {
    this.cancel();
    try {
      const rand = cryptoFramework.createRandom();
      const challenge = rand.generateRandomSync(16).data;
      const authParam: userAuth.AuthParam = {
        challenge: challenge,
        authType: [
          userAuth.UserAuthType.FACE,
          userAuth.UserAuthType.FINGERPRINT
        ],
        authTrustLevel: userAuth.AuthTrustLevel.ATL3
      };
      const widgetParam: userAuth.WidgetParam = {
        title: resolveAppResourceText($r('app.string.browser_ui_browser_private_mode_lock_overlay_004')),
        navigationButtonText: resolveAppResourceText($r('app.string.settings_custom_home_cancel'))
      };
      const authInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
      this.authInstance = authInstance;
      this.active = true;
      authInstance.on('result', {
        onResult: (result: userAuth.UserAuthResult) => {
          this.detach();
          callback(this.mapResult(result));
        }
      });
      authInstance.start();
    } catch (error) {
      this.detach();
      callback(this.mapError(error));
    }
  }

  cancel(): void {
    if (this.authInstance === undefined) {
      return;
    }
    try {
      if (this.active) {
        this.authInstance.cancel();
      }
    } catch (_error) {
    }
    this.detach();
  }

  private detach(): void {
    if (this.authInstance !== undefined) {
      try {
        this.authInstance.off('result');
      } catch (_error) {
      }
    }
    this.authInstance = undefined;
    this.active = false;
  }

  private mapResult(result: userAuth.UserAuthResult): PrivateModeUserAuthResult {
    if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
      return {
        status: 'success',
        code: result.result,
        message: resolveAppResourceText($r('app.string.private_auth_success'))
      };
    }
    return {
      status: result.result === userAuth.UserAuthResultCode.CANCELED ? 'cancelled' : 'failed',
      code: result.result,
      message: this.resolveResultMessage(result.result)
    };
  }

  private mapError(error: Object | Error | undefined): PrivateModeUserAuthResult {
    const businessError = error as BusinessError;
    return {
      status: 'unavailable',
      code: businessError?.code ?? -1,
      message: businessError?.message ?? resolveAppResourceText($r('app.string.private_auth_unavailable'))
    };
  }

  private resolveResultMessage(code: number): string {
    if (code === userAuth.UserAuthResultCode.CANCELED) {
      return resolveAppResourceText($r('app.string.private_auth_canceled'));
    }
    if (code === userAuth.UserAuthResultCode.TIMEOUT) {
      return resolveAppResourceText($r('app.string.private_auth_timeout'));
    }
    if (code === userAuth.UserAuthResultCode.LOCKED) {
      return resolveAppResourceText($r('app.string.private_auth_locked'));
    }
    return resolveAppResourceText($r('app.string.private_auth_failed'));
  }
}
