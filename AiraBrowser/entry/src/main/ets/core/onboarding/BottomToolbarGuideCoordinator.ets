import { resolveAppResourceText } from '../resources/AppResourceText';
import {
  BrowserTransientPromptBlockingFacts,
  BrowserTransientSurfaceId,
  BrowserTransientSurfacePresentationRequest,
  BrowserTransientSurfaceToken
} from '../browser/BrowserTransientSurfaceCoordinator';
import { BottomToolbarGuideRepository } from '../../data/onboarding/BottomToolbarGuideRepository';
import { BrowserDeviceFormFactor } from '../browser/BrowserDeviceFormFactorCoordinator';

export type BottomToolbarGuideAction = 'next' | 'acknowledge' | 'never_show_again';
export type BottomToolbarGuideClipId = 'hide' | 'return_home' | 'tools_panel' | 'tab_switch';
export type BottomToolbarGuidePrimaryAction = 'next' | 'acknowledge';

export interface BottomToolbarGuideSnapshot {
  visible: boolean;
  clipId: BottomToolbarGuideClipId;
  title: string;
  message: string;
  progressLabel: string;
  primaryAction: BottomToolbarGuidePrimaryAction;
  primaryActionTitle: string;
  secondaryActionTitle: string;
}

export function createHiddenBottomToolbarGuideSnapshot(): BottomToolbarGuideSnapshot {
  return {
    visible: false,
    clipId: 'hide',
    title: '',
    message: '',
    progressLabel: '',
    primaryAction: 'acknowledge',
    primaryActionTitle: '',
    secondaryActionTitle: ''
  };
}

interface BottomToolbarGuideStep {
  clipId: BottomToolbarGuideClipId;
  title: string;
  message: string;
}

export interface BottomToolbarGuideShellFacts {
  shellFamily: 'phone' | 'large_screen';
  /**
   * What the platform says the device is, before the shell falls back to its phone
   * adapter. A PC and a 2in1 device can end up on the phone shell, so the shell family
   * alone cannot tell them apart from a phone.
   */
  deviceFormFactor: BrowserDeviceFormFactor;
  /**
   * The browser page is the one the user is looking at. A pushed settings page leaves
   * this shell alive underneath, and the lesson must not surface there.
   */
  appVisible: boolean;
  /**
   * A Web page is showing, not the homepage. The homepage has nothing to swipe away,
   * so it must not be taught over.
   */
  webPageVisible: boolean;
  /** The phone lesson explains the floating toolbar. The split frame has no such gesture. */
  floatingToolbarChromeActive: boolean;
  privacyMode: string;
  promptBlockingFacts: BrowserTransientPromptBlockingFacts;
}

/**
 * The narrow slice of the transient-surface owner this lesson needs. Keeping it
 * this small keeps the lesson free of the whole browser stack it presents over.
 */
export interface BottomToolbarGuideSurface {
  present: (request: BrowserTransientSurfacePresentationRequest) => BrowserTransientSurfaceToken;
  dismiss: (id: BrowserTransientSurfaceId) => void;
  isReleaseNoticeBlocked: (facts: BrowserTransientPromptBlockingFacts) => boolean;
}

export interface BottomToolbarGuideShell {
  resolveFacts: () => BottomToolbarGuideShellFacts;
  publishState: (snapshot: BottomToolbarGuideSnapshot) => void;
}

const BOTTOM_TOOLBAR_GUIDE_EVALUATION_DELAY_MS: number = 700;
const BOTTOM_TOOLBAR_GUIDE_NEXT_TITLE: string = '下一个';
const BOTTOM_TOOLBAR_GUIDE_DONE_TITLE: string = '我知道了';
const BOTTOM_TOOLBAR_GUIDE_SECONDARY_ACTION_TITLE: string = '不再提示';
const BOTTOM_TOOLBAR_GUIDE_STEPS: BottomToolbarGuideStep[] = [
  {
    clipId: 'hide',
    title: '向下滑动隐藏悬浮工具条',
    message: '工具条就会收起来，只看网页内容，浏览更清爽。'
  },
  {
    clipId: 'return_home',
    title: '上滑两侧按钮回到主页',
    message: '按住返回或标签按钮向上滑，松手就会关闭当前页并回到主页。'
  },
  {
    clipId: 'tools_panel',
    title: '上滑中间搜索区打开工具',
    message: '按住中间的搜索区向上滑，工具面板会从底部展开。'
  },
  {
    clipId: 'tab_switch',
    title: '左右滑动切换标签页',
    message: '在搜索区左右滑动，就能切到旁边的标签页。'
  }
];

/**
 * Teaches the phone floating toolbar once per device, the first time that toolbar
 * is actually in front of a Web page. The card walks the gestures one at a time;
 * 下一个 advances the clip, and only the last step closes it. Choosing the centered homepage, or any later
 * switch to the split frame, has no such gesture, so those sessions stay silent and
 * do not spend the lesson. A later switch back to the floating toolbar — from toolbar
 * settings, the homepage choice, or sync — teaches on the next Web page, including
 * the page already open when the user returns from settings.
 *
 * The lesson is spent only when the card actually reaches the user. A load that lands
 * while another prompt holds the lane, or while the toolbar is still split, defers
 * the lesson instead of losing it.
 *
 * Phone only: the large-screen shell has its own toolbar that is not swiped away.
 */
export class BottomToolbarGuideCoordinator {
  private readonly repository: BottomToolbarGuideRepository;
  private readonly surface: BottomToolbarGuideSurface;
  private readonly shell: BottomToolbarGuideShell;
  private readonly evaluationDelayMs: number;
  private armed: boolean = false;
  /**
   * A Web page has finished loading on this shell. Survives a route reset so coming
   * back to that same page can still teach, without treating the homepage or a cold
   * start as a page that already loaded.
   */
  private webPageLoaded: boolean = false;
  private evaluateTimer: number = -1;
  private evaluationGeneration: number = 0;
  private presentationGeneration: number = 0;
  private stepIndex: number = 0;
  private snapshot: BottomToolbarGuideSnapshot = createHiddenBottomToolbarGuideSnapshot();

  constructor(
    repository: BottomToolbarGuideRepository,
    surface: BottomToolbarGuideSurface,
    shell: BottomToolbarGuideShell,
    evaluationDelayMs: number = BOTTOM_TOOLBAR_GUIDE_EVALUATION_DELAY_MS
  ) {
    this.repository = repository;
    this.surface = surface;
    this.shell = shell;
    this.evaluationDelayMs = evaluationDelayMs;
  }

  getSnapshot(): BottomToolbarGuideSnapshot {
    return this.snapshot;
  }

  /**
   * The active phone tab finished loading a Web page. That load is remembered for
   * this shell, and every later load re-decides whether the pending lesson may
   * present now.
   */
  handleWebPageLoadCompleted(): void {
    if (this.repository.hasCompleted()) {
      return;
    }
    this.webPageLoaded = true;
    this.armPendingLesson();
  }

  /**
   * The user is looking at a Web page that already finished loading: they came back
   * from settings, or the floating toolbar just became the active frame. A homepage,
   * a settings page, and a shell that has never loaded a Web page are not opportunities.
   */
  handleBrowsingSurfaceForeground(): void {
    if (this.repository.hasCompleted() || !this.webPageLoaded) {
      return;
    }
    this.armPendingLesson();
  }

  /**
   * Re-decides whether the armed guide may present now. Safe to call at any time:
   * it is a no-op until a Web page has armed the guide.
   */
  scheduleEvaluation(): void {
    this.cancelEvaluation();
    if (!this.armed || this.repository.hasCompleted()) {
      return;
    }
    const generation = this.evaluationGeneration;
    this.evaluateTimer = setTimeout((): void => {
      this.evaluateTimer = -1;
      void this.evaluate(generation);
    }, this.evaluationDelayMs);
  }

  handleAction(action: BottomToolbarGuideAction): void {
    if (action === 'next') {
      this.advanceStep();
      return;
    }
    if (action === 'never_show_again') {
      void this.repository.markCompleted().catch((_error: Error): void => {
      });
    }
    this.surface.dismiss('bottom_toolbar_guide');
  }

  /**
   * Records that the lesson reached the user. A custom bottom surface mounts
   * asynchronously, so a presentation abandoned before its reveal must not spend
   * the one-time guide.
   */
  handleSurfaceRevealed(): void {
    if (!this.snapshot.visible) {
      return;
    }
    this.armed = false;
    void this.repository.markShown().catch((_error: Error): void => {
    });
  }

  handleSurfaceDismissed(): void {
    this.presentationGeneration += 1;
    this.publishState(createHiddenBottomToolbarGuideSnapshot());
  }

  handleShellReset(): void {
    this.cancelEvaluation();
    // A route reset takes the card down, but the loaded page is still there. Coming
    // back to it is a new opportunity unless the user already saw the lesson.
    this.armed = false;
    this.presentationGeneration += 1;
    this.publishState(createHiddenBottomToolbarGuideSnapshot());
  }

  private armPendingLesson(): void {
    this.armed = true;
    this.scheduleEvaluation();
  }

  private cancelEvaluation(): void {
    this.evaluationGeneration += 1;
    if (this.evaluateTimer >= 0) {
      clearTimeout(this.evaluateTimer);
      this.evaluateTimer = -1;
    }
  }

  private async evaluate(generation: number): Promise<void> {
    if (generation !== this.evaluationGeneration || this.snapshot.visible) {
      return;
    }
    if (!this.armed) {
      return;
    }
    await this.repository.initialize().catch((_error: Error): void => {
    });
    if (generation !== this.evaluationGeneration || this.snapshot.visible) {
      return;
    }
    if (this.repository.hasCompleted() || !this.canPresent(generation)) {
      return;
    }
    this.presentGuide();
  }

  /**
   * Whether a presentation may still start. The published snapshot is not
   * consulted here: publishing it is what expresses the intent to present, so
   * treating it as a blocker would abandon every presentation at the reveal step.
   */
  private canPresent(generation: number): boolean {
    if (generation !== this.evaluationGeneration) {
      return false;
    }
    const facts = this.shell.resolveFacts();
    if (facts.shellFamily !== 'phone') {
      return false;
    }
    if (!facts.floatingToolbarChromeActive) {
      return false;
    }
    // A desktop has no bottom floating toolbar to swipe away, and a cockpit
    // must not teach a glance-heavy gesture while driving.
    if (facts.deviceFormFactor === 'pc' || facts.deviceFormFactor === 'two_in_one' ||
      facts.deviceFormFactor === 'car') {
      return false;
    }
    if (!facts.appVisible || !facts.webPageVisible || facts.privacyMode === 'private') {
      return false;
    }
    return !this.surface.isReleaseNoticeBlocked(facts.promptBlockingFacts);
  }

  private presentGuide(): void {
    this.publishStep(0);
    this.presentationGeneration += 1;
    const presentationGeneration = this.presentationGeneration;
    this.surface.present({
      id: 'bottom_toolbar_guide',
      revealDelayMs: 0,
      dismissDurationMs: 0,
      shouldReveal: (): boolean =>
        presentationGeneration === this.presentationGeneration && this.snapshot.visible
    });
  }

  private advanceStep(): void {
    if (!this.snapshot.visible) {
      return;
    }
    const nextIndex = this.stepIndex + 1;
    if (nextIndex >= BOTTOM_TOOLBAR_GUIDE_STEPS.length) {
      this.surface.dismiss('bottom_toolbar_guide');
      return;
    }
    this.publishStep(nextIndex);
  }

  private publishStep(index: number): void {
    const step: BottomToolbarGuideStep | undefined = BOTTOM_TOOLBAR_GUIDE_STEPS[index];
    if (step === undefined) {
      return;
    }
    const last = index >= BOTTOM_TOOLBAR_GUIDE_STEPS.length - 1;
    this.stepIndex = index;
    this.publishState({
      visible: true,
      clipId: step.clipId,
      title: this.localizeStepTitle(step),
      message: this.localizeStepMessage(step),
      progressLabel: `${index + 1}/${BOTTOM_TOOLBAR_GUIDE_STEPS.length}`,
      primaryAction: last ? 'acknowledge' : 'next',
      primaryActionTitle: this.resolvePrimaryActionTitle(last),
      secondaryActionTitle: toolbarGuideText($r('app.string.settings_link_guide_skip'), BOTTOM_TOOLBAR_GUIDE_SECONDARY_ACTION_TITLE)
    });
  }

  private resolvePrimaryActionTitle(last: boolean): string {
    if (last) {
      return toolbarGuideText($r('app.string.toolbar_guide_got_it'), BOTTOM_TOOLBAR_GUIDE_DONE_TITLE);
    }
    return toolbarGuideText($r('app.string.settings_link_guide_next'), BOTTOM_TOOLBAR_GUIDE_NEXT_TITLE);
  }

  private localizeStepTitle(step: BottomToolbarGuideStep): string {
    switch (step.clipId) {
      case 'hide':
        return toolbarGuideText($r('app.string.toolbar_guide_hide_title'), step.title);
      case 'return_home':
        return toolbarGuideText($r('app.string.toolbar_guide_home_title'), step.title);
      case 'tools_panel':
        return toolbarGuideText($r('app.string.toolbar_guide_tools_title'), step.title);
      case 'tab_switch':
        return toolbarGuideText($r('app.string.toolbar_guide_tabs_title'), step.title);
      default:
        return step.title;
    }
  }

  private localizeStepMessage(step: BottomToolbarGuideStep): string {
    switch (step.clipId) {
      case 'hide':
        return toolbarGuideText($r('app.string.toolbar_guide_hide_message'), step.message);
      case 'return_home':
        return toolbarGuideText($r('app.string.toolbar_guide_home_message'), step.message);
      case 'tools_panel':
        return toolbarGuideText($r('app.string.toolbar_guide_tools_message'), step.message);
      case 'tab_switch':
        return toolbarGuideText($r('app.string.toolbar_guide_tabs_message'), step.message);
      default:
        return step.message;
    }
  }

  private publishState(snapshot: BottomToolbarGuideSnapshot): void {
    this.snapshot = snapshot;
    this.shell.publishState(snapshot);
  }
}

function toolbarGuideText(resource: Resource, fallback: string): string {
  const resolved = resolveAppResourceText(resource);
  return resolved.length > 0 ? resolved : fallback;
}
