import {
  BROWSER_TABS_OVERVIEW_CARD_CORNER_RADIUS,
  BROWSER_TABS_OVERVIEW_GRID_BOTTOM_CROP_FRACTION,
  BROWSER_TABS_OVERVIEW_LIST_ROW_CORNER_RADIUS
} from '../BrowserTabsOverviewVisualTokens';

export type BrowserTabsOverviewEntryLayoutStyle = 'grid' | 'horizontal_cards' | 'stack' | 'list';

/**
 * Where the shrinking page is painted.
 *
 * `above_cards` is one layer over the whole gallery. `deck` is a slot between two stack cards,
 * and that slot — not this profile — owns the draw order.
 */
export type BrowserTabsOverviewMorphHost = 'above_cards' | 'deck';

/**
 * How the page picture moves into the card.
 *
 * `scale` grows or shrinks the picture with the frame. `clip` keeps the page still and crops the
 * window down onto the row. The two must not share modifiers: a clip fade isolates the morph node,
 * and a card thumbnail then paints over a page that has not finished becoming a card.
 */
export type BrowserTabsOverviewSnapshotMotion = 'scale' | 'clip';

export interface BrowserTabsOverviewStyleEntryProfile {
  style: BrowserTabsOverviewEntryLayoutStyle;
  morphHost: BrowserTabsOverviewMorphHost;
  snapshotMotion: BrowserTabsOverviewSnapshotMotion;
  pinImageToSource: boolean;
  /**
   * Turns on the grid crop motion. 0 keeps the page aspect. Only 卡片平铺 is non-zero.
   * The motion also drops the top ninth; the fractions live with the layout tokens.
   */
  bottomCropFraction: number;
  cornerRadius: number;
  /**
   * List only. Fading the covering picture applies opacity to the morph node. That must stay
   * false for every card style.
   */
  fadesCoveringSnapshot: boolean;
  /** List only. A row surface fades in under the clip. Card styles have no such surface. */
  paintsEntrySurface: boolean;
}

/**
 * Each tab-overview style owns one closed entry profile.
 *
 * Shared morph code asks this policy and applies only the fields of the active profile. It does
 * not branch on the style name, so a list-only fade cannot be attached to the card shrink.
 */
export class BrowserTabsOverviewStyleEntryPolicy {
  resolve(style: string | undefined): BrowserTabsOverviewStyleEntryProfile {
    if (style === 'horizontal_cards') {
      return this.horizontalCardsProfile();
    }
    if (style === 'stack') {
      return this.stackProfile();
    }
    if (style === 'list') {
      return this.listProfile();
    }
    return this.gridProfile();
  }

  private gridProfile(): BrowserTabsOverviewStyleEntryProfile {
    return {
      style: 'grid',
      morphHost: 'above_cards',
      snapshotMotion: 'scale',
      pinImageToSource: false,
      bottomCropFraction: BROWSER_TABS_OVERVIEW_GRID_BOTTOM_CROP_FRACTION,
      cornerRadius: BROWSER_TABS_OVERVIEW_CARD_CORNER_RADIUS,
      fadesCoveringSnapshot: false,
      paintsEntrySurface: false
    };
  }

  private horizontalCardsProfile(): BrowserTabsOverviewStyleEntryProfile {
    return {
      style: 'horizontal_cards',
      morphHost: 'above_cards',
      snapshotMotion: 'scale',
      pinImageToSource: false,
      bottomCropFraction: 0,
      cornerRadius: BROWSER_TABS_OVERVIEW_CARD_CORNER_RADIUS,
      fadesCoveringSnapshot: false,
      paintsEntrySurface: false
    };
  }

  private stackProfile(): BrowserTabsOverviewStyleEntryProfile {
    return {
      style: 'stack',
      morphHost: 'deck',
      snapshotMotion: 'scale',
      pinImageToSource: false,
      bottomCropFraction: 0,
      cornerRadius: BROWSER_TABS_OVERVIEW_CARD_CORNER_RADIUS,
      fadesCoveringSnapshot: false,
      paintsEntrySurface: false
    };
  }

  private listProfile(): BrowserTabsOverviewStyleEntryProfile {
    return {
      style: 'list',
      morphHost: 'above_cards',
      snapshotMotion: 'clip',
      pinImageToSource: true,
      bottomCropFraction: 0,
      cornerRadius: BROWSER_TABS_OVERVIEW_LIST_ROW_CORNER_RADIUS,
      fadesCoveringSnapshot: true,
      paintsEntrySurface: true
    };
  }
}
