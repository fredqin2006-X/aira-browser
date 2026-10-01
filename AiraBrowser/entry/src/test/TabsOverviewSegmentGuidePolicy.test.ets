import { describe, expect, it } from '@ohos/hypium';
import {
  advanceTabsOverviewSegmentGuide,
  resolveTabsOverviewSegmentGuidePlacement,
  resolveTabsOverviewSegmentGuideStep,
  TabsOverviewSegmentGuideChromeMetrics,
  tabsOverviewSegmentGuideStepCount
} from '../main/ets/core/onboarding/TabsOverviewSegmentGuidePolicy';

const METRICS: TabsOverviewSegmentGuideChromeMetrics = {
  height: 44,
  outerSize: 44,
  blockGap: 8,
  segmentInset: 4,
  bottomClearance: 35,
  horizontalInset: 16
};

export default function tabsOverviewSegmentGuidePolicyTest(): void {
  describe('tabs overview segment guide', () => {
    it('walks privacy, ordinary tabs, then cross-device, and only the last tap completes', 0, () => {
      expect(tabsOverviewSegmentGuideStepCount()).assertEqual(3);
      expect(resolveTabsOverviewSegmentGuideStep(0).target).assertEqual('privacy');
      expect(resolveTabsOverviewSegmentGuideStep(0).title).assertEqual('这里查看隐私标签页');
      expect(resolveTabsOverviewSegmentGuideStep(0).message).assertEqual('长按可以关闭全部');
      expect(resolveTabsOverviewSegmentGuideStep(0).continueLabel).assertEqual('轻点继续');
      expect(resolveTabsOverviewSegmentGuideStep(1).target).assertEqual('tabs');
      expect(resolveTabsOverviewSegmentGuideStep(1).title).assertEqual('这里查看普通标签页');
      expect(resolveTabsOverviewSegmentGuideStep(2).target).assertEqual('devices');
      expect(resolveTabsOverviewSegmentGuideStep(2).message).assertEqual('其他设备打开的页面会列在这里');
      expect(resolveTabsOverviewSegmentGuideStep(2).continueLabel).assertEqual('轻点完成');

      const first = advanceTabsOverviewSegmentGuide(0);
      expect(first.completed).assertEqual(false);
      expect(first.stepIndex).assertEqual(1);
      const second = advanceTabsOverviewSegmentGuide(first.stepIndex);
      expect(second.completed).assertEqual(false);
      expect(second.stepIndex).assertEqual(2);
      const last = advanceTabsOverviewSegmentGuide(second.stepIndex);
      expect(last.completed).assertEqual(true);
      expect(last.stepIndex).assertEqual(2);
    });

    it('keeps the arrow on the taught segment when the bubble shifts inward', 0, () => {
      const privacy = resolveTabsOverviewSegmentGuidePlacement({
        viewportWidth: 360,
        viewportHeight: 800,
        bottomLiftVp: 0,
        panelWidth: 328,
        panelOffsetX: 16,
        target: 'privacy',
        bubbleWidth: 232,
        bubbleHeight: 100,
        arrowWidth: 12,
        arrowHeight: 7,
        arrowGap: 8,
        viewportMargin: 12,
        metrics: METRICS
      });
      const devices = resolveTabsOverviewSegmentGuidePlacement({
        viewportWidth: 360,
        viewportHeight: 800,
        bottomLiftVp: 0,
        panelWidth: 328,
        panelOffsetX: 16,
        target: 'devices',
        bubbleWidth: 232,
        bubbleHeight: 100,
        arrowWidth: 12,
        arrowHeight: 7,
        arrowGap: 8,
        viewportMargin: 12,
        metrics: METRICS
      });

      expect(privacy.bubbleLeft).assertEqual(12);
      expect(devices.bubbleLeft).assertEqual(116);
      expect(privacy.arrowLeft < devices.arrowLeft).assertTrue();
      expect(privacy.bubbleTop + 100 <= privacy.arrowTop + 1).assertTrue();
    });
  });
}
