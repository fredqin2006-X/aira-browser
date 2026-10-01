import vibrator from '@ohos.vibrator';

const BROWSER_TABS_OVERVIEW_SWIPE_HAPTIC_DURATION_MS: number = 18;

export class BrowserTabsOverviewSwipeFeedbackService {
  static performThresholdFeedback(): void {
    BrowserTabsOverviewSwipeFeedbackService.performTouchTick();
  }

  static performLongPressFeedback(): void {
    BrowserTabsOverviewSwipeFeedbackService.performTouchTick();
  }

  private static performTouchTick(): void {
    vibrator.startVibration({
      type: 'time',
      duration: BROWSER_TABS_OVERVIEW_SWIPE_HAPTIC_DURATION_MS
    }, {
      usage: 'touch'
    }).catch((_error: Error) => {
    });
  }
}
