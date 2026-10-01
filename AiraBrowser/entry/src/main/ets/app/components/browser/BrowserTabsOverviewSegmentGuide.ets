import { BrowserBottomPanelResponsiveViewModel } from '../../../core/browser/BrowserBottomPanelResponsiveViewModel';
import {
  resolveTabsOverviewSegmentGuidePlacement,
  resolveTabsOverviewSegmentGuideStep,
  TabsOverviewSegmentGuideChromeMetrics,
  TabsOverviewSegmentGuidePlacement,
  TabsOverviewSegmentGuideStep
} from '../../../core/onboarding/TabsOverviewSegmentGuidePolicy';
import {
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import {
  BROWSER_TABS_OVERVIEW_BOTTOM_CHROME_BLOCK_GAP,
  BROWSER_TABS_OVERVIEW_BOTTOM_CHROME_BOTTOM_CLEARANCE,
  BROWSER_TABS_OVERVIEW_BOTTOM_CHROME_HEIGHT,
  BROWSER_TABS_OVERVIEW_BOTTOM_CHROME_OUTER_SIZE,
  BROWSER_TABS_OVERVIEW_BOTTOM_CHROME_SEGMENT_INSET
} from './BrowserTabsOverviewBottomChrome';
import { BROWSER_BOTTOM_ADDRESS_PANEL_FLOATING_HORIZONTAL_INSET } from '../../../core/browser/BrowserBottomAddressPanelMetrics';

const SEGMENT_GUIDE_BUBBLE_WIDTH: number = 232;
const SEGMENT_GUIDE_BUBBLE_HEIGHT: number = 108;
const SEGMENT_GUIDE_BUBBLE_RADIUS: number = 16;
const SEGMENT_GUIDE_ARROW_WIDTH: number = 12;
const SEGMENT_GUIDE_ARROW_HEIGHT: number = 7;
const SEGMENT_GUIDE_ARROW_GAP: number = 8;
const SEGMENT_GUIDE_VIEWPORT_MARGIN: number = 12;
const SEGMENT_GUIDE_MASK_COLOR: string = '#33000000';

@Component
export struct BrowserTabsOverviewSegmentGuide {
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY)
  private storedSurfaceBackgroundColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY)
  private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY)
  private storedSecondaryTextColor: string = '#5F6875';
  @Prop stepIndex: number = 0;
  @Prop viewportWidth: number = 390;
  @Prop viewportHeight: number = 844;
  @Prop bottomChromeLiftVp: number = 0;
  onAdvance: () => void = () => {};

  private responsiveViewModel: BrowserBottomPanelResponsiveViewModel = new BrowserBottomPanelResponsiveViewModel();

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack()
        .width('100%')
        .height('100%')
        .backgroundColor(SEGMENT_GUIDE_MASK_COLOR)
        .hitTestBehavior(HitTestMode.None)

      this.buildBubble()
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Block)
    .onClick(() => {
      this.onAdvance();
    })
  }

  @Builder
  private buildBubble() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Text(this.resolveStep().title)
          .width('100%')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.storedPrimaryTextColor)
          .maxLines(1)
          .minFontScale(1)
          .maxFontScale(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.resolveStep().message)
          .width('100%')
          .fontSize(13)
          .fontColor(this.storedSecondaryTextColor)
          .margin({ top: 4 })
          .maxLines(2)
          .minFontScale(1)
          .maxFontScale(1)

        Row() {
          Text(this.resolveStep().progressLabel)
            .fontSize(12)
            .fontColor(this.storedSecondaryTextColor)
            .minFontScale(1)
            .maxFontScale(1)

          Text(this.resolveStep().continueLabel)
            .fontSize(12)
            .fontColor(this.storedSecondaryTextColor)
            .minFontScale(1)
            .maxFontScale(1)
        }
        .width('100%')
        .margin({ top: 8 })
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width(SEGMENT_GUIDE_BUBBLE_WIDTH)
      .height(SEGMENT_GUIDE_BUBBLE_HEIGHT)
      .padding(14)
      .position({ x: this.resolvePlacement().bubbleLeft, y: this.resolvePlacement().bubbleTop })
      .backgroundColor(this.storedSurfaceBackgroundColor)
      .borderRadius(SEGMENT_GUIDE_BUBBLE_RADIUS)
      .shadow({
        radius: 24,
        color: $r('app.color.elevation_shadow'),
        offsetX: 0,
        offsetY: 6
      })
      .hitTestBehavior(HitTestMode.None)

      Polygon()
        .points(this.resolveArrowPoints())
        .width(SEGMENT_GUIDE_ARROW_WIDTH)
        .height(SEGMENT_GUIDE_ARROW_HEIGHT)
        .fill(this.storedSurfaceBackgroundColor)
        .position({ x: this.resolvePlacement().arrowLeft, y: this.resolvePlacement().arrowTop })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }

  private resolveArrowPoints(): Array<Array<number>> {
    return [
      [0, 0],
      [SEGMENT_GUIDE_ARROW_WIDTH, 0],
      [SEGMENT_GUIDE_ARROW_WIDTH / 2, SEGMENT_GUIDE_ARROW_HEIGHT]
    ];
  }

  private resolveStep(): TabsOverviewSegmentGuideStep {
    return resolveTabsOverviewSegmentGuideStep(this.stepIndex);
  }

  private resolvePlacement(): TabsOverviewSegmentGuidePlacement {
    const responsive = this.responsiveViewModel.buildState({
      viewportWidth: this.viewportWidth,
      viewportHeight: this.viewportHeight
    });
    const metrics: TabsOverviewSegmentGuideChromeMetrics = {
      height: BROWSER_TABS_OVERVIEW_BOTTOM_CHROME_HEIGHT,
      outerSize: BROWSER_TABS_OVERVIEW_BOTTOM_CHROME_OUTER_SIZE,
      blockGap: BROWSER_TABS_OVERVIEW_BOTTOM_CHROME_BLOCK_GAP,
      segmentInset: BROWSER_TABS_OVERVIEW_BOTTOM_CHROME_SEGMENT_INSET,
      bottomClearance: BROWSER_TABS_OVERVIEW_BOTTOM_CHROME_BOTTOM_CLEARANCE,
      horizontalInset: BROWSER_BOTTOM_ADDRESS_PANEL_FLOATING_HORIZONTAL_INSET
    };
    return resolveTabsOverviewSegmentGuidePlacement({
      viewportWidth: this.viewportWidth,
      viewportHeight: this.viewportHeight,
      bottomLiftVp: this.bottomChromeLiftVp,
      panelWidth: responsive.panelWidth,
      panelOffsetX: responsive.panelOffsetX,
      target: this.resolveStep().target,
      bubbleWidth: SEGMENT_GUIDE_BUBBLE_WIDTH,
      bubbleHeight: SEGMENT_GUIDE_BUBBLE_HEIGHT,
      arrowWidth: SEGMENT_GUIDE_ARROW_WIDTH,
      arrowHeight: SEGMENT_GUIDE_ARROW_HEIGHT,
      arrowGap: SEGMENT_GUIDE_ARROW_GAP,
      viewportMargin: SEGMENT_GUIDE_VIEWPORT_MARGIN,
      metrics: metrics
    });
  }
}
