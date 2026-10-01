import { resolveAppResourceText } from '../../../core/resources/AppResourceText';
import { BrowserTabOverviewItemPresentation } from '../../../core/browser/BrowserTabsOverlayViewModel';
import { BrowserTabState } from '../../../core/tabs/TabManager';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_CONTROL_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_FLOATING_SURFACE_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import {
  BROWSER_TABS_OVERVIEW_IDENTITY_TITLE_MAX_FONT_SCALE,
  BROWSER_TABS_OVERVIEW_LIST_ROW_CORNER_RADIUS
} from '../../../core/browser/BrowserTabsOverviewVisualTokens';
import { AiraIcon } from '../common/AiraIcon';
import { SiteIconView } from '../common/SiteIconView';
import { BrowserTabOverviewCardSelectRect } from './BrowserTabOverviewCard';

const TAB_OVERVIEW_LIST_ROW_RADIUS: number = BROWSER_TABS_OVERVIEW_LIST_ROW_CORNER_RADIUS;
const TAB_OVERVIEW_LIST_ROW_ICON_SIZE: number = 22;
const TAB_OVERVIEW_LIST_ROW_ICON_GAP: number = 10;
const TAB_OVERVIEW_LIST_ROW_LEADING_INSET: number = 14;
const TAB_OVERVIEW_LIST_ROW_TRAILING_INSET: number = 6;
const TAB_OVERVIEW_LIST_ROW_TITLE_FONT_SIZE: number = 16;
const TAB_OVERVIEW_LIST_ROW_CLOSE_SIZE: number = 32;
const TAB_OVERVIEW_LIST_ROW_CLOSE_ICON_SIZE: number = 16;
const TAB_OVERVIEW_LIST_ROW_PRESSED_SCALE: number = 0.985;
const TAB_OVERVIEW_LIST_ROW_PRESSED_ANIMATION_MS: number = 120;
const TAB_OVERVIEW_LIST_ROW_ACTIVE_BORDER_WIDTH: number = 1.5;

@Component
export struct BrowserTabOverviewListRow {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_CONTROL_BACKGROUND_KEY)
  private storedControlBackgroundColor: string = '#ECEDEF';
  @StorageProp(BROWSER_THEME_STORAGE_FLOATING_SURFACE_KEY)
  private storedFloatingSurfaceColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';

  @Prop tab: BrowserTabState;
  @Prop presentation: BrowserTabOverviewItemPresentation;
  @Prop active: boolean = false;
  @Prop rowEnabled: boolean = true;
  @Prop rowHeight: number = 52;
  @Prop rowTranslateX: number = 0;
  @Prop rowOpacity: number = 1;
  @Prop contentOpacity: number = 1;
  @Prop frameOpacity: number = 1;
  @Prop frameScale: number = 1;
  @Prop motionDurationMs: number = 0;
  @Prop motionCurve: Curve | string | ICurve = Curve.Linear;
  @Prop motionDelayMs: number = 0;

  @State private isPressed: boolean = false;
  private suppressNextSelection: boolean = false;
  private lastPreviewRect: BrowserTabOverviewCardSelectRect | undefined = undefined;

  onSelect: (tabId: string, rect?: BrowserTabOverviewCardSelectRect) => void =
    (_tabId: string, _rect?: BrowserTabOverviewCardSelectRect) => {};
  onCloseTab: (tabId: string) => void = (_tabId: string) => {};
  onPreviewRectChange: (
    tabId: string,
    left: number,
    top: number,
    width: number,
    height: number
  ) => void = (_tabId: string, _left: number, _top: number, _width: number, _height: number) => {};

  build() {
    Row() {
      // The measured row stays at the final size so the shrinking page keeps that
      // target. The chip itself can draw larger and transparent, then settle in.
      Stack() {
        Stack() {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor(this.isPressed ? this.storedControlBackgroundColor : this.storedFloatingSurfaceColor)
            .borderRadius(TAB_OVERVIEW_LIST_ROW_RADIUS)
            .border({
              width: TAB_OVERVIEW_LIST_ROW_ACTIVE_BORDER_WIDTH,
              color: this.active ? this.storedAccentColor : Color.Transparent
            })
            .opacity(this.frameOpacity)

          Row({ space: TAB_OVERVIEW_LIST_ROW_ICON_GAP }) {
            SiteIconView({
              iconUri: this.presentation.identity.iconUri,
              iconPixelMap: this.presentation.identity.iconPixelMap,
              fallbackLabel: this.presentation.identity.fallbackLabel,
              fallbackAiraIconId: this.presentation.identity.fallbackAiraIconId,
              fallbackIconSize: 16,
              iconSize: TAB_OVERVIEW_LIST_ROW_ICON_SIZE,
              cornerRadiusRatio: 0.22,
              frameBorderWidth: 0,
              contentPadding: 0,
              fallbackFontSize: 12,
              fallbackFontWeight: FontWeight.Medium,
              containerBackgroundColor: Color.Transparent,
              textColor: this.storedSecondaryTextColor,
              fit: ImageFit.Contain,
              preferPixelMap: this.presentation.identity.iconPixelMap !== undefined,
              sourceRevision: this.presentation.identity.sourceRevision,
              hitTestMode: HitTestMode.None
            })

            Text(this.presentation.identity.label)
              .layoutWeight(1)
              .constraintSize({ minWidth: 0 })
              .fontSize(TAB_OVERVIEW_LIST_ROW_TITLE_FONT_SIZE)
              .maxFontScale(BROWSER_TABS_OVERVIEW_IDENTITY_TITLE_MAX_FONT_SCALE)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.storedPrimaryTextColor)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            this.buildCloseButton()
          }
          .width('100%')
          .height('100%')
          .padding({
            left: TAB_OVERVIEW_LIST_ROW_LEADING_INSET,
            right: TAB_OVERVIEW_LIST_ROW_TRAILING_INSET
          })
          .alignItems(VerticalAlign.Center)
          .opacity(this.contentOpacity)
        }
        .width('100%')
        .height('100%')
        .clip(true)
        .borderRadius(TAB_OVERVIEW_LIST_ROW_RADIUS)
        .scale({
          x: this.isPressed ? TAB_OVERVIEW_LIST_ROW_PRESSED_SCALE : 1,
          y: this.isPressed ? TAB_OVERVIEW_LIST_ROW_PRESSED_SCALE : 1
        })
        .animation({
          duration: TAB_OVERVIEW_LIST_ROW_PRESSED_ANIMATION_MS,
          curve: Curve.EaseOut
        })
      }
      .width('100%')
      .height('100%')
      .scale({
        x: this.frameScale,
        y: this.frameScale
      })
    }
    .width('100%')
    .height(this.rowHeight)
    .alignItems(VerticalAlign.Center)
    .clip(false)
    .translate({ x: this.rowTranslateX })
    .opacity(this.rowOpacity)
    .animation({
      duration: this.motionDurationMs,
      curve: this.motionCurve,
      delay: this.motionDelayMs
    })
    .enabled(this.rowEnabled)
    .hitTestBehavior(this.rowEnabled ? HitTestMode.Default : HitTestMode.None)
    .accessibilityText(resolveAppResourceText($r('app.string.tab_a11y_switch', this.presentation.identity.label)))
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.recordPreviewRect(newArea);
    })
    .onClick(() => {
      if (this.consumeCloseSelectionSuppression()) {
        return;
      }
      if (!this.rowEnabled) {
        return;
      }
      this.onSelect(this.tab.id, this.lastPreviewRect);
    })
    .onTouch((event: TouchEvent) => {
      if (!this.rowEnabled) {
        this.isPressed = false;
        return;
      }
      this.isPressed = event.type === TouchType.Down || event.type === TouchType.Move;
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
  }

  @Builder
  private buildCloseButton() {
    Button({ type: ButtonType.Circle }) {
      AiraIcon({
        airaIconId: 'browser.tabs.delete',
        iconSize: TAB_OVERVIEW_LIST_ROW_CLOSE_ICON_SIZE,
        iconColor: this.storedSecondaryTextColor
      })
    }
    .buttonStyle(ButtonStyleMode.NORMAL)
    .stateEffect(true)
    .width(TAB_OVERVIEW_LIST_ROW_CLOSE_SIZE)
    .height(TAB_OVERVIEW_LIST_ROW_CLOSE_SIZE)
    .backgroundColor(Color.Transparent)
    .enabled(this.rowEnabled)
    .hitTestBehavior(this.rowEnabled ? HitTestMode.Default : HitTestMode.None)
    .accessibilityText(resolveAppResourceText($r('app.string.tab_a11y_close', this.presentation.identity.label)))
    .onTouch((event: TouchEvent) => {
      event.stopPropagation();
    })
    .onClick(() => {
      this.suppressNextSelection = true;
      this.isPressed = false;
      this.onCloseTab(this.tab.id);
    })
  }

  private consumeCloseSelectionSuppression(): boolean {
    if (!this.suppressNextSelection) {
      return false;
    }
    this.suppressNextSelection = false;
    return true;
  }

  private recordPreviewRect(area: Area): void {
    const rect: BrowserTabOverviewCardSelectRect = {
      left: this.parseAreaPosition(area.globalPosition.x),
      top: this.parseAreaPosition(area.globalPosition.y),
      width: this.parseAreaDimension(area.width),
      height: this.parseAreaDimension(area.height)
    };
    if (rect.width <= 0 || rect.height <= 0) {
      return;
    }
    this.lastPreviewRect = rect;
    this.onPreviewRectChange(this.tab.id, rect.left, rect.top, rect.width, rect.height);
  }

  private parseAreaDimension(value: Length): number {
    if (typeof value === 'number') {
      return value;
    }
    const parsed = Number.parseFloat(`${value}`);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  private parseAreaPosition(value?: Length): number {
    if (value === undefined) {
      return 0;
    }
    if (typeof value === 'number') {
      return value;
    }
    const parsed = Number.parseFloat(`${value}`);
    return Number.isFinite(parsed) ? parsed : 0;
  }
}
