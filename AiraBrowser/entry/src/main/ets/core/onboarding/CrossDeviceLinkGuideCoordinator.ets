import { CrossDeviceLinkGuideRepository } from '../../data/onboarding/CrossDeviceLinkGuideRepository';

export type CrossDeviceLinkGuideAction = 'next' | 'open_guide' | 'never_show_again' | 'dismiss';
export type CrossDeviceLinkGuideClipId = 'page_push' | 'device_tabs';
export type CrossDeviceLinkGuidePrimaryAction = 'next' | 'open_guide';

export interface CrossDeviceLinkGuideSnapshot {
  visible: boolean;
  clipId: CrossDeviceLinkGuideClipId;
  title: string;
  message: string;
  progressLabel: string;
  primaryAction: CrossDeviceLinkGuidePrimaryAction;
  primaryActionTitle: string;
  secondaryActionTitle: string;
}

export function createHiddenCrossDeviceLinkGuideSnapshot(): CrossDeviceLinkGuideSnapshot {
  return {
    visible: false,
    clipId: 'page_push',
    title: '',
    message: '',
    progressLabel: '',
    primaryAction: 'next',
    primaryActionTitle: '',
    secondaryActionTitle: ''
  };
}

interface CrossDeviceLinkGuideStep {
  clipId: CrossDeviceLinkGuideClipId;
  title: string;
  message: string;
}

export interface CrossDeviceLinkGuideShell {
  publishState: (snapshot: CrossDeviceLinkGuideSnapshot) => void;
  openGuide: () => void;
}

const CROSS_DEVICE_LINK_GUIDE_STEPS: CrossDeviceLinkGuideStep[] = [
  {
    clipId: 'page_push',
    title: '把当前页推到电脑',
    message: '打开工具栏点推送，电脑会新开这个页面，手机上的标签还在。'
  },
  {
    clipId: 'device_tabs',
    title: '两台设备互相看标签页',
    message: '两边打开的网页都会出现在对方的跨设备标签页里。'
  }
];

const CROSS_DEVICE_LINK_GUIDE_NEXT_TITLE: string = '下一个';
const CROSS_DEVICE_LINK_GUIDE_OPEN_TITLE: string = '查看互联教程';
const CROSS_DEVICE_LINK_GUIDE_SKIP_TITLE: string = '不再提示';

/**
 * Teaches 与电脑互联 once per device, the first time that settings page is entered.
 * The first step only advances the clip. The second step's primary button opens the
 * existing 互联教程 page. Skipping or leaving does not open it.
 */
export class CrossDeviceLinkGuideCoordinator {
  private readonly repository: CrossDeviceLinkGuideRepository;
  private readonly shell: CrossDeviceLinkGuideShell;
  private readonly presentDelayMs: number;
  private presentTimer: number = -1;
  private presentGeneration: number = 0;
  private stepIndex: number = 0;
  private snapshot: CrossDeviceLinkGuideSnapshot = createHiddenCrossDeviceLinkGuideSnapshot();

  constructor(
    repository: CrossDeviceLinkGuideRepository,
    shell: CrossDeviceLinkGuideShell,
    presentDelayMs: number = 200
  ) {
    this.repository = repository;
    this.shell = shell;
    this.presentDelayMs = presentDelayMs;
  }

  getSnapshot(): CrossDeviceLinkGuideSnapshot {
    return this.snapshot;
  }

  handlePageEntered(): void {
    if (this.repository.hasCompleted() || this.snapshot.visible || this.presentTimer >= 0) {
      return;
    }
    const generation = this.presentGeneration;
    this.presentTimer = setTimeout((): void => {
      this.presentTimer = -1;
      void this.present(generation);
    }, this.presentDelayMs);
  }

  handlePageLeft(): void {
    this.presentGeneration += 1;
    if (this.presentTimer >= 0) {
      clearTimeout(this.presentTimer);
      this.presentTimer = -1;
    }
  }

  /** Shows the first clip again. A completed lesson can still be reopened from 互联教程. */
  replay(): void {
    this.presentGeneration += 1;
    if (this.presentTimer >= 0) {
      clearTimeout(this.presentTimer);
      this.presentTimer = -1;
    }
    this.publishStep(0);
  }

  handleAction(action: CrossDeviceLinkGuideAction): void {
    if (!this.snapshot.visible && action !== 'dismiss') {
      return;
    }
    if (action === 'next') {
      this.advanceStep();
      return;
    }
    if (action === 'open_guide') {
      void this.repository.markCompleted().catch((_error: Error): void => {
      });
      this.hide();
      this.shell.openGuide();
      return;
    }
    if (action === 'never_show_again') {
      void this.repository.markCompleted().catch((_error: Error): void => {
      });
    }
    this.hide();
  }

  private async present(generation: number): Promise<void> {
    if (generation !== this.presentGeneration || this.snapshot.visible) {
      return;
    }
    await this.repository.initialize().catch((_error: Error): void => {
    });
    if (generation !== this.presentGeneration || this.snapshot.visible || this.repository.hasCompleted()) {
      return;
    }
    this.publishStep(0);
    void this.repository.markShown().catch((_error: Error): void => {
    });
  }

  private advanceStep(): void {
    const nextIndex = this.stepIndex + 1;
    if (nextIndex >= CROSS_DEVICE_LINK_GUIDE_STEPS.length) {
      return;
    }
    this.publishStep(nextIndex);
  }

  private publishStep(index: number): void {
    const step: CrossDeviceLinkGuideStep | undefined = CROSS_DEVICE_LINK_GUIDE_STEPS[index];
    if (step === undefined) {
      return;
    }
    const last = index >= CROSS_DEVICE_LINK_GUIDE_STEPS.length - 1;
    this.stepIndex = index;
    this.publishState({
      visible: true,
      clipId: step.clipId,
      title: step.title,
      message: step.message,
      progressLabel: `${index + 1}/${CROSS_DEVICE_LINK_GUIDE_STEPS.length}`,
      primaryAction: last ? 'open_guide' : 'next',
      primaryActionTitle: last ? CROSS_DEVICE_LINK_GUIDE_OPEN_TITLE : CROSS_DEVICE_LINK_GUIDE_NEXT_TITLE,
      secondaryActionTitle: CROSS_DEVICE_LINK_GUIDE_SKIP_TITLE
    });
  }

  private hide(): void {
    this.presentGeneration += 1;
    this.publishState(createHiddenCrossDeviceLinkGuideSnapshot());
  }

  private publishState(snapshot: CrossDeviceLinkGuideSnapshot): void {
    this.snapshot = snapshot;
    this.shell.publishState(snapshot);
  }
}
