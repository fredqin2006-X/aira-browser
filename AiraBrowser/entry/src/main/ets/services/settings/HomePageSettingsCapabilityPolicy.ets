import { resolveAppResourceText } from '../../core/resources/AppResourceText';
import { BrowserHomePageStyle } from '../../common/models/HomePagePresentationSettingsModels';
import { HomePageRecoveryEntry } from './HomePageRecoveryEntryPolicyService';

/**
 * Which homepage-settings controls a frame actually honors.
 *
 * Classic owns the full sheet. Centered keeps only controls that change that frame:
 * logo, wallpaper, favorites visibility, icon names, and icon size. Minimal keeps the centered
 * wordmark and search field but has no shortcut grid, so only logo and wallpaper remain.
 * Compact layout, section titles, icon radius, recently closed, system search, and the
 * settings button are classic-only.
 *
 * Centered and minimal open this sheet from the wordmark above the search field, so neither
 * frame has a stored settings-button toggle. `settingsButton` stays false there.
 */
export interface HomePageSettingsCapabilities {
  logo: boolean;
  wallpaper: boolean;
  favorites: boolean;
  compactFavorites: boolean;
  favoritesTitle: boolean;
  shortcutNames: boolean;
  iconSize: boolean;
  iconCornerRadius: boolean;
  recentlyClosed: boolean;
  systemSearch: boolean;
  settingsButton: boolean;
}

export function resolveHomePageSettingsCapabilities(
  style: BrowserHomePageStyle
): HomePageSettingsCapabilities {
  if (style === 'minimal') {
    return {
      logo: true,
      wallpaper: true,
      favorites: false,
      compactFavorites: false,
      favoritesTitle: false,
      shortcutNames: false,
      iconSize: false,
      iconCornerRadius: false,
      recentlyClosed: false,
      systemSearch: false,
      settingsButton: false
    };
  }
  if (style === 'centered') {
    return {
      logo: true,
      wallpaper: true,
      favorites: true,
      compactFavorites: false,
      favoritesTitle: false,
      shortcutNames: true,
      iconSize: true,
      iconCornerRadius: false,
      recentlyClosed: false,
      systemSearch: false,
      settingsButton: false
    };
  }
  return {
    logo: false,
    wallpaper: true,
    favorites: true,
    compactFavorites: true,
    favoritesTitle: true,
    shortcutNames: true,
    iconSize: true,
    iconCornerRadius: true,
    recentlyClosed: true,
    systemSearch: true,
    settingsButton: true
  };
}

/**
 * Entries that can still open homepage settings on the active frame.
 *
 * The classic frame must keep at least one of favorites, recently closed, or its settings button.
 * Centered and minimal always open the sheet from the wordmark, so neither frame rewrites the
 * stored classic flags.
 */
export function resolveHomePageRecoveryEntries(style: BrowserHomePageStyle): HomePageRecoveryEntry[] {
  if (style === 'centered' || style === 'minimal') {
    return [];
  }
  return ['favorites', 'recently_closed', 'settings_button'];
}

export function resolveHomePageSettingsRecoveryFooter(style: BrowserHomePageStyle): string {
  if (style === 'centered' || style === 'minimal') {
    return '';
  }
  return homeSettingsText(
    $r('app.string.home_settings_keep_one'),
    '收藏、最近关闭和主页设置按钮至少保留一项。'
  );
}

function homeSettingsText(resource: Resource, fallback: string): string {
  const resolved = resolveAppResourceText(resource);
  return resolved.length > 0 ? resolved : fallback;
}
