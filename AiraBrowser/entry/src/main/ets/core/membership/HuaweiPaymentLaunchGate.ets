/**
 * Keeps the "opening Huawei payment" sheet honest.
 *
 * createPurchase does not return until the cashier closes, and the cashier
 * itself can take a long time to appear. The sheet blocks the page during
 * that gap. It drops once the cashier actually takes the window, and a
 * foreground timeout drops it when the launch never happens so the page is
 * not stuck behind a spinner.
 */

export const HUAWEI_PAYMENT_LAUNCH_TIMEOUT_MS: number = 30000;
export const HUAWEI_PAYMENT_LAUNCH_TRANSIENT_INACTIVE_MS: number = 500;

export interface HuaweiPaymentLaunchHost {
  onLaunchVisibilityChanged(visible: boolean): void;
  onLaunchTimedOut(): void;
}

export interface HuaweiPaymentLaunchClock {
  now(): number;
  schedule(delayMs: number, callback: () => void): number;
  cancel(timerId: number): void;
}

class SystemHuaweiPaymentLaunchClock implements HuaweiPaymentLaunchClock {
  now(): number {
    return Date.now();
  }

  schedule(delayMs: number, callback: () => void): number {
    return setTimeout(callback, delayMs);
  }

  cancel(timerId: number): void {
    clearTimeout(timerId);
  }
}

const SYSTEM_HUAWEI_PAYMENT_LAUNCH_CLOCK: HuaweiPaymentLaunchClock = new SystemHuaweiPaymentLaunchClock();

export class HuaweiPaymentLaunchGate {
  private host?: HuaweiPaymentLaunchHost;
  private clock: HuaweiPaymentLaunchClock = SYSTEM_HUAWEI_PAYMENT_LAUNCH_CLOCK;
  private running: boolean = false;
  private visible: boolean = false;
  private timedOut: boolean = false;
  private cashierPresented: boolean = false;
  private cashierWatchArmed: boolean = false;
  private inactiveAt: number = 0;
  private timerId: number = -1;

  isActive(): boolean {
    return this.running;
  }

  hasTimedOut(): boolean {
    return this.timedOut;
  }

  begin(host: HuaweiPaymentLaunchHost, clock?: HuaweiPaymentLaunchClock): void {
    if (this.running) {
      return;
    }
    this.host = host;
    this.clock = clock !== undefined ? clock : SYSTEM_HUAWEI_PAYMENT_LAUNCH_CLOCK;
    this.running = true;
    this.timedOut = false;
    this.cashierPresented = false;
    this.cashierWatchArmed = false;
    this.inactiveAt = 0;
    this.visible = false;
    this.show();
    this.timerId = this.clock.schedule(HUAWEI_PAYMENT_LAUNCH_TIMEOUT_MS, (): void => {
      this.handleTimeout();
    });
  }

  /**
   * Focus loss before createPurchase is just the user pulling the shade.
   * Only loss after the purchase call can mean the cashier took the window.
   */
  armCashierDetection(): void {
    if (!this.running) {
      return;
    }
    this.cashierWatchArmed = true;
  }

  noteWindowInactive(): void {
    if (!this.running || this.timedOut || !this.cashierWatchArmed || this.cashierPresented) {
      return;
    }
    this.inactiveAt = this.clock.now();
    this.cashierPresented = true;
    this.hide();
  }

  noteWindowActive(): void {
    if (!this.running || this.timedOut || !this.cashierPresented) {
      return;
    }
    const awayMs = this.clock.now() - this.inactiveAt;
    if (awayMs >= HUAWEI_PAYMENT_LAUNCH_TRANSIENT_INACTIVE_MS) {
      return;
    }
    this.cashierPresented = false;
    this.show();
  }

  finish(): void {
    if (!this.running) {
      return;
    }
    this.running = false;
    this.clearTimer();
    this.hide();
    this.host = undefined;
  }

  private handleTimeout(): void {
    this.timerId = -1;
    if (!this.running || this.timedOut || this.cashierPresented) {
      return;
    }
    this.timedOut = true;
    this.hide();
    if (this.host !== undefined) {
      this.host.onLaunchTimedOut();
    }
  }

  private show(): void {
    if (this.visible) {
      return;
    }
    this.visible = true;
    if (this.host !== undefined) {
      this.host.onLaunchVisibilityChanged(true);
    }
  }

  private hide(): void {
    if (!this.visible) {
      return;
    }
    this.visible = false;
    if (this.host !== undefined) {
      this.host.onLaunchVisibilityChanged(false);
    }
  }

  private clearTimer(): void {
    if (this.timerId < 0) {
      return;
    }
    this.clock.cancel(this.timerId);
    this.timerId = -1;
  }
}
