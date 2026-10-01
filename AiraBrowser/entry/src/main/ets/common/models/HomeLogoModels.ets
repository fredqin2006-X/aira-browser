/**
 * Homepage wordmark choice for the centered and minimal frames. Both frames share this catalog.
 *
 * Shipped ids are stable and are not the tile's position, so adding a logo cannot retarget a
 * choice the user already saved. A custom asset is an image the user added. Custom assets
 * accumulate: each one becomes a tile in the picker, and the add tile always stays last.
 */
export const HOME_LOGO_BUILTIN_ID: string = 'builtin';
export const HOME_LOGO_BUILTIN_RAWFILE: string = 'home_centered_wordmark.svg';
/** Custom ids carry this prefix so they can never collide with a shipped preset id. */
export const HOME_LOGO_CUSTOM_ASSET_ID_PREFIX: string = 'custom-';

/**
 * How a shipped logo takes color. This is a property of the artwork, not of the homepage style.
 *
 * `wallpaper` is a single-color SVG mask. Every fill is replaced with the homepage text tone,
 * the same tone the default wordmark uses, so the mark follows the wallpaper.
 * `authored` keeps the colors it was drawn with. fillColor would paint every shape one tone and
 * erase a multi-color illustration or an animation, so those logos are never recolored.
 * A file the user added is always authored: the gallery image is not a mask we can safely retint.
 */
export type HomeLogoColorMode = 'wallpaper' | 'authored';
/** A wordmark stays a wide mark. An icon is a shipped app icon, drawn as a rounded square. */
export type HomeLogoShape = 'wordmark' | 'icon';

export function homeLogoFollowsWallpaper(colorMode: HomeLogoColorMode): boolean {
  return colorMode === 'wallpaper';
}

interface HomeLogoPresetAsset {
  id: string;
  title: string;
  rawfileName: string;
  width: number;
  height: number;
  colorMode: HomeLogoColorMode;
  shape?: HomeLogoShape;
}

/**
 * Built-in artwork in picker order. Wordmark masks come first, then the one full-color wordmark,
 * then the animated banners. Only a single-fill SVG may be `wallpaper`; a gif or a multi-color
 * SVG must stay `authored`.
 */
const HOME_LOGO_PRESET_ASSETS: HomeLogoPresetAsset[] = [
  {
    id: HOME_LOGO_BUILTIN_ID,
    title: '默认',
    rawfileName: HOME_LOGO_BUILTIN_RAWFILE,
    width: 546,
    height: 163,
    colorMode: 'wallpaper'
  },
  {
    id: 'icon-classic',
    title: '经典',
    rawfileName: 'home_logo_icon_classic.png',
    width: 216,
    height: 216,
    colorMode: 'authored',
    shape: 'icon'
  },
  {
    id: 'icon-night',
    title: '夜色',
    rawfileName: 'home_logo_icon_night.png',
    width: 216,
    height: 216,
    colorMode: 'authored',
    shape: 'icon'
  },
  {
    id: 'icon-blue',
    title: '海蓝',
    rawfileName: 'home_logo_icon_blue.png',
    width: 1080,
    height: 1080,
    colorMode: 'authored',
    shape: 'icon'
  },
  {
    id: 'icon-color',
    title: '缤纷',
    rawfileName: 'home_logo_icon_color.png',
    width: 1080,
    height: 1080,
    colorMode: 'authored',
    shape: 'icon'
  },
  {
    id: 'icon-texture',
    title: '磨砂',
    rawfileName: 'home_logo_icon_texture.png',
    width: 1080,
    height: 1080,
    colorMode: 'authored',
    shape: 'icon'
  },
  {
    id: 'preset-pixel',
    title: '像素',
    rawfileName: 'home_logo_preset_pixel.svg',
    width: 692,
    height: 198,
    colorMode: 'wallpaper'
  },
  {
    id: 'preset-sharp',
    title: '锋芒',
    rawfileName: 'home_logo_preset_sharp.svg',
    width: 588,
    height: 418,
    colorMode: 'wallpaper'
  },
  {
    id: 'preset-round',
    title: '圆笔',
    rawfileName: 'home_logo_preset_round.svg',
    width: 715,
    height: 382,
    colorMode: 'wallpaper'
  },
  {
    id: 'preset-script',
    title: '签名',
    rawfileName: 'home_logo_preset_script.svg',
    width: 513,
    height: 301,
    colorMode: 'wallpaper'
  },
  {
    id: 'preset-confetti',
    title: '彩带',
    rawfileName: 'home_logo_preset_confetti.svg',
    width: 618,
    height: 366,
    colorMode: 'authored'
  },
  {
    id: 'preset-1',
    title: '父亲节',
    rawfileName: 'home_logo_preset_1.gif',
    width: 1000,
    height: 400,
    colorMode: 'authored'
  },
  {
    id: 'preset-2',
    title: '世界杯',
    rawfileName: 'home_logo_preset_2.gif',
    width: 1000,
    height: 400,
    colorMode: 'authored'
  },
  {
    id: 'preset-3',
    title: '德甲',
    rawfileName: 'home_logo_preset_3.gif',
    width: 1000,
    height: 400,
    colorMode: 'authored'
  }
];

export interface HomeLogoPreset {
  id: string;
  title: string;
  rawfileName: string;
  intrinsicWidth: number;
  intrinsicHeight: number;
  colorMode: HomeLogoColorMode;
  shape: HomeLogoShape;
}

/**
 * Where a custom logo comes from. The gallery only holds bitmaps, so an SVG or a file
 * outside the gallery has to come through the file picker.
 */
export type HomeLogoPickSource = 'photos' | 'files';

export interface HomeLogoCustomAsset {
  id: string;
  uri: string;
  /** Shown under the tile, so the user recognizes the file they picked. */
  fileName: string;
  width: number;
  height: number;
}

export interface HomeLogoSelection {
  id: string;
  customAssets: HomeLogoCustomAsset[];
}

export interface HomeLogoDisplaySource {
  rawfileName: string;
  fileUri: string;
  intrinsicWidth: number;
  intrinsicHeight: number;
  colorMode: HomeLogoColorMode;
  shape: HomeLogoShape;
}

export function listHomeLogoPresets(): HomeLogoPreset[] {
  const presets: HomeLogoPreset[] = [];
  for (let index = 0; index < HOME_LOGO_PRESET_ASSETS.length; index += 1) {
    const asset = HOME_LOGO_PRESET_ASSETS[index];
    presets.push({
      id: asset.id,
      title: asset.title,
      rawfileName: asset.rawfileName,
      intrinsicWidth: asset.width,
      intrinsicHeight: asset.height,
      colorMode: asset.colorMode,
      shape: asset.shape === 'icon' ? 'icon' : 'wordmark'
    });
  }
  return presets;
}

export function findHomeLogoPreset(id: string): HomeLogoPreset | undefined {
  const presets = listHomeLogoPresets();
  for (let index = 0; index < presets.length; index += 1) {
    if (presets[index].id === id) {
      return presets[index];
    }
  }
  return undefined;
}

export function buildHomeLogoCustomAssetId(nowMs: number): string {
  return `${HOME_LOGO_CUSTOM_ASSET_ID_PREFIX}${Math.max(0, Math.floor(nowMs))}`;
}

/** Last path segment of a uri, without its query or fragment. */
export function readHomeLogoFileNameFromUri(uri: string): string {
  const trimmed = uri.trim();
  if (trimmed.length === 0) {
    return '';
  }
  const withoutQuery = trimmed.split('?')[0].split('#')[0];
  const slash = withoutQuery.lastIndexOf('/');
  const fileName = slash >= 0 ? withoutQuery.substring(slash + 1) : withoutQuery;
  return fileName.trim();
}

/** Drops entries a picker could never show: a missing id, or no file behind it. */
export function normalizeHomeLogoCustomAssets(
  value: HomeLogoCustomAsset[] | undefined
): HomeLogoCustomAsset[] {
  const assets: HomeLogoCustomAsset[] = [];
  if (value === undefined) {
    return assets;
  }
  for (let index = 0; index < value.length; index += 1) {
    const asset: HomeLogoCustomAsset | undefined = value[index];
    if (asset === undefined) {
      continue;
    }
    const id = typeof asset.id === 'string' ? asset.id.trim() : '';
    const uri = typeof asset.uri === 'string' ? asset.uri.trim() : '';
    if (id.length === 0 || uri.length === 0) {
      continue;
    }
    const storedName = typeof asset.fileName === 'string' ? asset.fileName.trim() : '';
    assets.push({
      id: id,
      uri: uri,
      fileName: storedName.length > 0 ? storedName : readHomeLogoFileNameFromUri(uri),
      width: normalizeHomeLogoDimension(asset.width),
      height: normalizeHomeLogoDimension(asset.height)
    });
  }
  return assets;
}

export function findHomeLogoCustomAsset(
  assets: HomeLogoCustomAsset[],
  id: string
): HomeLogoCustomAsset | undefined {
  for (let index = 0; index < assets.length; index += 1) {
    if (assets[index].id === id) {
      return assets[index];
    }
  }
  return undefined;
}

export function normalizeHomeLogoId(value: string | undefined, assets: HomeLogoCustomAsset[]): string {
  const candidate = value ?? '';
  if (findHomeLogoPreset(candidate) !== undefined) {
    return candidate;
  }
  if (findHomeLogoCustomAsset(assets, candidate) !== undefined) {
    return candidate;
  }
  return HOME_LOGO_BUILTIN_ID;
}

export function normalizeHomeLogoSelection(selection: HomeLogoSelection | undefined): HomeLogoSelection {
  const customAssets = normalizeHomeLogoCustomAssets(selection?.customAssets);
  return {
    id: normalizeHomeLogoId(selection?.id, customAssets),
    customAssets: customAssets
  };
}

/**
 * Drops one imported logo. Selecting that logo falls back to the shipped wordmark.
 * A missing id returns undefined so the caller can refuse instead of rewriting the list.
 */
export function withoutHomeLogoCustomAsset(
  selection: HomeLogoSelection | undefined,
  id: string
): HomeLogoSelection | undefined {
  const normalized = normalizeHomeLogoSelection(selection);
  if (findHomeLogoCustomAsset(normalized.customAssets, id) === undefined) {
    return undefined;
  }
  const assets: HomeLogoCustomAsset[] = [];
  for (let index = 0; index < normalized.customAssets.length; index += 1) {
    if (normalized.customAssets[index].id !== id) {
      assets.push(normalized.customAssets[index]);
    }
  }
  return normalizeHomeLogoSelection({
    id: normalized.id === id ? HOME_LOGO_BUILTIN_ID : normalized.id,
    customAssets: assets
  });
}

export function resolveHomeLogoDisplaySource(selection: HomeLogoSelection | undefined): HomeLogoDisplaySource {
  const normalized = normalizeHomeLogoSelection(selection);
  const preset = findHomeLogoPreset(normalized.id);
  if (preset !== undefined) {
    return {
      rawfileName: preset.rawfileName,
      fileUri: '',
      intrinsicWidth: preset.intrinsicWidth,
      intrinsicHeight: preset.intrinsicHeight,
      colorMode: preset.colorMode,
      shape: preset.shape
    };
  }
  const asset = findHomeLogoCustomAsset(normalized.customAssets, normalized.id);
  if (asset !== undefined) {
    return {
      rawfileName: '',
      fileUri: asset.uri,
      intrinsicWidth: asset.width,
      intrinsicHeight: asset.height,
      colorMode: 'authored',
      shape: 'wordmark'
    };
  }
  const fallback = builtinHomeLogoPreset();
  return {
    rawfileName: fallback.rawfileName,
    fileUri: '',
    intrinsicWidth: fallback.intrinsicWidth,
    intrinsicHeight: fallback.intrinsicHeight,
    colorMode: fallback.colorMode,
    shape: fallback.shape
  };
}

export function resolveHomeLogoRowLabel(selection: HomeLogoSelection | undefined): string {
  const normalized = normalizeHomeLogoSelection(selection);
  const preset = findHomeLogoPreset(normalized.id);
  if (preset !== undefined) {
    return preset.title;
  }
  return findHomeLogoCustomAsset(normalized.customAssets, normalized.id) !== undefined ?
    '自定义' : builtinHomeLogoPreset().title;
}

function builtinHomeLogoPreset(): HomeLogoPreset {
  return listHomeLogoPresets()[0];
}

function normalizeHomeLogoDimension(value: number | undefined): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) {
    return 0;
  }
  return value;
}
