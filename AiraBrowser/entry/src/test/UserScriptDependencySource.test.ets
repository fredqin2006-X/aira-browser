import { describe, expect, it } from '@ohos/hypium';
import { isAcceptableUserScriptDependencySource } from '../main/ets/services/userscripts/UserScriptSourceFetchService';

export default function userScriptDependencySourceTest(): void {
  describe('UserScript @require dependency source', () => {
    it('accepts a plain library that has no userscript header', 0, () => {
      const library = '/* locals.js */\nvar I18N = {};\nI18N.conf = {};\n';

      expect(isAcceptableUserScriptDependencySource(library)).assertTrue();
    });

    it('still accepts a required userscript', 0, () => {
      const userscript = '// ==UserScript==\n// @name helper\n// ==/UserScript==\nconsole.log(1);\n';

      expect(isAcceptableUserScriptDependencySource(userscript)).assertTrue();
    });

    it('rejects an HTML error page so it is not stored as a library', 0, () => {
      expect(isAcceptableUserScriptDependencySource('<!DOCTYPE html><html></html>')).assertFalse();
      expect(isAcceptableUserScriptDependencySource('<html><body>missing</body></html>')).assertFalse();
      expect(isAcceptableUserScriptDependencySource('   ')).assertFalse();
    });
  });
}
