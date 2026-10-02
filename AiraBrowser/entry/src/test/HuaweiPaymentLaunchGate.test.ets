import { describe, expect, it } from '@ohos/hypium';
import {
  HUAWEI_PAYMENT_LAUNCH_TIMEOUT_MS,
  HUAWEI_PAYMENT_LAUNCH_TRANSIENT_INACTIVE_MS,
  HuaweiPaymentLaunchClock,
  HuaweiPaymentLaunchGate,
  HuaweiPaymentLaunchHost
} from '../main/ets/core/membership/HuaweiPaymentLaunchGate';

export default function huaweiPaymentLaunchGateTest(): void {
  describe('Huawei payment launch gate', () => {
    it('shows a blocking sheet as soon as the launch starts', 0, () => {
      const clock = new ManualLaunchClock();
      const host = new RecordingLaunchHost();
      const gate = new HuaweiPaymentLaunchGate();
      gate.begin(host, clock);
      expect(host.visible).assertTrue();
      expect(gate.isActive()).assertTrue();
      expect(host.timeouts).assertEqual(0);
    });

    it('closes the sheet and reports failure when the cashier never appears', 0, () => {
      const clock = new ManualLaunchClock();
      const host = new RecordingLaunchHost();
      const gate = new HuaweiPaymentLaunchGate();
      gate.begin(host, clock);
      gate.armCashierDetection();
      clock.advance(HUAWEI_PAYMENT_LAUNCH_TIMEOUT_MS);
      expect(host.visible).assertFalse();
      expect(host.timeouts).assertEqual(1);
      expect(gate.hasTimedOut()).assertTrue();
      clock.advance(HUAWEI_PAYMENT_LAUNCH_TIMEOUT_MS);
      expect(host.timeouts).assertEqual(1);
    });

    it('drops the sheet without a failure once the cashier takes the window', 0, () => {
      const clock = new ManualLaunchClock();
      const host = new RecordingLaunchHost();
      const gate = new HuaweiPaymentLaunchGate();
      gate.begin(host, clock);
      gate.armCashierDetection();
      gate.noteWindowInactive();
      expect(host.visible).assertFalse();
      clock.advance(HUAWEI_PAYMENT_LAUNCH_TIMEOUT_MS);
      expect(host.timeouts).assertEqual(0);
      expect(gate.hasTimedOut()).assertFalse();
    });

    it('ignores focus loss before the purchase call', 0, () => {
      const clock = new ManualLaunchClock();
      const host = new RecordingLaunchHost();
      const gate = new HuaweiPaymentLaunchGate();
      gate.begin(host, clock);
      gate.noteWindowInactive();
      expect(host.visible).assertTrue();
      expect(host.timeouts).assertEqual(0);
    });

    it('puts the sheet back when focus blips for less than the cashier threshold', 0, () => {
      const clock = new ManualLaunchClock();
      const host = new RecordingLaunchHost();
      const gate = new HuaweiPaymentLaunchGate();
      gate.begin(host, clock);
      gate.armCashierDetection();
      gate.noteWindowInactive();
      clock.advance(HUAWEI_PAYMENT_LAUNCH_TRANSIENT_INACTIVE_MS - 1);
      gate.noteWindowActive();
      expect(host.visible).assertTrue();
      expect(gate.hasTimedOut()).assertFalse();
    });

    it('keeps the sheet down after a real cashier visit', 0, () => {
      const clock = new ManualLaunchClock();
      const host = new RecordingLaunchHost();
      const gate = new HuaweiPaymentLaunchGate();
      gate.begin(host, clock);
      gate.armCashierDetection();
      gate.noteWindowInactive();
      clock.advance(HUAWEI_PAYMENT_LAUNCH_TRANSIENT_INACTIVE_MS);
      gate.noteWindowActive();
      expect(host.visible).assertFalse();
      expect(host.timeouts).assertEqual(0);
    });

    it('cancels the timeout once the launch finishes', 0, () => {
      const clock = new ManualLaunchClock();
      const host = new RecordingLaunchHost();
      const gate = new HuaweiPaymentLaunchGate();
      gate.begin(host, clock);
      gate.finish();
      expect(host.visible).assertFalse();
      expect(gate.isActive()).assertFalse();
      clock.advance(HUAWEI_PAYMENT_LAUNCH_TIMEOUT_MS);
      expect(host.timeouts).assertEqual(0);
    });
  });
}

class ScheduledLaunchTask {
  id: number = 0;
  at: number = 0;
  callback: () => void = (): void => {
  };
}

class ManualLaunchClock implements HuaweiPaymentLaunchClock {
  private nowMs: number = 0;
  private nextId: number = 1;
  private tasks: ScheduledLaunchTask[] = [];

  now(): number {
    return this.nowMs;
  }

  schedule(delayMs: number, callback: () => void): number {
    const task = new ScheduledLaunchTask();
    task.id = this.nextId;
    this.nextId++;
    task.at = this.nowMs + delayMs;
    task.callback = callback;
    this.tasks.push(task);
    return task.id;
  }

  cancel(timerId: number): void {
    const remaining: ScheduledLaunchTask[] = [];
    for (let index = 0; index < this.tasks.length; index++) {
      if (this.tasks[index].id !== timerId) {
        remaining.push(this.tasks[index]);
      }
    }
    this.tasks = remaining;
  }

  advance(delayMs: number): void {
    this.nowMs += delayMs;
    const due: ScheduledLaunchTask[] = [];
    const remaining: ScheduledLaunchTask[] = [];
    for (let index = 0; index < this.tasks.length; index++) {
      if (this.tasks[index].at <= this.nowMs) {
        due.push(this.tasks[index]);
      } else {
        remaining.push(this.tasks[index]);
      }
    }
    this.tasks = remaining;
    for (let index = 0; index < due.length; index++) {
      due[index].callback();
    }
  }
}

class RecordingLaunchHost implements HuaweiPaymentLaunchHost {
  visible: boolean = false;
  timeouts: number = 0;

  onLaunchVisibilityChanged(visible: boolean): void {
    this.visible = visible;
  }

  onLaunchTimedOut(): void {
    this.timeouts++;
  }
}
