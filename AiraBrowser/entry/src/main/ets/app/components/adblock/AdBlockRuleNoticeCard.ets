import { SettingsNoticeCard } from '../settings/SettingsNoticeCard';

@Component
export struct AdBlockRuleNoticeCard {
  @Prop desktopPresentation: boolean = false;
  onClosed: () => void = () => {};

  build() {
    SettingsNoticeCard({
      title: $r('app.string.adblock_ui_ad_block_rule_notice_card_002'),
      message: $r('app.string.adblock_ui_ad_block_rule_notice_card_001'),
      desktopPresentation: this.desktopPresentation,
      onClosed: () => {
        this.onClosed();
      }
    })
  }
}
