import { describe, expect, it } from '@ohos/hypium';
import { isAppString } from '../main/ets/core/resources/AppResourceText';
import {
  HISTORY_SELECTION_MORE_EMPTY_MESSAGE,
  planHistorySelectionMoreMenu
} from '../main/ets/features/history/HistorySelectionMoreMenu';

export default function historySelectionMoreMenuTest(): void {
  describe('History edit-mode more menu', () => {
    it('still presents timeline actions when the user has not selected any rows', 0, () => {
      const plan = planHistorySelectionMoreMenu('timeline', 0, true);
      expect(plan.selectedCount).assertEqual(0);
      expect(plan.emptySelectionMessage).assertEqual(HISTORY_SELECTION_MORE_EMPTY_MESSAGE);
      expect(plan.items.length).assertEqual(4);
      expect(plan.items[0].id).assertEqual('copy_links');
      expect(isAppString(plan.items[0].title, $r('app.string.history_batch_copy'))).assertTrue();
      expect(plan.items[1].id).assertEqual('add_bookmarks');
      expect(isAppString(plan.items[1].title, $r('app.string.history_batch_add_bookmarks'))).assertTrue();
      expect(plan.items[2].id).assertEqual('remove_bookmarks');
      expect(isAppString(plan.items[2].title, $r('app.string.history_batch_remove_bookmarks'))).assertTrue();
      expect(plan.items[3].id).assertEqual('share_links');
      expect(isAppString(plan.items[3].title, $r('app.string.history_batch_share'))).assertTrue();
    });

    it('still presents the site cleanup action when the user has not selected any sites', 0, () => {
      const plan = planHistorySelectionMoreMenu('sites', 0, false);
      expect(plan.selectedCount).assertEqual(0);
      expect(plan.items.length).assertEqual(1);
      expect(plan.items[0].id).assertEqual('delete_selected_sites');
      expect(isAppString(plan.items[0].title, $r('app.string.history_delete_selected_sites'))).assertTrue();
    });
  });
}
