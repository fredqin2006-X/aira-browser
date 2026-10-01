import { resolveAppResourceText } from '../../../core/resources/AppResourceText';
import { AiraRenderableIconId } from '../../../core/resources/GeneratedAiraIconCatalog';
import {
  BROWSER_THEME_STORAGE_CONTROL_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { AiraIcon } from '../common/AiraIcon';
import { BrowserSheetActionButton } from './BrowserModalBottomSheet';

const ZOOM_ADJUST_CIRCLE_SIZE: number = 44;
const ZOOM_ADJUST_ICON_SIZE: number = 18;
const ZOOM_ADJUST_PRESSED_SCALE: number = 0.86;
const ZOOM_ADJUST_PRESS_DURATION_MS: number = 90;
const ZOOM_ADJUST_RELEASE_DURATION_MS: number = 220;

@Component
export struct BrowserZoomAdjustDialogBody {
  @StorageProp(BROWSER_THEME_STORAGE_CONTROL_BACKGROUND_KEY)
  private storedControlBackgroundColor: string = '#EEF2F6';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY)
  private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY)
  private storedSecondaryTextColor: string = '#5F6875';
  @Prop title: ResourceStr = '';
  @Prop percentLabel: string = '100%';
  @Prop canDecrease: boolean = false;
  @Prop canIncrease: boolean = false;
  @Prop canReset: boolean = false;
  decreaseLabel: ResourceStr = '';
  increaseLabel: ResourceStr = '';
  onDecrease: () => void = (): void => {};
  onIncrease: () => void = (): void => {};
  onReset: () => void = (): void => {};
  onDone: () => void = (): void => {};

  build() {
    Column({ space: 16 }) {
      Row() {
        Blank()
          .width(56)
          .height(44)

        Text(this.title)
          .layoutWeight(1)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.storedPrimaryTextColor)
          .textAlign(TextAlign.Center)
          .maxLines(1)

        BrowserSheetActionButton({
          label: $r('app.string.web_text_zoom_default'),
          fillAvailableWidth: false,
          buttonWidth: 56,
          buttonHeight: 44,
          fontSize: 15,
          actionEnabled: this.canReset,
          onAction: (): void => {
            this.onReset();
          }
        })
      }
      .width('100%')
      .height(44)
      .alignItems(VerticalAlign.Center)

      Row() {
        BrowserZoomAdjustCircleButton({
          iconId: 'browser.toolbar.zoomOut',
          label: resolveAppResourceText(this.decreaseLabel),
          enabled: this.canDecrease,
          iconColor: this.canDecrease ? this.storedPrimaryTextColor : this.storedSecondaryTextColor,
          backgroundColor: this.storedControlBackgroundColor,
          onAction: (): void => {
            this.onDecrease();
          }
        })

        Text(this.percentLabel)
          .layoutWeight(1)
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.storedPrimaryTextColor)
          .textAlign(TextAlign.Center)
          .maxLines(1)

        BrowserZoomAdjustCircleButton({
          iconId: 'browser.toolbar.zoomIn',
          label: resolveAppResourceText(this.increaseLabel),
          enabled: this.canIncrease,
          iconColor: this.canIncrease ? this.storedPrimaryTextColor : this.storedSecondaryTextColor,
          backgroundColor: this.storedControlBackgroundColor,
          onAction: (): void => {
            this.onIncrease();
          }
        })
      }
      .width('100%')
      .height(ZOOM_ADJUST_CIRCLE_SIZE)
      .alignItems(VerticalAlign.Center)

      Row() {
        BrowserSheetActionButton({
          label: $r('app.string.web_text_zoom_done'),
          stacked: true,
          buttonHeight: 44,
          fontSize: 15,
          onAction: (): void => {
            this.onDone();
          }
        })
      }
      .width('100%')
      .height(44)
    }
    .width('100%')
    .height('auto')
    .justifyContent(FlexAlign.Start)
  }

}

@Component
struct BrowserZoomAdjustCircleButton {
  @Prop iconId: AiraRenderableIconId = 'browser.toolbar.zoomIn';
  @Prop label: string = '';
  @Prop enabled: boolean = true;
  @Prop iconColor: ResourceColor = '#111318';
  @Prop backgroundColor: ResourceColor = '#EEF2F6';
  onAction: () => void = (): void => {};
  @State private pressed: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      AiraIcon({
        airaIconId: this.iconId,
        iconSize: ZOOM_ADJUST_ICON_SIZE,
        iconColor: this.iconColor
      })
    }
    .width(ZOOM_ADJUST_CIRCLE_SIZE)
    .height(ZOOM_ADJUST_CIRCLE_SIZE)
    .borderRadius(ZOOM_ADJUST_CIRCLE_SIZE / 2)
    .backgroundColor(this.backgroundColor)
    .opacity(this.enabled ? 1 : 0.38)
    .scale({
      x: this.pressed ? ZOOM_ADJUST_PRESSED_SCALE : 1,
      y: this.pressed ? ZOOM_ADJUST_PRESSED_SCALE : 1
    })
    .animation({
      duration: this.pressed ? ZOOM_ADJUST_PRESS_DURATION_MS : ZOOM_ADJUST_RELEASE_DURATION_MS,
      curve: this.pressed ? Curve.EaseOut : Curve.Friction
    })
    .accessibilityText(this.label)
    .onTouch((event: TouchEvent): void => {
      this.updatePressed(event.type);
    })
    .onClick((): void => {
      if (!this.enabled) {
        return;
      }
      this.onAction();
    })
  }

  private updatePressed(type: TouchType): void {
    if (!this.enabled) {
      this.pressed = false;
      return;
    }
    this.pressed = type === TouchType.Down;
  }
}
