import { describe, expect, it } from '@ohos/hypium';
import { MediaProbePolicyService } from '../main/ets/services/media/MediaProbePolicyService';

export default function mediaProbePolicyServiceTest(): void {
  describe('MediaProbePolicyService', () => {
    it('disables scheduled deep probes for hidden pages', 0, () => {
      const service = new MediaProbePolicyService();
      const plan = service.buildVideoPageEndDeepProbePlan({
        fullAppServiceMode: true,
        webVideoTakeoverEnabled: true,
        tabActive: true,
        webPageVisible: false
      });

      expect(plan.enabled).assertFalse();
      expect(plan.delayMsList.length).assertEqual(0);
    });

    it('keeps the existing three-pass budget for visible pages', 0, () => {
      const service = new MediaProbePolicyService();
      const plan = service.buildVideoPageEndDeepProbePlan({
        fullAppServiceMode: true,
        webVideoTakeoverEnabled: true,
        tabActive: true,
        webPageVisible: true
      });

      expect(plan.enabled).assertTrue();
      expect(plan.delayMsList.length).assertEqual(3);
      expect(plan.budget.maxDeepProbeRunsPerNavigation).assertEqual(3);
      expect(plan.budget.maxInFlightDeepProbes).assertEqual(1);
    });

    it('keeps generic resource capture enabled while takeover is active', 0, () => {
      const service = new MediaProbePolicyService();
      const decision = service.decideGenericResourceRequestObservation({
        fullAppServiceMode: true,
        webVideoTakeoverEnabled: true,
        mediaResourcesPanelOpen: false
      });

      expect(decision.enabled).assertTrue();
      expect(decision.reason).assertEqual('takeover_resource_observation');
    });
  });
}
