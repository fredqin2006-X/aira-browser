import {
  BrowserResolvedThemeMode,
  BrowserTabsOverviewLayoutStyle,
  BrowserThemeMode,
  BrowserThemePaletteId
} from '../../common/models/BrowserModels';
import { BrowserThemePaletteService } from '../../services/theme/BrowserThemePaletteService';
import { resolveAppResourceText } from '../resources/AppResourceText';
import { TabOverviewLayoutOptionState } from '../settings/TabOverviewLayoutSettingsCoordinator';

const FEATURE_INTRO_APPEARANCE_TITLE: string = '选择外观';
const FEATURE_INTRO_APPEARANCE_SUBTITLE: string = '主题色和标签页样式之后也可以在设置里更改。';
const FEATURE_INTRO_APPEARANCE_THEME_SECTION: string = '主题色';
const FEATURE_INTRO_APPEARANCE_TAB_SECTION: string = '标签页样式';
const FEATURE_INTRO_APPEARANCE_CONTINUE_LABEL: string = '下一步';
const FEATURE_INTRO_APPEARANCE_PREVIOUS_LABEL: string = '上一步';
const FEATURE_INTRO_APPEARANCE_SKIP_LABEL: string = '跳过';
const FEATURE_INTRO_APPEARANCE_DEFAULT_PALETTE: BrowserThemePaletteId = 'default';
const FEATURE_INTRO_APPEARANCE_DEFAULT_TAB_STYLE: BrowserTabsOverviewLayoutStyle = 'grid';
const FEATURE_INTRO_APPEARANCE_PALETTE_IDS: BrowserThemePaletteId[] = [
  'default',
  'aurora',
  'cedar',
  'indigo',
  'amber',
  'coral'
];

export interface FeatureIntroAppearancePaletteChoice {
  id: BrowserThemePaletteId;
  title: string;
  previewColor: string;
  isSelected: boolean;
}

export interface FeatureIntroAppearanceThemeModeChoice {
  mode: BrowserThemeMode;
  title: string;
  isSelected: boolean;
}

export interface FeatureIntroAppearancePreviewTokens {
  accent: string;
  onAccent: string;
  pageBackground: string;
  surfaceBackground: string;
  textPrimary: string;
  textSecondary: string;
}

export function resolveFeatureIntroAppearancePalette(value: string): BrowserThemePaletteId {
  if (value === 'aurora' || value === 'cedar' || value === 'indigo' || value === 'amber' || value === 'coral') {
    return value;
  }
  return FEATURE_INTRO_APPEARANCE_DEFAULT_PALETTE;
}

export function resolveFeatureIntroAppearanceThemeMode(value: string): BrowserThemeMode {
  if (value === 'light' || value === 'dark') {
    return value;
  }
  return 'system';
}

export function resolveFeatureIntroAppearanceTabStyle(value: string): BrowserTabsOverviewLayoutStyle {
  return value === 'horizontal_cards' || value === 'stack' || value === 'list' ?
    value : FEATURE_INTRO_APPEARANCE_DEFAULT_TAB_STYLE;
}

/** PC keeps a top tab strip or a side tab strip. It does not use the phone overview styles. */
export type FeatureIntroDesktopTabPlacement = 'horizontal' | 'vertical';

export interface FeatureIntroDesktopTabChoice {
  placement: FeatureIntroDesktopTabPlacement;
  title: string;
  isSelected: boolean;
}

const FEATURE_INTRO_DESKTOP_TAB_PLACEMENT_DEFAULT: FeatureIntroDesktopTabPlacement = 'horizontal';

export function resolveFeatureIntroDesktopTabPlacement(value: string): FeatureIntroDesktopTabPlacement {
  return value === 'vertical' ? 'vertical' : FEATURE_INTRO_DESKTOP_TAB_PLACEMENT_DEFAULT;
}

export class FeatureIntroAppearanceViewModel {
  private readonly paletteService: BrowserThemePaletteService = new BrowserThemePaletteService();

  title(): string {
    return featureIntroText($r('app.string.feature_intro_appearance_title'), FEATURE_INTRO_APPEARANCE_TITLE);
  }

  subtitle(): string {
    return featureIntroText($r('app.string.feature_intro_appearance_subtitle'), FEATURE_INTRO_APPEARANCE_SUBTITLE);
  }

  themeSectionTitle(): string {
    return featureIntroText($r('app.string.settings_appearance_theme_color'), FEATURE_INTRO_APPEARANCE_THEME_SECTION);
  }

  tabSectionTitle(): string {
    return featureIntroText($r('app.string.settings_appearance_tab_style'), FEATURE_INTRO_APPEARANCE_TAB_SECTION);
  }

  continueLabel(): string {
    return featureIntroText($r('app.string.settings_sync_next'), FEATURE_INTRO_APPEARANCE_CONTINUE_LABEL);
  }

  previousLabel(): string {
    return featureIntroText($r('app.string.feature_intro_previous'), FEATURE_INTRO_APPEARANCE_PREVIOUS_LABEL);
  }

  skipLabel(): string {
    return featureIntroText($r('app.string.onboarding_ui_feature_intro_skip_control_001'), FEATURE_INTRO_APPEARANCE_SKIP_LABEL);
  }

  defaultPaletteId(): BrowserThemePaletteId {
    return FEATURE_INTRO_APPEARANCE_DEFAULT_PALETTE;
  }

  defaultTabStyle(): BrowserTabsOverviewLayoutStyle {
    return FEATURE_INTRO_APPEARANCE_DEFAULT_TAB_STYLE;
  }

  defaultDesktopTabPlacement(): FeatureIntroDesktopTabPlacement {
    return FEATURE_INTRO_DESKTOP_TAB_PLACEMENT_DEFAULT;
  }

  previewTokens(paletteId: string, mode: string): FeatureIntroAppearancePreviewTokens {
    const resolvedMode: BrowserResolvedThemeMode = mode === 'dark' ? 'dark' : 'light';
    const tokens = this.paletteService.resolveTokens(resolveFeatureIntroAppearancePalette(paletteId), resolvedMode);
    return {
      accent: tokens.accent,
      onAccent: tokens.onAccent,
      pageBackground: tokens.pageBackground,
      surfaceBackground: tokens.surfaceBackground,
      textPrimary: tokens.textPrimary,
      textSecondary: tokens.textSecondary
    };
  }

  themeModes(selectedMode: string): FeatureIntroAppearanceThemeModeChoice[] {
    const selected = resolveFeatureIntroAppearanceThemeMode(selectedMode);
    return [
      {
        mode: 'dark',
        title: featureIntroText($r('app.string.settings_appearance_dark'), '深色'),
        isSelected: selected === 'dark'
      },
      {
        mode: 'light',
        title: featureIntroText($r('app.string.settings_appearance_light'), '浅色'),
        isSelected: selected === 'light'
      },
      {
        mode: 'system',
        title: featureIntroText($r('app.string.settings_general_system'), '系统'),
        isSelected: selected === 'system'
      }
    ];
  }

  palettes(selectedId: string): FeatureIntroAppearancePaletteChoice[] {
    const selected = resolveFeatureIntroAppearancePalette(selectedId);
    return FEATURE_INTRO_APPEARANCE_PALETTE_IDS.map((id: BrowserThemePaletteId): FeatureIntroAppearancePaletteChoice => {
      const palette = this.paletteService.resolvePalette(id);
      return {
        id: id,
        title: palette.title,
        previewColor: palette.previewColor,
        isSelected: id === selected
      };
    });
  }

  desktopTabOptions(selectedPlacement: string): FeatureIntroDesktopTabChoice[] {
    const selected = resolveFeatureIntroDesktopTabPlacement(selectedPlacement);
    return [
      {
        placement: 'horizontal',
        title: featureIntroText($r('app.string.settings_appearance_horizontal_tabs'), '水平标签页'),
        isSelected: selected === 'horizontal'
      },
      {
        placement: 'vertical',
        title: featureIntroText($r('app.string.feature_intro_vertical_tabs'), '竖向标签页'),
        isSelected: selected === 'vertical'
      }
    ];
  }

  tabOptions(selectedStyle: string): TabOverviewLayoutOptionState[] {
    const selected = resolveFeatureIntroAppearanceTabStyle(selectedStyle);
    return [
      {
        style: 'grid',
        title: featureIntroText($r('app.string.settings_appearance_grid'), '卡片平铺'),
        isSelected: selected === 'grid'
      },
      {
        style: 'horizontal_cards',
        title: featureIntroText($r('app.string.settings_appearance_large_cards'), '横向大卡片'),
        isSelected: selected === 'horizontal_cards'
      },
      {
        style: 'stack',
        title: featureIntroText($r('app.string.settings_appearance_stack'), '堆叠式'),
        isSelected: selected === 'stack'
      },
      {
        style: 'list',
        title: featureIntroText($r('app.string.settings_appearance_list'), '列表式'),
        isSelected: selected === 'list'
      }
    ];
  }
}

function featureIntroText(resource: Resource, fallback: string): string {
  const resolved = resolveAppResourceText(resource);
  return resolved.length > 0 ? resolved : fallback;
}
