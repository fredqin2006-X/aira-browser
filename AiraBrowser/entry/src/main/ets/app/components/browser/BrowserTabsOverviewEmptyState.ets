import { BrowserTabsOverviewSection } from '../../../core/browser/tabsOverview/BrowserTabsOverviewSectionPolicy';
import { AiraIcon } from '../common/AiraIcon';

const PRIVACY_EMPTY_STATE_ICON_SIZE: number = 56;
const PRIVACY_EMPTY_STATE_CONTENT_WIDTH: number = 300;

@Component
export struct BrowserTabsOverviewEmptyState {
  @Prop selectedSection: BrowserTabsOverviewSection = 'tabs';
  @Prop textColor: ResourceColor = '';

  build() {
    Column({ space: 14 }) {
      if (this.selectedSection === 'privacy') {
        AiraIcon({
          airaIconId: 'browser.toolbar.privacyMode',
          iconSize: PRIVACY_EMPTY_STATE_ICON_SIZE,
          iconColor: this.textColor
        })
          .margin({ bottom: 4 })

        Text($r('app.string.browser_ui_browser_tabs_overview_empty_state_003'))
          .width('100%')
          .constraintSize({ maxWidth: PRIVACY_EMPTY_STATE_CONTENT_WIDTH })
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
          .textAlign(TextAlign.Center)
          .maxLines(2)

        Text($r('app.string.browser_ui_browser_tabs_overview_empty_state_001'))
          .width('100%')
          .constraintSize({ maxWidth: PRIVACY_EMPTY_STATE_CONTENT_WIDTH })
          .fontSize(14)
          .lineHeight(21)
          .fontColor(this.textColor)
          .textAlign(TextAlign.Center)
      } else {
        Text($r('app.string.browser_ui_browser_tabs_overview_empty_state_002'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
