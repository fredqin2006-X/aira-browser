import { UIContext } from '@kit.ArkUI';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';

export class BrowserSafeBrowsingThreatPresentationService {
  private presentingByTabId: Record<string, boolean | undefined> = {};

  presentIfNeeded(uiContext: UIContext, tabId: string, threatType: ThreatType): void {
    if (threatType !== ThreatType.THREAT_WARNING || this.presentingByTabId[tabId] === true) {
      return;
    }
    this.presentingByTabId[tabId] = true;
    void uiContext.getPromptAction().showDialog({
      title: resolveAppResourceText($r('app.string.web_threat_site_risk_title')),
      message: resolveAppResourceText($r('app.string.web_threat_site_risk_message')),
      buttons: [{
        text: resolveAppResourceText($r('app.string.settings_advanced_backup_confirm')),
        color: $r('sys.color.ohos_id_color_text_primary')
      }]
    }).then((): void => {
      this.presentingByTabId[tabId] = undefined;
    }).catch((_error: Error): void => {
      this.presentingByTabId[tabId] = undefined;
    });
  }
}

export const sharedBrowserSafeBrowsingThreatPresentationService: BrowserSafeBrowsingThreatPresentationService =
  new BrowserSafeBrowsingThreatPresentationService();
