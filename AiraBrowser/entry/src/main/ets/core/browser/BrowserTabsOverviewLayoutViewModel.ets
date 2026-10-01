import { BrowserTabsOverviewLayoutStyle } from '../../common/models/BrowserModels';
import {
  AppWindowResponsiveFacts,
  AppWindowResponsiveLayoutService
} from '../../services/layout/AppWindowResponsiveLayoutService';
import {
  BROWSER_TABS_OVERVIEW_GRID_BOTTOM_CROP_FRACTION,
  BROWSER_TABS_OVERVIEW_IDENTITY_HEADER_HEIGHT,
  BROWSER_TABS_OVERVIEW_IDENTITY_PREVIEW_GAP,
  BROWSER_TABS_OVERVIEW_IDENTITY_TITLE_FONT_SIZE,
  BROWSER_TABS_OVERVIEW_IDENTITY_TITLE_MAX_FONT_SCALE
} from './BrowserTabsOverviewVisualTokens';

export interface BrowserTabsOverviewLayoutInput {
  gridWidth: number;
  sheetWidth: number;
  sheetHeight: number;
  layoutStyle?: BrowserTabsOverviewLayoutStyle | string;
  /**
   * System font scale the shell actually applies to native UI. Phone follows the
   * system; the large-screen shell passes 1 because it pins its own UI scale.
   */
  uiFontScale?: number;
}

export interface BrowserTabsOverviewLayoutState {
  layoutStyle: BrowserTabsOverviewLayoutStyle;
  columnCount: number;
  columnsTemplate: string;
  gridGap: number;
  cardWidth: number;
  previewHeight: number;
  identityHeaderHeight: number;
  identityPreviewGap: number;
  itemHeight: number;
  horizontalContentInset: number;
}

export function isSameTabsOverviewLayoutState(
  current: BrowserTabsOverviewLayoutState,
  next: BrowserTabsOverviewLayoutState
): boolean {
  return current.layoutStyle === next.layoutStyle &&
    current.columnCount === next.columnCount &&
    current.columnsTemplate === next.columnsTemplate &&
    current.gridGap === next.gridGap &&
    current.cardWidth === next.cardWidth &&
    current.previewHeight === next.previewHeight &&
    current.identityHeaderHeight === next.identityHeaderHeight &&
    current.identityPreviewGap === next.identityPreviewGap &&
    current.itemHeight === next.itemHeight &&
    current.horizontalContentInset === next.horizontalContentInset;
}

interface BrowserTabsOverviewLayoutFrame {
  width: number;
  height: number;
}

interface BrowserTabsOverviewLayoutBaseState {
  layoutStyle: BrowserTabsOverviewLayoutStyle;
  columnCount: number;
  columnsTemplate: string;
  gridGap: number;
  cardWidth: number;
  previewHeight: number;
  identityHeaderHeight: number;
  horizontalContentInset: number;
  itemHeight?: number;
}

/**
 * Readable card width. Used only to drop a column when the fitted width would be narrower than
 * this. It must not raise a card past its grid slot: display-size scaling shrinks the vp count,
 * and a floor wider than the slot is what stacks two cards on top of each other.
 */
const TAB_OVERVIEW_LAYOUT_MIN_CARD_WIDTH: number = 132;
const TAB_OVERVIEW_LAYOUT_MIN_PREVIEW_HEIGHT: number = 118;
/**
 * Room kept above a centred card for the status bar and below it for the floating bar. The
 * preview height ratio ignores both, so a display-size-shrunk sheet clips the card without this.
 */
const TAB_OVERVIEW_LAYOUT_SHEET_CHROME_RESERVE: number = 96;
const TAB_OVERVIEW_LAYOUT_GRID_GAP: number = 16;
const TAB_OVERVIEW_LAYOUT_TOP_PADDING: number = 16;
const TAB_OVERVIEW_LAYOUT_TOP_SAFE_GAP: number = 10;
/**
 * Zero gap for the stacked deck.
 *
 * Every card is placed by its own offset inside a `Stack`, so there is no stride left for a gap to
 * sit in. The value only reaches the selection-displacement camera now, where a card travels its
 * own width and nothing more.
 */
const TAB_OVERVIEW_STACK_GAP: number = 0;
/**
 * Gap between the large cards of the horizontal strip.
 */
const TAB_OVERVIEW_HORIZONTAL_CARDS_GAP: number = 18;
/**
 * Focused card width, over the usable width, for the stacked deck on a portrait window.
 *
 * Smaller than the flat strip's 0.82 because a deck spends width on the leading strip and on the
 * trailing neighbour instead of on the focused card alone. Kept at 0.70 so the nearest leading
 * strip, which peeks `cardWidth * 0.22` past the focused card's edge, stays on the sheet on the
 * narrowest phones.
 */
const TAB_OVERVIEW_STACK_PHONE_WIDTH_RATIO: number = 0.70;
const TAB_OVERVIEW_STACK_LANDSCAPE_WIDTH_RATIO: number = 0.56;
const TAB_OVERVIEW_STACK_MAX_WIDTH: number = 520;
const TAB_OVERVIEW_STACK_VIEWPORT_HEIGHT_RATIO: number = 0.66;
/**
 * Portrait width ratio of one large card in the horizontal strip.
 *
 * 0.82 leaves the neighbouring card a sliver of the sheet, which is what makes the strip read as
 * "swipe sideways for the next card" instead of "one card fills the screen".
 */
const TAB_OVERVIEW_HORIZONTAL_CARDS_PHONE_WIDTH_RATIO: number = 0.82;
const TAB_OVERVIEW_HORIZONTAL_CARDS_LANDSCAPE_WIDTH_RATIO: number = 0.56;
const TAB_OVERVIEW_HORIZONTAL_CARDS_MAX_WIDTH: number = 520;
const TAB_OVERVIEW_HORIZONTAL_CARDS_VIEWPORT_HEIGHT_RATIO: number = 0.66;
/**
 * One list row. Taller than the caption above a card, because the row is the whole tab: icon,
 * title and the close button share it. The extra padding keeps a scaled title inside the chip.
 */
const TAB_OVERVIEW_LIST_GAP: number = 10;
const TAB_OVERVIEW_LIST_ROW_MIN_HEIGHT: number = 52;
const TAB_OVERVIEW_LIST_ROW_EXTRA_PADDING: number = 24;

export class BrowserTabsOverviewLayoutViewModel {
  private readonly responsiveLayoutService: AppWindowResponsiveLayoutService =
    new AppWindowResponsiveLayoutService();

  buildState(input: BrowserTabsOverviewLayoutInput): BrowserTabsOverviewLayoutState {
    const layoutStyle = this.normalizeLayoutStyle(input.layoutStyle);
    const usableWidth = this.resolveUsableWidth(input);
    if (layoutStyle === 'horizontal_cards') {
      return this.buildHorizontalCardsState(input, usableWidth);
    }
    if (layoutStyle === 'stack') {
      return this.buildStackState(input, usableWidth);
    }
    if (layoutStyle === 'list') {
      return this.buildListState(input, usableWidth);
    }
    const responsiveFacts = this.resolveResponsiveFacts(input);
    const columnCount = this.resolveFittingColumnCount(responsiveFacts, usableWidth);
    const cardWidth = this.resolveCardWidth(usableWidth, columnCount);
    const previewHeight = this.resolvePreviewHeight(input, cardWidth);
    return this.buildLayoutState({
      layoutStyle: 'grid',
      columnCount: columnCount,
      columnsTemplate: this.buildColumnsTemplate(columnCount),
      gridGap: TAB_OVERVIEW_LAYOUT_GRID_GAP,
      cardWidth: cardWidth,
      previewHeight: previewHeight,
      identityHeaderHeight: this.resolveIdentityHeaderHeight(input.uiFontScale),
      horizontalContentInset: 0
    });
  }

  /**
   * The large centred card strip.
   *
   * One card per page, centred by an equal inset on either edge so the first and the last card can
   * both rest in the middle of the sheet.
   */
  private buildHorizontalCardsState(
    input: BrowserTabsOverviewLayoutInput,
    usableWidth: number
  ): BrowserTabsOverviewLayoutState {
    const headerHeight = this.resolveIdentityHeaderHeight(input.uiFontScale);
    const maxWidth = this.resolveHorizontalCardWidth(input, usableWidth);
    const maxHeight = this.resolveHorizontalPreviewHeight(input, headerHeight);
    // The shared box keeps the page's own aspect. Two independent ratios make a wider card than
    // the screenshot, and the picture then sits inside it with a white border.
    const frame = this.resolveViewportAspectFrame(input.sheetWidth, input.sheetHeight, maxWidth, maxHeight);
    return this.buildLayoutState({
      layoutStyle: 'horizontal_cards',
      columnCount: 1,
      columnsTemplate: '1fr',
      gridGap: TAB_OVERVIEW_HORIZONTAL_CARDS_GAP,
      cardWidth: frame.width,
      previewHeight: frame.height,
      identityHeaderHeight: headerHeight,
      horizontalContentInset: Math.max(0, (usableWidth - frame.width) / 2)
    });
  }

  /**
   * The stacked deck.
   *
   * Every card is placed by its own offset inside a `Stack`, so the state only carries the focused
   * card's width and the preview height the deck scales from.
   */
  private buildStackState(
    input: BrowserTabsOverviewLayoutInput,
    usableWidth: number
  ): BrowserTabsOverviewLayoutState {
    const headerHeight = this.resolveIdentityHeaderHeight(input.uiFontScale);
    const cardWidth = this.resolveStackCardWidth(input, usableWidth);
    return this.buildLayoutState({
      layoutStyle: 'stack',
      columnCount: 1,
      columnsTemplate: '1fr',
      gridGap: TAB_OVERVIEW_STACK_GAP,
      cardWidth: cardWidth,
      previewHeight: this.resolveStackPreviewHeight(input, headerHeight),
      identityHeaderHeight: headerHeight,
      horizontalContentInset: 0
    });
  }

  /**
   * The icon-and-title list.
   *
   * One full-width row per tab. There is no page preview, so the row height is the item height and
   * the identity header is not stacked above a second block.
   */
  private buildListState(
    input: BrowserTabsOverviewLayoutInput,
    usableWidth: number
  ): BrowserTabsOverviewLayoutState {
    const headerHeight = this.resolveIdentityHeaderHeight(input.uiFontScale);
    const rowHeight = Math.max(
      TAB_OVERVIEW_LIST_ROW_MIN_HEIGHT,
      headerHeight + TAB_OVERVIEW_LIST_ROW_EXTRA_PADDING
    );
    return this.buildLayoutState({
      layoutStyle: 'list',
      columnCount: 1,
      columnsTemplate: '1fr',
      gridGap: TAB_OVERVIEW_LIST_GAP,
      cardWidth: Math.max(1, usableWidth),
      previewHeight: rowHeight,
      identityHeaderHeight: 0,
      horizontalContentInset: 0,
      itemHeight: rowHeight
    });
  }

  private buildLayoutState(base: BrowserTabsOverviewLayoutBaseState): BrowserTabsOverviewLayoutState {
    const fallbackItemHeight = base.previewHeight + base.identityHeaderHeight +
      BROWSER_TABS_OVERVIEW_IDENTITY_PREVIEW_GAP;
    return {
      layoutStyle: base.layoutStyle,
      columnCount: base.columnCount,
      columnsTemplate: base.columnsTemplate,
      gridGap: base.gridGap,
      cardWidth: base.cardWidth,
      previewHeight: base.previewHeight,
      identityHeaderHeight: base.identityHeaderHeight,
      identityPreviewGap: BROWSER_TABS_OVERVIEW_IDENTITY_PREVIEW_GAP,
      itemHeight: base.itemHeight !== undefined && base.itemHeight > 0 ? base.itemHeight : fallbackItemHeight,
      horizontalContentInset: base.horizontalContentInset
    };
  }

  resolveTopPadding(topSafeInsetVp: number): number {
    return Math.max(TAB_OVERVIEW_LAYOUT_TOP_PADDING, topSafeInsetVp + TAB_OVERVIEW_LAYOUT_TOP_SAFE_GAP);
  }

  private resolveColumnCount(facts: AppWindowResponsiveFacts): number {
    if (facts.orientation === 'landscape' &&
      this.responsiveLayoutService.isAtLeastWidthClass(facts.widthClass, 'md')) {
      return 3;
    }
    if (this.responsiveLayoutService.isAtLeastWidthClass(facts.widthClass, 'lg')) {
      return 4;
    }
    return 2;
  }

  /**
   * Drop a column before a card is forced wider than its slot. Display-size scaling raises
   * density and shrinks the vp count; keeping two columns then overlaps the cards.
   */
  private resolveFittingColumnCount(facts: AppWindowResponsiveFacts, usableWidth: number): number {
    let columnCount = this.resolveColumnCount(facts);
    while (columnCount > 1 &&
      this.resolveFittedCardWidth(usableWidth, columnCount) < TAB_OVERVIEW_LAYOUT_MIN_CARD_WIDTH) {
      columnCount -= 1;
    }
    return columnCount;
  }

  private resolveUsableWidth(input: BrowserTabsOverviewLayoutInput): number {
    if (input.gridWidth > 0) {
      return input.gridWidth;
    }
    return Math.max(1, input.sheetWidth - 32);
  }

  private resolveFittedCardWidth(usableWidth: number, columnCount: number): number {
    const safeColumnCount = Math.max(1, columnCount);
    const totalGap = TAB_OVERVIEW_LAYOUT_GRID_GAP * Math.max(0, safeColumnCount - 1);
    return (Math.max(1, usableWidth) - totalGap) / safeColumnCount;
  }

  private resolveCardWidth(usableWidth: number, columnCount: number): number {
    return Math.max(1, this.resolveFittedCardWidth(usableWidth, columnCount));
  }

  private resolvePreviewHeight(input: BrowserTabsOverviewLayoutInput, cardWidth: number): number {
    const pageWidth = Math.max(1, input.sheetWidth);
    const pageHeight = Math.max(1, input.sheetHeight);
    // 卡片平铺不再按整页等比。高度是裁掉底部 1/3 之后的高度，图片顶边对齐，多出来的底部由卡片裁掉，
    // 不能把整张图压进这个更矮的框，否则页面会被压扁。
    const visibleFraction = 1 - BROWSER_TABS_OVERVIEW_GRID_BOTTOM_CROP_FRACTION;
    return Math.max(
      TAB_OVERVIEW_LAYOUT_MIN_PREVIEW_HEIGHT,
      Math.round(cardWidth * pageHeight / pageWidth * visibleFraction)
    );
  }

  private resolveHorizontalCardWidth(input: BrowserTabsOverviewLayoutInput, usableWidth: number): number {
    const landscape = input.sheetWidth > input.sheetHeight;
    const ratio = landscape ?
      TAB_OVERVIEW_HORIZONTAL_CARDS_LANDSCAPE_WIDTH_RATIO :
      TAB_OVERVIEW_HORIZONTAL_CARDS_PHONE_WIDTH_RATIO;
    return this.clampCardExtent(
      Math.max(1, usableWidth) * ratio,
      Math.min(TAB_OVERVIEW_HORIZONTAL_CARDS_MAX_WIDTH, Math.max(1, usableWidth))
    );
  }

  private resolveHorizontalPreviewHeight(
    input: BrowserTabsOverviewLayoutInput,
    headerHeight: number
  ): number {
    return this.clampCardExtent(
      Math.max(1, input.sheetHeight) * TAB_OVERVIEW_HORIZONTAL_CARDS_VIEWPORT_HEIGHT_RATIO,
      this.resolveSheetPreviewCap(input.sheetHeight, headerHeight)
    );
  }

  private resolveViewportAspectFrame(
    pageWidth: number,
    pageHeight: number,
    maxWidth: number,
    maxHeight: number
  ): BrowserTabsOverviewLayoutFrame {
    const safePageWidth = Math.max(1, pageWidth);
    const safePageHeight = Math.max(1, pageHeight);
    const scale = Math.min(
      Math.max(1, maxWidth) / safePageWidth,
      Math.max(1, maxHeight) / safePageHeight
    );
    return {
      width: Math.max(1, Math.round(safePageWidth * scale)),
      height: Math.max(1, Math.round(safePageHeight * scale))
    };
  }

  private resolveStackCardWidth(input: BrowserTabsOverviewLayoutInput, usableWidth: number): number {
    const landscape = input.sheetWidth > input.sheetHeight;
    const ratio = landscape ?
      TAB_OVERVIEW_STACK_LANDSCAPE_WIDTH_RATIO :
      TAB_OVERVIEW_STACK_PHONE_WIDTH_RATIO;
    return this.clampCardExtent(
      Math.max(1, usableWidth) * ratio,
      Math.min(TAB_OVERVIEW_STACK_MAX_WIDTH, Math.max(1, usableWidth))
    );
  }

  private resolveStackPreviewHeight(input: BrowserTabsOverviewLayoutInput, headerHeight: number): number {
    return this.clampCardExtent(
      Math.max(1, input.sheetHeight) * TAB_OVERVIEW_STACK_VIEWPORT_HEIGHT_RATIO,
      this.resolveSheetPreviewCap(input.sheetHeight, headerHeight)
    );
  }

  /**
   * Preferred size, never past the space the sheet still has. A hardcoded floor used to win here,
   * so raising display size made the card wider than the window.
   */
  private clampCardExtent(preferred: number, maximum: number): number {
    const cap = Math.max(1, maximum);
    return Math.round(Math.min(cap, Math.max(1, preferred)));
  }

  private resolveSheetPreviewCap(sheetHeight: number, headerHeight: number): number {
    return Math.max(
      1,
      Math.max(1, sheetHeight) - headerHeight - BROWSER_TABS_OVERVIEW_IDENTITY_PREVIEW_GAP -
        TAB_OVERVIEW_LAYOUT_SHEET_CHROME_RESERVE
    );
  }

  private resolveIdentityHeaderHeight(uiFontScale: number | undefined): number {
    const scale = this.normalizeUiFontScale(uiFontScale);
    // 14fp plus breathing room. At scale 1 this stays the existing 28vp header.
    return Math.max(
      BROWSER_TABS_OVERVIEW_IDENTITY_HEADER_HEIGHT,
      Math.round(BROWSER_TABS_OVERVIEW_IDENTITY_TITLE_FONT_SIZE * scale +
        BROWSER_TABS_OVERVIEW_IDENTITY_HEADER_HEIGHT - BROWSER_TABS_OVERVIEW_IDENTITY_TITLE_FONT_SIZE)
    );
  }

  private normalizeUiFontScale(uiFontScale: number | undefined): number {
    if (uiFontScale === undefined || !Number.isFinite(uiFontScale) || uiFontScale <= 1) {
      return 1;
    }
    return Math.min(BROWSER_TABS_OVERVIEW_IDENTITY_TITLE_MAX_FONT_SCALE, uiFontScale);
  }

  private normalizeLayoutStyle(
    style: BrowserTabsOverviewLayoutStyle | string | undefined
  ): BrowserTabsOverviewLayoutStyle {
    // Each of the four styles is its own value; anything else is the default, 卡片平铺.
    return style === 'horizontal_cards' || style === 'stack' || style === 'list' ? style : 'grid';
  }

  private buildColumnsTemplate(columnCount: number): string {
    const columns: string[] = [];
    for (let index = 0; index < Math.max(1, columnCount); index += 1) {
      columns.push('1fr');
    }
    return columns.join(' ');
  }

  private resolveResponsiveFacts(input: BrowserTabsOverviewLayoutInput): AppWindowResponsiveFacts {
    return this.responsiveLayoutService.resolve({
      viewportWidth: input.sheetWidth,
      viewportHeight: input.sheetHeight
    });
  }
}
