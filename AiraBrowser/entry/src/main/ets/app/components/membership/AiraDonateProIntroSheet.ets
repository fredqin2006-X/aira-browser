import { BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY } from '../../../core/theme/BrowserThemeStorageKeys';
import {
  BrowserImmersiveSheetLayout,
  BrowserSheetActionButton,
  BROWSER_IMMERSIVE_SHEET_HEADER_CONTENT_TOP_INSET,
  BROWSER_MODAL_BOTTOM_SHEET_HORIZONTAL_PADDING,
  BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING,
  browserSheetHeaderBlurModifier,
  resolveBrowserSheetHeaderBlurRadius
} from '../browser/BrowserModalBottomSheet';

const DONATE_PRO_INTRO_TITLE_SIZE: number = 30;
const DONATE_PRO_INTRO_BODY_SIZE: number = 17;
const DONATE_PRO_INTRO_ROW_TITLE_SIZE: number = 17;
const DONATE_PRO_INTRO_ROW_DESC_SIZE: number = 14;
const DONATE_PRO_INTRO_NOTE_SIZE: number = 13;
const DONATE_PRO_INTRO_LINK_SIZE: number = 16;
const DONATE_PRO_INTRO_ICON_SIZE: number = 32;
const DONATE_PRO_INTRO_MARK_SIZE: number = 64;
const DONATE_PRO_INTRO_MARK_RADIUS: number = 18;
const DONATE_PRO_INTRO_MARK_ICON_SIZE: number = 32;
const DONATE_PRO_INTRO_ROW_GAP: number = 26;
/** Pulls the feature column in from the sheet padding so the rows are not flush with the edges. */
const DONATE_PRO_INTRO_BODY_SIDE_INSET: number = 20;
const DONATE_PRO_INTRO_REPO_BUTTON_HEIGHT: number = 44;
const DONATE_PRO_INTRO_FOOTER_GAP: number = 8;
/** Clears the floating repo link and the primary action beneath the body. */
const DONATE_PRO_INTRO_FOOTER_CLEARANCE: number = 156;

/**
 * First-visit explanation for 捐赠Pro. Icon feature rows carry what the
 * donation adds; the note keeps the free alternatives visible. Paying stays
 * on the page behind this sheet. Chrome matches the immersive half-modal:
 * the glass close stays above the scroll, and the action keeps the standard inset.
 */
@Component
export struct AiraDonateProIntroSheet {
  @Prop primaryTextColor: ResourceColor = '#111318';
  @Prop secondaryTextColor: ResourceColor = '#5F6875';
  @Prop accentColor: ResourceColor = '#0A59F7';
  @Prop onAccentColor: ResourceColor = '#FFFFFF';
  @Prop surfaceColor: ResourceColor = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY) private storedPressedBackgroundColor: string = '#DDE4EC';
  onEnter?: () => void;
  onOpenRepository?: () => void;
  @State private sheetHeaderBlurRadius: number = 0;
  private readonly sheetBlurScroller: Scroller = new Scroller();

  build() {
    BrowserImmersiveSheetLayout({
      closeVisible: true,
      closeAccessibilityLabel: $r('app.string.ui_close'),
      footerVisible: true,
      footerBottomPadding: BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING,
      horizontalPadding: BROWSER_MODAL_BOTTOM_SHEET_HORIZONTAL_PADDING,
      onClose: (): void => {
        this.onEnter?.();
      },
      scrollContent: (): void => {
        this.buildScrollContent()
      },
      footer: (): void => {
        this.buildFooter()
      }
    })
  }

  @Builder
  private buildScrollContent() {
    Scroll(this.sheetBlurScroller) {
      Column() {
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            Image($r('app.media.donate_pro_intro_crow'))
              .width(DONATE_PRO_INTRO_MARK_ICON_SIZE)
              .height(DONATE_PRO_INTRO_MARK_ICON_SIZE)
              .objectFit(ImageFit.Contain)
          }
          .width(DONATE_PRO_INTRO_MARK_SIZE)
          .height(DONATE_PRO_INTRO_MARK_SIZE)
          .borderRadius(DONATE_PRO_INTRO_MARK_RADIUS)
          .backgroundColor(this.accentColor)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 16 })

        Text($r('app.string.settings_pro_donate_intro_title'))
          .width('100%')
          .fontSize(DONATE_PRO_INTRO_TITLE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor)
          .textAlign(TextAlign.Center)
          .lineHeight(DONATE_PRO_INTRO_TITLE_SIZE * 1.25)

        Text($r('app.string.settings_pro_donate_intro_lead'))
          .width('100%')
          .fontSize(DONATE_PRO_INTRO_BODY_SIZE)
          .fontColor(this.secondaryTextColor)
          .textAlign(TextAlign.Center)
          .lineHeight(DONATE_PRO_INTRO_BODY_SIZE * 1.55)
          .margin({ top: 10 })

        Column() {
          this.buildBody()
        }
        .width('100%')
        .padding({
          left: DONATE_PRO_INTRO_BODY_SIDE_INSET,
          right: DONATE_PRO_INTRO_BODY_SIDE_INSET
        })
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .padding({
        left: BROWSER_MODAL_BOTTOM_SHEET_HORIZONTAL_PADDING,
        right: BROWSER_MODAL_BOTTOM_SHEET_HORIZONTAL_PADDING,
        top: BROWSER_IMMERSIVE_SHEET_HEADER_CONTENT_TOP_INSET,
        bottom: DONATE_PRO_INTRO_FOOTER_CLEARANCE
      })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .clip(false)
    .nestedScroll({
      scrollForward: NestedScrollMode.PARENT_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
    .attributeModifier(browserSheetHeaderBlurModifier(this.sheetHeaderBlurRadius))
    .onDidScroll((_xOffset: number, _yOffset: number): void => {
      this.sheetHeaderBlurRadius = resolveBrowserSheetHeaderBlurRadius(
        this.sheetBlurScroller.currentOffset().yOffset);
    })
  }

  @Builder
  private buildBody() {
    Column() {
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
        .margin({ top: 28 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildFooter() {
    Column({ space: DONATE_PRO_INTRO_FOOTER_GAP }) {
      Button() {
        Text($r('app.string.settings_pro_donate_intro_repo'))
          .fontSize(DONATE_PRO_INTRO_LINK_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.accentColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(DONATE_PRO_INTRO_REPO_BUTTON_HEIGHT)
      .type(ButtonType.Capsule)
      .backgroundColor(Color.Transparent)
      .borderRadius(DONATE_PRO_INTRO_REPO_BUTTON_HEIGHT / 2)
      .clip(true)
      .stateEffect(false)
      .stateStyles({
        normal: {
          .backgroundColor(Color.Transparent)
        },
        pressed: {
          .backgroundColor(this.storedPressedBackgroundColor)
        }
      })
      .onClick(() => {
        this.onOpenRepository?.();
      })

      BrowserSheetActionButton({
        label: $r('app.string.settings_pro_donate_intro_enter'),
        emphasis: 'primary',
        stacked: true,
        accentColor: this.accentColor,
        buttonHeight: 50,
        fontSize: DONATE_PRO_INTRO_BODY_SIZE,
        onAction: (): void => {
          this.onEnter?.();
        }
      })
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
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
          .width('100%')
          .fontSize(DONATE_PRO_INTRO_ROW_TITLE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor)

        Text(description)
          .width('100%')
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
    .margin({ top: first ? 8 : DONATE_PRO_INTRO_ROW_GAP })
  }
}
