const DONATE_PRO_INTRO_TITLE_SIZE: number = 30;
const DONATE_PRO_INTRO_BODY_SIZE: number = 17;
const DONATE_PRO_INTRO_ROW_TITLE_SIZE: number = 17;
const DONATE_PRO_INTRO_ROW_DESC_SIZE: number = 14;
const DONATE_PRO_INTRO_NOTE_SIZE: number = 13;
const DONATE_PRO_INTRO_LINK_SIZE: number = 16;
const DONATE_PRO_INTRO_BUTTON_HEIGHT: number = 50;
const DONATE_PRO_INTRO_BUTTON_RADIUS: number = 16;
const DONATE_PRO_INTRO_ICON_SIZE: number = 32;
const DONATE_PRO_INTRO_ROW_GAP: number = 26;
const DONATE_PRO_INTRO_FOOTER_CLEARANCE: number = 112;
const DONATE_PRO_INTRO_HORIZONTAL_PADDING: number = 24;

/**
 * First-visit explanation for 捐赠Pro. Icon feature rows carry what the
 * donation adds; the note keeps the free alternatives visible. Paying stays
 * on the page behind this sheet.
 */
@Component
export struct AiraDonateProIntroSheet {
  @Prop primaryTextColor: ResourceColor = '#111318';
  @Prop secondaryTextColor: ResourceColor = '#5F6875';
  @Prop accentColor: ResourceColor = '#0A59F7';
  @Prop onAccentColor: ResourceColor = '#FFFFFF';
  @Prop surfaceColor: ResourceColor = '#FFFFFF';
  onEnter?: () => void;
  onOpenRepository?: () => void;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column() {
          Text($r('app.string.settings_pro_donate_intro_title'))
            .width('100%')
            .fontSize(DONATE_PRO_INTRO_TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor)
            .textAlign(TextAlign.Center)
            .lineHeight(DONATE_PRO_INTRO_TITLE_SIZE * 1.25)
            .margin({ top: 12 })

          Text($r('app.string.settings_pro_donate_intro_lead'))
            .width('100%')
            .fontSize(DONATE_PRO_INTRO_BODY_SIZE)
            .fontColor(this.secondaryTextColor)
            .textAlign(TextAlign.Center)
            .lineHeight(DONATE_PRO_INTRO_BODY_SIZE * 1.55)
            .margin({ top: 10 })

          this.featureRow($r('app.media.donate_pro_intro_cloud_sync'),
            $r('app.string.settings_pro_donate_intro_row_sync_title'),
            $r('app.string.settings_pro_donate_intro_row_sync_desc'), true)
          this.featureRow($r('app.media.donate_pro_intro_cross_device'),
            $r('app.string.settings_pro_donate_intro_row_link_title'),
            $r('app.string.settings_pro_donate_intro_row_link_desc'), false)
          this.featureRow($r('app.media.donate_pro_intro_support_dev'),
            $r('app.string.settings_pro_donate_intro_row_support_title'),
            $r('app.string.settings_pro_donate_intro_row_support_desc'), false)

          Text($r('app.string.settings_pro_donate_intro_tail'))
            .width('100%')
            .fontSize(DONATE_PRO_INTRO_NOTE_SIZE)
            .fontColor(this.secondaryTextColor)
            .textAlign(TextAlign.Center)
            .lineHeight(DONATE_PRO_INTRO_NOTE_SIZE * 1.65)
            .margin({ top: 30 })

          Text($r('app.string.settings_pro_donate_intro_repo'))
            .width('100%')
            .fontSize(DONATE_PRO_INTRO_LINK_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.accentColor)
            .textAlign(TextAlign.Center)
            .margin({ top: 16 })
            .onClick(() => {
              this.onOpenRepository?.();
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: DONATE_PRO_INTRO_HORIZONTAL_PADDING,
          right: DONATE_PRO_INTRO_HORIZONTAL_PADDING,
          bottom: DONATE_PRO_INTRO_FOOTER_CLEARANCE
        })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)

      Column() {
        Button() {
          Text($r('app.string.settings_pro_donate_intro_enter'))
            .fontSize(DONATE_PRO_INTRO_BODY_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.onAccentColor)
        }
        .width('100%')
        .height(DONATE_PRO_INTRO_BUTTON_HEIGHT)
        .type(ButtonType.Normal)
        .backgroundColor(this.accentColor)
        .borderRadius(DONATE_PRO_INTRO_BUTTON_RADIUS)
        .onClick(() => {
          this.onEnter?.();
        })
      }
      .width('100%')
      .padding({
        left: DONATE_PRO_INTRO_HORIZONTAL_PADDING,
        right: DONATE_PRO_INTRO_HORIZONTAL_PADDING,
        top: 14,
        bottom: 34
      })
      .backgroundColor(this.surfaceColor)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private featureRow(icon: Resource, title: ResourceStr, description: ResourceStr, first: boolean) {
    Row({ space: 14 }) {
      Image(icon)
        .width(DONATE_PRO_INTRO_ICON_SIZE)
        .height(DONATE_PRO_INTRO_ICON_SIZE)
        .objectFit(ImageFit.Contain)

      Column() {
        Text(title)
          .fontSize(DONATE_PRO_INTRO_ROW_TITLE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor)

        Text(description)
          .fontSize(DONATE_PRO_INTRO_ROW_DESC_SIZE)
          .fontColor(this.secondaryTextColor)
          .lineHeight(DONATE_PRO_INTRO_ROW_DESC_SIZE * 1.5)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ top: first ? 32 : DONATE_PRO_INTRO_ROW_GAP })
  }
}
