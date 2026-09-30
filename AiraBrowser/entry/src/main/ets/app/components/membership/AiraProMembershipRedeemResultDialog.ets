import { AiraProMembershipRedeemResultState } from '../../../core/membership/AiraProMembershipRedeemResult';
import { AiraProMembershipRedeemConfetti } from './AiraProMembershipRedeemConfetti';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_ON_ACCENT_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { BrowserSheetActionButton } from '../browser/BrowserModalBottomSheet';
import {
  CENTERED_DIALOG_CORNER_RADIUS_VP,
  CENTERED_DIALOG_MAX_WIDTH_VP,
  resolveCenteredDialogControllerWidth,
  resolveCenteredDialogSurfaceColor
} from '../common/CenteredDialogSurface';

const REDEEM_RESULT_ART_ASPECT_RATIO: number = 1125 / 500;
const REDEEM_RESULT_VALUE_FONT_SIZE: number = 64;
const REDEEM_RESULT_UNIT_FONT_SIZE: number = 20;

@CustomDialog
export struct AiraProMembershipRedeemResultDialog {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_ON_ACCENT_KEY) private storedOnAccentColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  controller?: CustomDialogController;
  @Link result: AiraProMembershipRedeemResultState;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .onClick(() => {
          this.controller?.close();
        })

      this.buildCard()

      AiraProMembershipRedeemConfetti()
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildCard() {
    Column() {
      Image($r('app.media.membership_reward_card'))
        .width('100%')
        .aspectRatio(REDEEM_RESULT_ART_ASPECT_RATIO)
        .objectFit(ImageFit.Cover)
        .draggable(false)

      Column({ space: 16 }) {
        Column({ space: 0 }) {
          this.buildValueMark()

          Text(this.result.caption)
            .width('100%')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.storedSecondaryTextColor)
            .textAlign(TextAlign.Center)
            .margin({ top: 2 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        Column({ space: 8 }) {
          BrowserSheetActionButton({
            label: this.resolveActionText(),
            emphasis: 'primary',
            stacked: true,
            accentColor: this.storedAccentColor,
            textColor: this.storedOnAccentColor,
            buttonHeight: 44,
            fontSize: 15,
            onAction: () => {
              this.controller?.close();
            }
          })

          BrowserSheetActionButton({
            label: $r('app.string.settings_account_cancel'),
            emphasis: 'ghost',
            stacked: true,
            buttonHeight: 44,
            fontSize: 15,
            onAction: () => {
              this.controller?.close();
            }
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding({
        left: 20,
        right: 20,
        top: 16,
        bottom: 16
      })
    }
    .width(resolveCenteredDialogControllerWidth('s'))
    .constraintSize({ maxWidth: CENTERED_DIALOG_MAX_WIDTH_VP })
    .backgroundColor(resolveCenteredDialogSurfaceColor())
    .borderRadius(CENTERED_DIALOG_CORNER_RADIUS_VP)
    .clip(true)
  }

  @Builder
  private buildValueMark() {
    Row() {
      Text(this.result.valueText)
        .fontSize(REDEEM_RESULT_VALUE_FONT_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.storedPrimaryTextColor)
        .lineHeight(REDEEM_RESULT_VALUE_FONT_SIZE)

      if (this.hasVisibleText(this.result.unitText)) {
        Text(this.result.unitText)
          .fontSize(REDEEM_RESULT_UNIT_FONT_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.storedPrimaryTextColor)
          .margin({ left: 2, bottom: 10 })
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Bottom)
  }

  private resolveActionText(): ResourceStr {
    return this.hasVisibleText(this.result.actionText) ? this.result.actionText : $r('app.string.settings_pro_got_it');
  }

  private hasVisibleText(value: ResourceStr): boolean {
    return typeof value !== 'string' || value.length > 0;
  }
}
