import { resolveAppResourceText } from '../resources/AppResourceText';

export type TabsOverviewSegmentGuideTarget = 'privacy' | 'tabs' | 'devices';

export interface TabsOverviewSegmentGuideStep {
  target: TabsOverviewSegmentGuideTarget;
  title: string;
  message: string;
  continueLabel: string;
  progressLabel: string;
}

export interface TabsOverviewSegmentGuideAdvance {
  stepIndex: number;
  completed: boolean;
}

export interface TabsOverviewSegmentGuideChromeMetrics {
  height: number;
  outerSize: number;
  blockGap: number;
  segmentInset: number;
  bottomClearance: number;
  horizontalInset: number;
}

export interface TabsOverviewSegmentGuidePlacementInput {
  viewportWidth: number;
  viewportHeight: number;
  bottomLiftVp: number;
  panelWidth: number;
  panelOffsetX: number;
  target: TabsOverviewSegmentGuideTarget;
  bubbleWidth: number;
  bubbleHeight: number;
  arrowWidth: number;
  arrowHeight: number;
  arrowGap: number;
  viewportMargin: number;
  metrics: TabsOverviewSegmentGuideChromeMetrics;
}

export interface TabsOverviewSegmentGuidePlacement {
  bubbleLeft: number;
  bubbleTop: number;
  arrowLeft: number;
  arrowTop: number;
}

const TABS_OVERVIEW_SEGMENT_GUIDE_STEPS: TabsOverviewSegmentGuideStep[] = [
  {
    target: 'privacy',
    title: '这里查看隐私标签页',
    message: '长按可以关闭全部',
    continueLabel: '轻点继续',
    progressLabel: '1/3'
  },
  {
    target: 'tabs',
    title: '这里查看普通标签页',
    message: '长按可以关闭全部',
    continueLabel: '轻点继续',
    progressLabel: '2/3'
  },
  {
    target: 'devices',
    title: '这里查看跨设备标签页',
    message: '其他设备打开的页面会列在这里',
    continueLabel: '轻点完成',
    progressLabel: '3/3'
  }
];

export function tabsOverviewSegmentGuideStepCount(): number {
  return TABS_OVERVIEW_SEGMENT_GUIDE_STEPS.length;
}

export function resolveTabsOverviewSegmentGuideStep(stepIndex: number): TabsOverviewSegmentGuideStep {
  const index = clampIndex(stepIndex, TABS_OVERVIEW_SEGMENT_GUIDE_STEPS.length);
  return localizeTabsOverviewSegmentGuideStep(TABS_OVERVIEW_SEGMENT_GUIDE_STEPS[index]);
}

function localizeTabsOverviewSegmentGuideStep(step: TabsOverviewSegmentGuideStep): TabsOverviewSegmentGuideStep {
  if (step.target === 'privacy') {
    return {
      target: step.target,
      title: tabsGuideText($r('app.string.tabs_guide_private_title'), step.title),
      message: tabsGuideText($r('app.string.tabs_guide_close_all'), step.message),
      continueLabel: tabsGuideText($r('app.string.tabs_guide_continue'), step.continueLabel),
      progressLabel: step.progressLabel
    };
  }
  if (step.target === 'tabs') {
    return {
      target: step.target,
      title: tabsGuideText($r('app.string.tabs_guide_normal_title'), step.title),
      message: tabsGuideText($r('app.string.tabs_guide_close_all'), step.message),
      continueLabel: tabsGuideText($r('app.string.tabs_guide_continue'), step.continueLabel),
      progressLabel: step.progressLabel
    };
  }
  return {
    target: step.target,
    title: tabsGuideText($r('app.string.tabs_guide_devices_title'), step.title),
    message: tabsGuideText($r('app.string.tabs_guide_devices_message'), step.message),
    continueLabel: tabsGuideText($r('app.string.tabs_guide_done'), step.continueLabel),
    progressLabel: step.progressLabel
  };
}

function tabsGuideText(resource: Resource, fallback: string): string {
  const resolved = resolveAppResourceText(resource);
  return resolved.length > 0 ? resolved : fallback;
}

/**
 * A tap advances one step. Only the last step completes the lesson, so leaving
 * the page halfway does not spend it.
 */
export function advanceTabsOverviewSegmentGuide(stepIndex: number): TabsOverviewSegmentGuideAdvance {
  const index = Math.max(0, Math.floor(stepIndex));
  if (!Number.isFinite(stepIndex) || index >= TABS_OVERVIEW_SEGMENT_GUIDE_STEPS.length - 1) {
    return {
      stepIndex: TABS_OVERVIEW_SEGMENT_GUIDE_STEPS.length - 1,
      completed: true
    };
  }
  return {
    stepIndex: index + 1,
    completed: false
  };
}

/**
 * Places the bubble above the segment it teaches. The bubble stays on screen;
 * the arrow keeps pointing at that segment even when the bubble has to shift.
 */
export function resolveTabsOverviewSegmentGuidePlacement(
  input: TabsOverviewSegmentGuidePlacementInput
): TabsOverviewSegmentGuidePlacement {
  const metrics = input.metrics;
  const viewportWidth = Math.max(0, input.viewportWidth);
  const viewportHeight = Math.max(0, input.viewportHeight);
  const lift = Number.isFinite(input.bottomLiftVp) ? Math.max(0, input.bottomLiftVp) : 0;
  const chromeWidth = input.panelWidth > 0 ? input.panelWidth :
    Math.max(0, viewportWidth - metrics.horizontalInset * 2);
  const chromeLeft = input.panelWidth > 0 ? input.panelOffsetX : Math.max(0, metrics.horizontalInset);
  const chromeTop = Math.max(0, viewportHeight - metrics.bottomClearance - lift - metrics.height);
  const switcherWidth = Math.max(0, chromeWidth - (metrics.outerSize + metrics.blockGap) * 2);
  const contentLeft = chromeLeft + metrics.outerSize + metrics.blockGap + metrics.segmentInset;
  const segmentWidth = Math.max(1, (switcherWidth - metrics.segmentInset * 2) / 3);
  const segmentCenterX = contentLeft + segmentWidth * (targetIndex(input.target) + 0.5);
  const segmentTop = chromeTop + metrics.segmentInset;
  const margin = Math.max(0, input.viewportMargin);
  const bubbleWidth = Math.max(1, input.bubbleWidth);
  const bubbleHeight = Math.max(1, input.bubbleHeight);
  const maxLeft = Math.max(margin, viewportWidth - margin - bubbleWidth);
  const bubbleLeft = clamp(segmentCenterX - bubbleWidth / 2, margin, maxLeft);
  const arrowTop = segmentTop - Math.max(0, input.arrowGap) - Math.max(0, input.arrowHeight);
  const bubbleTop = Math.max(margin, arrowTop - bubbleHeight);
  const arrowWidth = Math.max(1, input.arrowWidth);
  const arrowInset = Math.min(16, bubbleWidth / 4);
  const arrowLeft = clamp(
    segmentCenterX - arrowWidth / 2,
    bubbleLeft + arrowInset,
    bubbleLeft + bubbleWidth - arrowInset - arrowWidth
  );
  return {
    bubbleLeft: bubbleLeft,
    bubbleTop: bubbleTop,
    arrowLeft: arrowLeft,
    arrowTop: bubbleTop + bubbleHeight - 1
  };
}

/**
 * The page back handler asks this gate before it closes the tab overview, so a
 * back press during the lesson advances the bubble instead of leaving the page.
 */
export class TabsOverviewSegmentGuideBackGate {
  private active: boolean = false;
  private advance: () => void = () => {};

  setActive(active: boolean, advance: () => void): void {
    this.active = active;
    this.advance = advance;
  }

  consumeBack(): boolean {
    if (!this.active) {
      return false;
    }
    this.advance();
    return true;
  }
}

export const tabsOverviewSegmentGuideBackGate: TabsOverviewSegmentGuideBackGate =
  new TabsOverviewSegmentGuideBackGate();

function targetIndex(target: TabsOverviewSegmentGuideTarget): number {
  if (target === 'privacy') {
    return 0;
  }
  if (target === 'tabs') {
    return 1;
  }
  return 2;
}

function clampIndex(value: number, length: number): number {
  if (!Number.isFinite(value)) {
    return 0;
  }
  return Math.max(0, Math.min(length - 1, Math.floor(value)));
}

function clamp(value: number, min: number, max: number): number {
  if (max < min) {
    return min;
  }
  return Math.max(min, Math.min(max, value));
}
