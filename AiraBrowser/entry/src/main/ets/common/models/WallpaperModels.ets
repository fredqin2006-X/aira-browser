import { BrowserHomepageBackdropAppearanceState } from './BackdropAppearanceModels';

export type WallpaperMode = 'auto' | 'theme' | 'solid' | 'bing' | 'custom';

// One list for both the sync writer and the snapshot validator. A second handwritten copy
// rejected `auto` and failed the whole personalization upload.
export const PORTABLE_WALLPAPER_MODES: string[] = ['auto', 'theme', 'solid', 'bing', 'custom'];

export function readPortableWallpaperMode(value: string | undefined): WallpaperMode | undefined {
  if (value === 'auto' || value === 'theme' || value === 'solid' || value === 'bing' || value === 'custom') {
    return value;
  }
  return undefined;
}

export type WallpaperAssetSource = 'bing' | 'custom' | 'builtin';

export type WallpaperAssetMediaType = 'image' | 'video';

export type HomeWallpaperPresentationKind = 'default' | 'auto' | 'solid' | 'image' | 'video';

export type HomeWallpaperForegroundTone = 'lightText' | 'darkText';

/**
 * One background the user can pick, in swatch order.
 *
 * `auto` is the black-and-white swatch: it paints white in light mode and black in dark mode,
 * so it needs no fixed color of its own. `solid` carries one color. `theme` follows the palette.
 */
export type HomeWallpaperChoiceKind = 'auto' | 'solid' | 'theme';

export interface HomeWallpaperChoice {
  id: string;
  label: string;
  kind: HomeWallpaperChoiceKind;
  /** Painted color for a solid choice; empty for auto and theme. */
  color: string;
  /** Text tone over a solid choice. Auto and theme take the theme's own tone instead. */
  foregroundTone: HomeWallpaperForegroundTone;
}

export const HOME_WALLPAPER_AUTO_CHOICE_ID: string = 'auto';
export const HOME_WALLPAPER_THEME_CHOICE_ID: string = 'theme';
/** The auto swatch stands for "whatever the current light or dark mode needs". */
export const HOME_WALLPAPER_AUTO_LIGHT_COLOR: string = '#FFFFFF';
export const HOME_WALLPAPER_AUTO_DARK_COLOR: string = '#000000';

export const HOME_WALLPAPER_CHOICES: HomeWallpaperChoice[] = [
  { id: HOME_WALLPAPER_AUTO_CHOICE_ID, label: '自动黑白', kind: 'auto', color: '', foregroundTone: 'darkText' },
  { id: 'mist', label: '雾蓝', kind: 'solid', color: '#E3EBF5', foregroundTone: 'darkText' },
  { id: 'sage', label: '浅绿', kind: 'solid', color: '#E6EFE7', foregroundTone: 'darkText' },
  { id: 'blush', label: '浅粉', kind: 'solid', color: '#F5E7EC', foregroundTone: 'darkText' }
];

/** The follow-the-theme swatch always closes the row. */
export const HOME_WALLPAPER_THEME_CHOICE: HomeWallpaperChoice = {
  id: HOME_WALLPAPER_THEME_CHOICE_ID,
  label: '跟随主题色',
  kind: 'theme',
  color: '',
  foregroundTone: 'darkText'
};

export function listHomeWallpaperChoices(): HomeWallpaperChoice[] {
  return HOME_WALLPAPER_CHOICES.concat([HOME_WALLPAPER_THEME_CHOICE]);
}

export function findHomeWallpaperChoice(id: string | undefined): HomeWallpaperChoice | undefined {
  const candidate = (id ?? '').trim();
  const choices = listHomeWallpaperChoices();
  for (let index = 0; index < choices.length; index += 1) {
    if (choices[index].id === candidate) {
      return choices[index];
    }
  }
  return undefined;
}

/** Only a flat color can be a `solidColorId`; auto and theme are modes of their own. */
export function normalizeHomeWallpaperSolidColorId(value: string | undefined): string {
  const candidate = findHomeWallpaperChoice(value);
  if (candidate !== undefined && candidate.kind === 'solid') {
    return candidate.id;
  }
  for (let index = 0; index < HOME_WALLPAPER_CHOICES.length; index += 1) {
    if (HOME_WALLPAPER_CHOICES[index].kind === 'solid') {
      return HOME_WALLPAPER_CHOICES[index].id;
    }
  }
  return '';
}

export function resolveHomeWallpaperAutoColor(darkMode: boolean): string {
  return darkMode ? HOME_WALLPAPER_AUTO_DARK_COLOR : HOME_WALLPAPER_AUTO_LIGHT_COLOR;
}

export const HOME_WALLPAPER_FOREGROUND_ALGORITHM_VERSION: number = 4;

export interface HomeWallpaperVisibleCropInput {
  viewportWidth: number;
  viewportHeight: number;
  maskOpacity: number;
}

export interface HomeWallpaperForegroundAnalysis {
  foregroundTone: HomeWallpaperForegroundTone;
  contentSignature: string;
  cropSignature: string;
  sampleSignature: string;
  algorithmVersion: number;
}

export interface WallpaperAsset {
  id: string;
  source: WallpaperAssetSource;
  mediaType: WallpaperAssetMediaType;
  originalPath: string;
  displayPath: string;
  thumbPath: string;
  contentSignature: string;
  foregroundTone: HomeWallpaperForegroundTone;
  foregroundToneContentSignature: string;
  foregroundToneCropSignature: string;
  foregroundToneSampleSignature: string;
  foregroundToneAlgorithmVersion: number;
  appearanceLight?: BrowserHomepageBackdropAppearanceState;
  appearanceDark?: BrowserHomepageBackdropAppearanceState;
  width: number;
  height: number;
  mimeType: string;
  byteSize: number;
  title: string;
  attribution: string;
  createdAt: number;
  updatedAt: number;
  isFavorite: boolean;
}

export interface WallpaperBingState {
  currentAssetId: string;
  market: string;
  lastRefreshDay: string;
  lastRefreshAt: number;
  manualRefreshAvailableAt: number;
  failureReason: string;
}

export interface WallpaperSettings {
  mode: WallpaperMode;
  solidColorId: string;
  bingWallpaperId: string;
  customWallpaperId: string;
  bing: WallpaperBingState;
  updatedAt: number;
}

export interface HomeWallpaperPresentationState {
  kind: HomeWallpaperPresentationKind;
  mode: WallpaperMode;
  foregroundTone: HomeWallpaperForegroundTone;
  imagePath: string;
  /** Sandbox video for a looping wallpaper. Empty unless kind is video. */
  videoPath: string;
  solidColor: string;
  maskOpacity: number;
  assetId: string;
  updatedAt: number;
}

export interface WallpaperRepositorySnapshot {
  settings: WallpaperSettings;
  assets: WallpaperAsset[];
}

export const DEFAULT_WALLPAPER_BING_STATE: WallpaperBingState = {
  currentAssetId: '',
  market: 'zh-CN',
  lastRefreshDay: '',
  lastRefreshAt: 0,
  manualRefreshAvailableAt: 0,
  failureReason: ''
};

export const DEFAULT_WALLPAPER_SETTINGS: WallpaperSettings = {
  // New installs follow the theme palette. Auto black/white stays a choice, not the start.
  mode: 'theme',
  solidColorId: normalizeHomeWallpaperSolidColorId('mist'),
  bingWallpaperId: '',
  customWallpaperId: '',
  bing: DEFAULT_WALLPAPER_BING_STATE,
  updatedAt: 0
};

export const DEFAULT_HOME_WALLPAPER_PRESENTATION_STATE: HomeWallpaperPresentationState = {
  kind: 'default',
  mode: DEFAULT_WALLPAPER_SETTINGS.mode,
  foregroundTone: 'darkText',
  imagePath: '',
  videoPath: '',
  solidColor: '',
  maskOpacity: 0,
  assetId: '',
  updatedAt: 0
};

export function cloneHomeWallpaperPresentationState(
  state: HomeWallpaperPresentationState
): HomeWallpaperPresentationState {
  return {
    kind: state.kind,
    mode: state.mode,
    foregroundTone: state.foregroundTone,
    imagePath: state.imagePath,
    videoPath: state.videoPath,
    solidColor: state.solidColor,
    maskOpacity: state.maskOpacity,
    assetId: state.assetId,
    updatedAt: state.updatedAt
  };
}

export function isSameHomeWallpaperPresentationState(
  left: HomeWallpaperPresentationState,
  right: HomeWallpaperPresentationState
): boolean {
  return left.kind === right.kind &&
    left.mode === right.mode &&
    left.foregroundTone === right.foregroundTone &&
    left.imagePath === right.imagePath &&
    left.videoPath === right.videoPath &&
    left.solidColor === right.solidColor &&
    left.maskOpacity === right.maskOpacity &&
    left.assetId === right.assetId &&
    left.updatedAt === right.updatedAt;
}

/**
 * A flat color, the auto black/white and a photo all paint the whole home edge to edge, so the
 * chrome clears over any of them. The theme-color home paints a color that already matches the
 * chrome instead.
 */
export function paintsHomeBackdrop(kind: HomeWallpaperPresentationKind): boolean {
  return kind !== 'default';
}

/**
 * A photo, a looping video or a chosen flat color says what its own text tone is. Auto takes the
 * theme's tone, because it is white in light mode and black in dark mode, exactly like the theme surface.
 */
export function usesOwnHomeForegroundTone(kind: HomeWallpaperPresentationKind): boolean {
  return kind === 'image' || kind === 'video' || kind === 'solid';
}
