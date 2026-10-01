import { describe, expect, it } from '@ohos/hypium';
import { insertMissingBrowserToolbarActions } from '../main/ets/data/preferences/PreferencesRepository';

export default function browserToolbarActionInsertPolicyTest(): void {
  describe('BrowserToolbarActionInsertPolicy', () => {
    it('inserts page zoom beside text size and keeps find after it', 0, () => {
      const inserted = insertMissingBrowserToolbarActions(
        ['userAgent', 'textZoom', 'find', 'reader'],
        ['webZoom']
      );
      expect(inserted.join(',')).assertEqual('userAgent,textZoom,webZoom,find,reader');
    });

    it('inserts a missing find after page zoom when both are new', 0, () => {
      const inserted = insertMissingBrowserToolbarActions(
        ['textZoom', 'reader'],
        ['webZoom', 'find', 'offline']
      );
      expect(inserted.join(',')).assertEqual('textZoom,webZoom,find,reader,offline');
    });

    it('appends page zoom when text size was removed', 0, () => {
      const inserted = insertMissingBrowserToolbarActions(
        ['find', 'reader'],
        ['webZoom']
      );
      expect(inserted.join(',')).assertEqual('find,reader,webZoom');
    });
  });
}
