import {
  BrowserResolvedThemeMode,
  BrowserThemePaletteId
} from '../../common/models/BrowserModels';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';
import {
  BrowserActivityHeatmapTokenSet,
  BrowserSettingsIconBackgroundTokenSet,
  BrowserSyncProviderIconBackgroundTokenSet,
  BrowserThemePalette,
  BrowserThemeTokenSet,
  DEFAULT_BROWSER_ACTIVITY_HEATMAP_TOKENS,
  DEFAULT_BROWSER_SYNC_PROVIDER_ICON_BACKGROUND_TOKENS,
  DEFAULT_BROWSER_SETTINGS_ICON_BACKGROUND_TOKENS
} from '../../features/theme/BrowserThemePaletteModels';
import {
  BUILT_IN_THEME_PALETTES,
  DEFAULT_BROWSER_THEME_PALETTE_ID,
  findBrowserThemePalette
} from '../../features/theme/BrowserThemePalettes';
export interface ResolvedBrowserThemeTokens extends BrowserThemeTokenSet {
  paletteId: BrowserThemePaletteId;
  paletteTitle: string;
  mode: 'light' | 'dark';
}

export class BrowserThemePaletteService {
  listPalettes(): BrowserThemePalette[] {
    return BUILT_IN_THEME_PALETTES.map((palette: BrowserThemePalette) => this.clonePalette(palette));
  }

  resolvePalette(id: BrowserThemePaletteId): BrowserThemePalette {
    return this.clonePalette(findBrowserThemePalette(id));
  }

  resolvePaletteLabel(id: BrowserThemePaletteId): string {
    return this.resolvePalette(id).title;
  }

  resolveTokens(
    paletteId: BrowserThemePaletteId,
    mode: BrowserResolvedThemeMode
  ): ResolvedBrowserThemeTokens {
    const palette = this.resolvePalette(paletteId);
    const baseTokens = mode === 'dark' ? palette.dark : palette.light;
    const tokens = this.cloneTokenSet(baseTokens);
    return {
      accent: tokens.accent,
      onAccent: tokens.onAccent,
      onPrimary: tokens.onPrimary,
      settingsIconForeground: tokens.settingsIconForeground,
      settingsIconBackgrounds: this.cloneSettingsIconBackgroundTokens(tokens.settingsIconBackgrounds),
      syncProviderIconBackgrounds: this.cloneSyncProviderIconBackgroundTokens(tokens.syncProviderIconBackgrounds),
      activityHeatmap: this.cloneActivityHeatmapTokens(tokens.activityHeatmap),
      pageBackground: tokens.pageBackground,
      surfaceBackground: tokens.surfaceBackground,
      floatingSurface: tokens.floatingSurface,
      controlBackground: tokens.controlBackground,
      pressedBackground: tokens.pressedBackground,
      divider: tokens.divider,
      outline: tokens.outline,
      textPrimary: tokens.textPrimary,
      textSecondary: tokens.textSecondary,
      paletteId: palette.id,
      paletteTitle: palette.title,
      mode
    };
  }

  getDefaultPaletteId(): BrowserThemePaletteId {
    return DEFAULT_BROWSER_THEME_PALETTE_ID;
  }

  private clonePalette(palette: BrowserThemePalette): BrowserThemePalette {
    const copy = localizedThemePaletteCopy(palette.id);
    return {
      id: palette.id,
      title: copy === undefined ? palette.title : copy.title,
      subtitle: copy === undefined ? palette.subtitle : copy.subtitle,
      previewColor: palette.previewColor,
      light: this.cloneTokenSet(palette.light),
      dark: this.cloneTokenSet(palette.dark)
    };
  }

  private cloneTokenSet(tokens: BrowserThemeTokenSet): BrowserThemeTokenSet {
    return {
      accent: tokens.accent,
      onAccent: tokens.onAccent,
      onPrimary: tokens.onPrimary,
      settingsIconForeground: tokens.settingsIconForeground,
      settingsIconBackgrounds: this.cloneSettingsIconBackgroundTokens(tokens.settingsIconBackgrounds),
      syncProviderIconBackgrounds: this.cloneSyncProviderIconBackgroundTokens(tokens.syncProviderIconBackgrounds),
      activityHeatmap: this.cloneActivityHeatmapTokens(tokens.activityHeatmap),
      pageBackground: tokens.pageBackground,
      surfaceBackground: tokens.surfaceBackground,
      floatingSurface: tokens.floatingSurface,
      controlBackground: tokens.controlBackground,
      pressedBackground: tokens.pressedBackground,
      divider: tokens.divider,
      outline: tokens.outline,
      textPrimary: tokens.textPrimary,
      textSecondary: tokens.textSecondary
    };
  }

  private cloneSyncProviderIconBackgroundTokens(
    tokens: BrowserSyncProviderIconBackgroundTokenSet | undefined
  ): BrowserSyncProviderIconBackgroundTokenSet {
    const resolvedTokens = tokens ?? DEFAULT_BROWSER_SYNC_PROVIDER_ICON_BACKGROUND_TOKENS;
    return {
      cloud: resolvedTokens.cloud,
      webdav: resolvedTokens.webdav
    };
  }

  private cloneActivityHeatmapTokens(
    tokens: BrowserActivityHeatmapTokenSet | undefined
  ): BrowserActivityHeatmapTokenSet {
    const resolvedTokens = tokens ?? DEFAULT_BROWSER_ACTIVITY_HEATMAP_TOKENS;
    return {
      empty: resolvedTokens.empty,
      level1: resolvedTokens.level1,
      level2: resolvedTokens.level2,
      level3: resolvedTokens.level3,
      level4: resolvedTokens.level4,
      todayBorder: resolvedTokens.todayBorder
    };
  }

  private cloneSettingsIconBackgroundTokens(
    tokens: BrowserSettingsIconBackgroundTokenSet | undefined
  ): BrowserSettingsIconBackgroundTokenSet {
    const resolvedTokens = tokens ?? DEFAULT_BROWSER_SETTINGS_ICON_BACKGROUND_TOKENS;
    return {
      general: resolvedTokens.general,
      search: resolvedTokens.search,
      privacySecurity: resolvedTokens.privacySecurity,
      siteSettings: resolvedTokens.siteSettings,
      adBlocker: resolvedTokens.adBlocker,
      userScripts: resolvedTokens.userScripts,
      siteCustomization: resolvedTokens.siteCustomization,
      webpageTranslation: resolvedTokens.webpageTranslation,
      passwords: resolvedTokens.passwords,
      downloads: resolvedTokens.downloads,
      userAgent: resolvedTokens.userAgent,
      appearance: resolvedTokens.appearance,
      experiments: resolvedTokens.experiments,
      sync: resolvedTokens.sync,
      about: resolvedTokens.about,
      crossDeviceLink: resolvedTokens.crossDeviceLink,
      customHomepage: resolvedTokens.customHomepage,
      toolbar: resolvedTokens.toolbar,
      privateMode: resolvedTokens.privateMode,
      webFeatures: resolvedTokens.webFeatures,
      webApps: resolvedTokens.webApps,
      advancedSettings: resolvedTokens.advancedSettings,
      bookmarks: resolvedTokens.bookmarks,
      history: resolvedTokens.history,
      homeShortcuts: resolvedTokens.homeShortcuts,
      activityHeatmap: resolvedTokens.activityHeatmap,
      novelBookshelf: resolvedTokens.novelBookshelf,
      syncMethod: resolvedTokens.syncMethod,
      syncPageCrossDevice: resolvedTokens.syncPageCrossDevice,
      syncPageAdvanced: resolvedTokens.syncPageAdvanced,
      backupFrequency: resolvedTokens.backupFrequency,
      backupLocation: resolvedTokens.backupLocation,
      addDevice: resolvedTokens.addDevice,
      siteLocation: resolvedTokens.siteLocation,
      siteMicrophone: resolvedTokens.siteMicrophone,
      siteClipboard: resolvedTokens.siteClipboard,
      siteExternalActions: resolvedTokens.siteExternalActions
    };
  }
}

interface LocalizedThemePaletteCopy {
  title: string;
  subtitle: string;
}

function themePaletteText(resource: Resource, fallback: string): string {
  const resolved = resolveAppResourceText(resource);
  return resolved.length > 0 ? resolved : fallback;
}

function localizedThemePaletteCopy(id: string): LocalizedThemePaletteCopy | undefined {
  switch (id) {
    case 'default':
      return {
        title: themePaletteText($r('app.string.web_text_zoom_default'), '默认'),
        subtitle: themePaletteText($r('app.string.theme_palette_default_subtitle'), '蓝色主调，中性灰阶')
      };
    case 'aira_classic':
      return {
        title: themePaletteText($r('app.string.theme_palette_dawn_title'), '晨光'),
        subtitle: themePaletteText($r('app.string.theme_palette_dawn_subtitle'), '蓝紫晨光')
      };
    case 'aira_origin':
      return {
        title: themePaletteText($r('app.string.theme_palette_lead_title'), '铅云'),
        subtitle: themePaletteText($r('app.string.theme_palette_lead_subtitle'), '中性灰阶')
      };
    case 'aurora':
      return {
        title: themePaletteText($r('app.string.theme_palette_aurora_title'), '晨屿'),
        subtitle: themePaletteText($r('app.string.theme_palette_aurora_subtitle'), '海雾青光')
      };
    case 'sage':
      return {
        title: themePaletteText($r('app.string.theme_palette_sage_title'), '竹影'),
        subtitle: themePaletteText($r('app.string.theme_palette_sage_subtitle'), '静绿灰调')
      };
    case 'cedar':
      return {
        title: themePaletteText($r('app.string.theme_palette_cedar_title'), '森息'),
        subtitle: themePaletteText($r('app.string.theme_palette_cedar_subtitle'), '深林呼吸')
      };
    case 'lagoon':
      return {
        title: themePaletteText($r('app.string.theme_palette_lagoon_title'), '潮镜'),
        subtitle: themePaletteText($r('app.string.theme_palette_lagoon_subtitle'), '温蓝水面')
      };
    case 'glacier':
      return {
        title: themePaletteText($r('app.string.theme_palette_glacier_title'), '薄霁'),
        subtitle: themePaletteText($r('app.string.theme_palette_glacier_subtitle'), '浅蓝晴空')
      };
    case 'indigo':
      return {
        title: themePaletteText($r('app.string.theme_palette_indigo_title'), '夜航'),
        subtitle: themePaletteText($r('app.string.theme_palette_indigo_subtitle'), '蓝紫航线')
      };
    case 'wisteria':
      return {
        title: themePaletteText($r('app.string.theme_palette_wisteria_title'), '云藤'),
        subtitle: themePaletteText($r('app.string.theme_palette_wisteria_subtitle'), '柔紫云隙')
      };
    case 'rosewood':
      return {
        title: themePaletteText($r('app.string.theme_palette_rosewood_title'), '绯页'),
        subtitle: themePaletteText($r('app.string.theme_palette_rosewood_subtitle'), '低饱和红')
      };
    case 'terracotta':
      return {
        title: themePaletteText($r('app.string.theme_palette_terracotta_title'), '暖砖'),
        subtitle: themePaletteText($r('app.string.theme_palette_terracotta_subtitle'), '红棕余温')
      };
    case 'amber':
      return {
        title: themePaletteText($r('app.string.theme_palette_amber_title'), '灯穗'),
        subtitle: themePaletteText($r('app.string.theme_palette_amber_subtitle'), '金色暖影')
      };
    case 'moss':
      return {
        title: themePaletteText($r('app.string.theme_palette_moss_title'), '苔径'),
        subtitle: themePaletteText($r('app.string.theme_palette_moss_subtitle'), '橄榄小路')
      };
    case 'cyan':
      return {
        title: themePaletteText($r('app.string.theme_palette_cyan_title'), '晴瓷'),
        subtitle: themePaletteText($r('app.string.theme_palette_cyan_subtitle'), '清透青蓝')
      };
    case 'steel':
      return {
        title: themePaletteText($r('app.string.theme_palette_steel_title'), '雾钢'),
        subtitle: themePaletteText($r('app.string.theme_palette_steel_subtitle'), '理性灰蓝')
      };
    case 'plum':
      return {
        title: themePaletteText($r('app.string.theme_palette_plum_title'), '暮梅'),
        subtitle: themePaletteText($r('app.string.theme_palette_plum_subtitle'), '深紫红晕')
      };
    case 'coral':
      return {
        title: themePaletteText($r('app.string.theme_palette_coral_title'), '橙潮'),
        subtitle: themePaletteText($r('app.string.theme_palette_coral_subtitle'), '柔亮橙粉')
      };
    default:
      return undefined;
  }
}
