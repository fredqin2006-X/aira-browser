import { CENTERED_HOME_WORDMARK_HEIGHT } from '../../features/newtab/CenteredHomeShortcutLayoutPolicy';
import {
  HomeLogoColorMode,
  HomeLogoSelection,
  HomeLogoShape,
  listHomeLogoPresets,
  normalizeHomeLogoSelection,
  resolveHomeLogoRowLabel
} from '../../common/models/HomeLogoModels';

/**
 * The mark above the search field keeps this height. Width follows the image
 * ratio, and only stops at the space the header actually has.
 */
export const HOME_LOGO_DISPLAY_HEIGHT_VP: number = CENTERED_HOME_WORDMARK_HEIGHT;
/**
 * The slider range. 100% is the shipped wordmark height; the cap stops a logo from swallowing
 * the home, and the rendered width is still clamped to the space the header actually has.
 */
export const HOME_LOGO_SCALE_MIN_RATIO: number = 0.6;
export const HOME_LOGO_SCALE_MAX_RATIO: number = 2;
export const HOME_LOGO_SCALE_DEFAULT_RATIO: number = 1;
export const HOME_LOGO_SCALE_SLIDER_STEP: number = 1;
/** 0 hides the mark; 1 is the shipped solid wordmark. */
export const HOME_LOGO_OPACITY_MIN: number = 0;
export const HOME_LOGO_OPACITY_MAX: number = 1;
export const HOME_LOGO_OPACITY_DEFAULT: number = 1;
export const HOME_LOGO_OPACITY_SLIDER_STEP: number = 1;
export const HOME_LOGO_PREVIEW_HEIGHT_VP: number = 40;
/** Share of the drawn side. Matches a rounded app icon, not a circle. */
export const HOME_LOGO_ICON_CORNER_RATIO: number = 0.22;
export const HOME_LOGO_GRID_GAP_VP: number = 12;
/** The trailing "add" tile is only a picker affordance, never a selectable logo. */
export const HOME_LOGO_ADD_ITEM_ID: string = 'add';
export const HOME_LOGO_MAX_CUSTOM_ASSETS: number = 12;
const HOME_LOGO_GRID_THREE_COLUMN_MIN_WIDTH_VP: number = 440;
const HOME_LOGO_GRID_FOUR_COLUMN_MIN_WIDTH_VP: number = 680;

export type HomeLogoGridItemKind = 'preset' | 'custom' | 'add';

export interface HomeLogoGridItem {
  id: string;
  kind: HomeLogoGridItemKind;
  title: string;
  rawfileName: string;
  fileUri: string;
  intrinsicWidth: number;
  intrinsicHeight: number;
  colorMode: HomeLogoColorMode;
  shape: HomeLogoShape;
  selected: boolean;
}

export interface HomeLogoGridRow {
  key: string;
  items: HomeLogoGridItem[];
  placeholderCount: number;
}

export interface HomeLogoSettingsViewState {
  selectedId: string;
  rowLabel: string;
  columns: number;
  columnGap: number;
  items: HomeLogoGridItem[];
}

export function resolveHomeLogoGridColumns(containerWidth: number): number {
  const width = Number.isFinite(containerWidth) ? containerWidth : 0;
  if (width >= HOME_LOGO_GRID_FOUR_COLUMN_MIN_WIDTH_VP) {
    return 4;
  }
  if (width >= HOME_LOGO_GRID_THREE_COLUMN_MIN_WIDTH_VP) {
    return 3;
  }
  return 2;
}

/** Keeps the stored ratio inside the slider range so a stale value cannot paint an absurd logo. */
export function normalizeHomeLogoScaleRatio(value: number | undefined): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return HOME_LOGO_SCALE_DEFAULT_RATIO;
  }
  return Math.max(
    HOME_LOGO_SCALE_MIN_RATIO,
    Math.min(HOME_LOGO_SCALE_MAX_RATIO, Math.round(value * 100) / 100)
  );
}

export function homeLogoScaleToSliderValue(ratio: number): number {
  return Math.round(normalizeHomeLogoScaleRatio(ratio) * 100);
}

export function homeLogoSliderValueToScale(value: number): number {
  return normalizeHomeLogoScaleRatio(value / 100);
}

export function formatHomeLogoScaleLabel(ratio: number): string {
  return `${homeLogoScaleToSliderValue(ratio)}%`;
}

/** Keeps a missing or stale value solid, and lets 0 stay hidden. */
export function normalizeHomeLogoOpacity(value: number | undefined): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return HOME_LOGO_OPACITY_DEFAULT;
  }
  const clamped = Math.max(HOME_LOGO_OPACITY_MIN, Math.min(HOME_LOGO_OPACITY_MAX, value));
  return Math.round(clamped * 100) / 100;
}

export function homeLogoOpacityToSliderValue(opacity: number): number {
  return Math.round(normalizeHomeLogoOpacity(opacity) * 100);
}

export function homeLogoSliderValueToOpacity(value: number): number {
  return normalizeHomeLogoOpacity(value / 100);
}

export function formatHomeLogoOpacityLabel(opacity: number): string {
  return `${homeLogoOpacityToSliderValue(opacity)}%`;
}

/** The height the logo is actually drawn at, before the width clamp has its say. */
export function resolveHomeLogoHeightVp(baseHeightVp: number, scaleRatio: number): number {
  const base = baseHeightVp > 0 ? baseHeightVp : HOME_LOGO_DISPLAY_HEIGHT_VP;
  return Math.max(1, Math.round(base * normalizeHomeLogoScaleRatio(scaleRatio)));
}

/**
 * Fixed height, free width. A very wide image is capped at the available width
 * so it cannot run off the screen; the box height stays the fixed height.
 */
export function resolveHomeLogoDisplayWidthVp(
  intrinsicWidth: number,
  intrinsicHeight: number,
  heightVp: number,
  maxWidthVp: number
): number {
  const height = heightVp > 0 ? heightVp : HOME_LOGO_DISPLAY_HEIGHT_VP;
  const sourceWidth = intrinsicWidth > 0 ? intrinsicWidth : height;
  const sourceHeight = intrinsicHeight > 0 ? intrinsicHeight : height;
  const natural = height * (sourceWidth / sourceHeight);
  if (!Number.isFinite(natural) || natural <= 0) {
    return height;
  }
  if (maxWidthVp > 0 && natural > maxWidthVp) {
    return maxWidthVp;
  }
  return natural;
}

/** Wordmarks stay square-cornered. An app icon takes a rounded-rect mask of its own height. */
export function resolveHomeLogoCornerRadiusVp(heightVp: number, shape: HomeLogoShape): number {
  if (shape !== 'icon' || !(heightVp > 0)) {
    return 0;
  }
  return Math.max(1, Math.round(heightVp * HOME_LOGO_ICON_CORNER_RATIO));
}

export function resolveHomeLogoPreviewMaxWidthVp(
  containerWidth: number,
  columns: number,
  gap: number
): number {
  const columnCount = resolveGridColumnCount(columns);
  const content = Number.isFinite(containerWidth) && containerWidth > 0 ? containerWidth : 1;
  const cardWidth = (content - gap * (columnCount - 1)) / columnCount;
  return Math.max(48, cardWidth - 28);
}

/**
 * Tiles in reading order: the shipped presets, then every custom asset the user added,
 * then one trailing add tile. The add tile stays last however many assets exist.
 */
export function buildHomeLogoGridItems(selection: HomeLogoSelection | undefined): HomeLogoGridItem[] {
  const normalized = normalizeHomeLogoSelection(selection);
  const items: HomeLogoGridItem[] = [];
  const presets = listHomeLogoPresets();
  for (let index = 0; index < presets.length; index += 1) {
    const preset = presets[index];
    items.push({
      id: preset.id,
      kind: 'preset',
      title: preset.title,
      rawfileName: preset.rawfileName,
      fileUri: '',
      intrinsicWidth: preset.intrinsicWidth,
      intrinsicHeight: preset.intrinsicHeight,
      colorMode: preset.colorMode,
      shape: preset.shape,
      selected: preset.id === normalized.id
    });
  }
  for (let index = 0; index < normalized.customAssets.length; index += 1) {
    const asset = normalized.customAssets[index];
    items.push({
      id: asset.id,
      kind: 'custom',
      title: asset.fileName.length > 0 ? asset.fileName : '自定义',
      rawfileName: '',
      fileUri: asset.uri,
      intrinsicWidth: asset.width,
      intrinsicHeight: asset.height,
      colorMode: 'authored',
      shape: 'wordmark',
      selected: asset.id === normalized.id
    });
  }
  items.push({
    id: HOME_LOGO_ADD_ITEM_ID,
    kind: 'add',
    title: '',
    rawfileName: '',
    fileUri: '',
    intrinsicWidth: 0,
    intrinsicHeight: 0,
    colorMode: 'authored',
    shape: 'wordmark',
    selected: false
  });
  return items;
}

export function buildHomeLogoGridRows(
  items: HomeLogoGridItem[],
  columns: number
): HomeLogoGridRow[] {
  const columnCount = resolveGridColumnCount(columns);
  const rows: HomeLogoGridRow[] = [];
  for (let index = 0; index < items.length; index += columnCount) {
    const rowItems: HomeLogoGridItem[] = [];
    const end = Math.min(items.length, index + columnCount);
    for (let itemIndex = index; itemIndex < end; itemIndex += 1) {
      rowItems.push(items[itemIndex]);
    }
    rows.push({
      key: buildHomeLogoGridRowKey(rowItems, index),
      items: rowItems,
      placeholderCount: columnCount - rowItems.length
    });
  }
  return rows;
}

export function buildHomeLogoSettingsViewState(
  selection: HomeLogoSelection | undefined,
  containerWidth: number
): HomeLogoSettingsViewState {
  const normalized = normalizeHomeLogoSelection(selection);
  return {
    selectedId: normalized.id,
    rowLabel: resolveHomeLogoRowLabel(normalized),
    columns: resolveHomeLogoGridColumns(containerWidth),
    columnGap: HOME_LOGO_GRID_GAP_VP,
    items: buildHomeLogoGridItems(normalized)
  };
}

function resolveGridColumnCount(columns: number): number {
  if (columns >= 4) {
    return 4;
  }
  return columns === 3 ? 3 : 2;
}

/**
 * The key carries each tile's selected flag. ForEach reuses a node whose key did not change,
 * so without the flag the grid keeps the old row and the selection border never moves.
 */
function buildHomeLogoGridRowKey(items: HomeLogoGridItem[], index: number): string {
  let key = `${index}`;
  for (let itemIndex = 0; itemIndex < items.length; itemIndex += 1) {
    const item = items[itemIndex];
    key = `${key}-${item.kind}:${item.id}:${item.selected ? '1' : '0'}`;
  }
  return key;
}
