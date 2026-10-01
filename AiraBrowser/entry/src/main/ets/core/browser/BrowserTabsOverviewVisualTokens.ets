export const BROWSER_TABS_OVERVIEW_CARD_CORNER_RADIUS: number = 26;
/**
 * 卡片平铺只留中间那一截。底部 1/3 是页面下半截，顶部 1/9 基本是安全区或地址栏，对认标签没用。
 * 横向大卡片和堆叠式不走这条，它们仍按页面自己的比例。
 */
export const BROWSER_TABS_OVERVIEW_GRID_BOTTOM_CROP_FRACTION: number = 1 / 3;
export const BROWSER_TABS_OVERVIEW_GRID_TOP_CROP_FRACTION: number = 1 / 9;
export const BROWSER_TABS_OVERVIEW_LIST_ROW_CORNER_RADIUS: number = 14;
export const BROWSER_TABS_OVERVIEW_IDENTITY_HEADER_HEIGHT: number = 28;
export const BROWSER_TABS_OVERVIEW_IDENTITY_ICON_SIZE: number = 20;
export const BROWSER_TABS_OVERVIEW_IDENTITY_ICON_TEXT_GAP: number = 6;
export const BROWSER_TABS_OVERVIEW_IDENTITY_HORIZONTAL_INSET: number = 10;
export const BROWSER_TABS_OVERVIEW_IDENTITY_PREVIEW_GAP: number = 6;
export const BROWSER_TABS_OVERVIEW_IDENTITY_TITLE_FONT_SIZE: number = 14;
/**
 * Cap for the card title. The system font scale follows the user up to 3.2, which turns a 14fp
 * title into a handful of characters on a two-column card. 1.75 is the aging-adaptation ceiling
 * for compact chrome, and the header height grows to match it.
 */
export const BROWSER_TABS_OVERVIEW_IDENTITY_TITLE_MAX_FONT_SCALE: number = 1.75;
export const BROWSER_TABS_OVERVIEW_IDENTITY_MORPH_OFFSET_Y: number = 6;
export const BROWSER_TABS_OVERVIEW_IDENTITY_ICON_REVEAL_DURATION_MS: number = 120;
