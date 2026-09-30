import { DEFAULT_THEME_PALETTE } from '../../../features/theme/palettes/DefaultThemePalette';
import { SearchEngineManagementState } from '../../../core/search/SearchEngineManagementViewModel';
import {
  SettingsActionButton,
  SettingsNavigationRow,
  SettingsSwitchRow
} from '../settings/SettingsRows';
import { SettingsHdsScaffold } from '../settings/SettingsHdsScaffold';
import {
  SettingsGroupCard,
  SettingsGroupDivider,
  SettingsFooterText,
  SettingsPresentationScrollBody,
  SettingsSection
} from '../settings/SettingsLayout';
import {
  SettingsTargetRevealController,
  SettingsTargetRevealRegion
} from '../settings/SettingsTargetReveal';
import { isPrivateBoundaryRoute } from '../../../common/utils/RouteParamUtils';
import { SettingsNavigationCoordinator } from '../../router/SettingsNavigationCoordinator';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_DIVIDER_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { SettingsContentKind } from '../../../core/settings/SettingsContentLayoutPolicy';
import { resolveAppResourceText } from '../../../core/resources/AppResourceText';

@Component
export struct SearchSettingsScreen {
  private navigationCoordinator: SettingsNavigationCoordinator = new SettingsNavigationCoordinator();
  private settingsScroller: Scroller = new Scroller();
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY) private storedDividerColor: string = '#14000000';
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = DEFAULT_THEME_PALETTE.light.pageBackground;
  @StorageProp(BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY) private storedPressedBackgroundColor: string = '#DDE4EC';
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private storedSurfaceBackgroundColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  @Prop state: SearchEngineManagementState = {
    defaultEngineName: 'Bing',
    fallbackEnabled: false,
    fallbackEngineName: '',
    fallbackEngineSelectable: true,
    fallbackNoticeEnabled: true,
    fallbackInfoText: '',
    builtInEngines: [],
    customEngines: [],
    historySuggestionsEnabled: false,
    browsingHistorySuggestionsEnabled: false,
    bookmarkSuggestionsEnabled: true,
    openTabSuggestionsEnabled: true,
    remoteSuggestionsEnabled: true
  };
  @Prop dataScope: string = '';
  @Prop privacyMode: string = '';
  @Prop pageBackground: ResourceColor | undefined = undefined;
  @Prop surfaceBackground: ResourceColor | undefined = undefined;
  @Prop controlBackground: ResourceColor | undefined = undefined;
  @Prop pressedBackground: ResourceColor | undefined = undefined;
  @Prop accentColor: ResourceColor = '';
  @Prop primaryTextColor: ResourceColor = this.storedPrimaryTextColor;
  @Prop secondaryTextColor: ResourceColor = this.storedSecondaryTextColor;
  @Prop showBackButton: boolean = true;
  @Prop showTitleBar: boolean = true;
  @Prop useTopSafeInset: boolean = true;
  @Prop contentKind: SettingsContentKind = 'standard';
  @Prop desktopPresentation: boolean = false;
  @Prop @Watch('handleRevealRequest') revealTargetId: string = '';
  @Prop @Watch('handleRevealRequest') revealRevision: number = 0;
  @State private highlightedTargetId: string = '';
  private revealController: SettingsTargetRevealController = new SettingsTargetRevealController(
    (targetId: string): void => {
      this.highlightedTargetId = targetId;
    }
  );
  @Prop externalAppSearchSummary: string = resolveAppResourceText($r('app.string.settings_search_engine_external_on'));
  @Prop quickSearchSwitchingEnabled: boolean = true;
  onOpenDefaultEngine: () => void = () => {};
  onQuickSearchSwitchingChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onFallbackEnabledChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onOpenFallbackEngine: () => void = () => {};
  onFallbackNoticeEnabledChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onHistorySuggestionsChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onBrowsingHistorySuggestionsChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onBookmarkSuggestionsChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onOpenTabSuggestionsChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onRemoteSuggestionsChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onOpenExternalAppSearchSettings: () => void = () => {};
  onClearSearchHistory: () => void = () => {};

  aboutToAppear(): void {
    this.revealController.bindScroller(this.settingsScroller);
    this.handleRevealRequest();
  }

  aboutToDisappear(): void {
    this.revealController.dispose();
  }

  build() {
    SettingsHdsScaffold({
      title: $r('app.string.settings_search_engine_page_title'),
      backIconKind: 'back',
      pageBackground: this.resolvePageBackground(),
      headerButtonBackground: this.resolveControlBackground(),
      primaryTextColor: this.resolvePrimaryTextColor(),
      showPrivateIndicator: isPrivateBoundaryRoute(this.dataScope, this.privacyMode),
      showBackButton: this.showBackButton,
      showTitleBar: this.showTitleBar,
      useTopSafeInset: this.useTopSafeInset,
      contentKind: this.contentKind,
      desktopPresentation: this.desktopPresentation,
      scrollers: [this.settingsScroller],
      onBack: () => {
        this.navigationCoordinator.back();
      }
    }) {
      Column() {
        SettingsPresentationScrollBody({
          contentSpace: 18,
          desktopPresentation: this.desktopPresentation,
          topPadding: 16,
          bottomPadding: 32,
          scroller: this.settingsScroller,
          onContentAreaChanged: (area: Area): void => {
            this.revealController.rememberContentArea(area);
          }
        }) {
          this.buildDefaultSection()
          this.buildExternalAppSearchEntrySection()
          this.buildSuggestionsSection()
          this.buildClearSearchHistorySection()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.resolvePageBackground())
    }
  }

  @Builder
  private buildDefaultSection() {
    SettingsTargetRevealRegion({
      targetId: 'search_engine',
      highlightedTargetId: this.highlightedTargetId,
      accentColor: this.resolveAccentColor(),
      onAreaChanged: (targetId: string, area: Area): void => {
        this.revealController.rememberTargetArea(targetId, area);
      }
    }) {
      SettingsSection({
        title: $r('app.string.settings_search_engine_section'),
        secondaryTextColor: this.resolveSecondaryTextColor()
      }) {
        SettingsGroupCard({
          surfaceColor: this.resolveSurfaceBackground(),
          desktopPresentation: this.desktopPresentation
        }) {
        SettingsTargetRevealRegion({
          targetId: 'default_search_engine',
          highlightedTargetId: this.highlightedTargetId,
          accentColor: this.resolveAccentColor(),
          onAreaChanged: (targetId: string, area: Area): void => {
            this.revealController.rememberTargetArea(targetId, area);
          }
        }) {
          SettingsNavigationRow({
            title: $r('app.string.settings_search_engine_default'),
            desktopPresentation: this.desktopPresentation,
            value: this.state.defaultEngineName,
            primaryTextColor: this.resolvePrimaryTextColor(),
            secondaryTextColor: this.resolveSecondaryTextColor(),
            pressedBackgroundColor: this.resolvePressedBackground(),
            rowPosition: 'first',
            onAction: () => {
              this.onOpenDefaultEngine();
            }
          })
        }
        SettingsGroupDivider({ dividerColor: this.storedDividerColor })
        SettingsTargetRevealRegion({
          targetId: 'quick_search_switching',
          highlightedTargetId: this.highlightedTargetId,
          accentColor: this.resolveAccentColor(),
          onAreaChanged: (targetId: string, area: Area): void => {
            this.revealController.rememberTargetArea(targetId, area);
          }
        }) {
          SettingsSwitchRow({
            title: $r('app.string.settings_search_engine_quick_switch'),
            desktopPresentation: this.desktopPresentation,
            checked: this.quickSearchSwitchingEnabled,
            primaryTextColor: this.resolvePrimaryTextColor(),
            secondaryTextColor: this.resolveSecondaryTextColor(),
            pressedBackgroundColor: this.resolvePressedBackground(),
            rowPosition: 'middle',
            onChange: (enabled: boolean) => {
              this.onQuickSearchSwitchingChange(enabled);
            }
          })
        }
        SettingsGroupDivider({ dividerColor: this.storedDividerColor })
        SettingsTargetRevealRegion({
          targetId: 'smart_search_fallback',
          highlightedTargetId: this.highlightedTargetId,
          accentColor: this.resolveAccentColor(),
          onAreaChanged: (targetId: string, area: Area): void => {
            this.revealController.rememberTargetArea(targetId, area);
          }
        }) {
          SettingsSwitchRow({
            title: $r('app.string.settings_search_engine_smart_fallback'),
            desktopPresentation: this.desktopPresentation,
            checked: this.state.fallbackEnabled,
            isEnabled: this.state.fallbackEngineSelectable,
            titleActionIcon: $r('sys.symbol.info_circle'),
            titlePopupText: this.state.fallbackInfoText,
            titleActionAccessibilityText: $r('app.string.settings_search_engine_fallback_info'),
            primaryTextColor: this.resolvePrimaryTextColor(),
            secondaryTextColor: this.resolveSecondaryTextColor(),
            pressedBackgroundColor: this.resolvePressedBackground(),
            rowPosition: 'middle',
            onChange: (enabled: boolean) => {
              this.onFallbackEnabledChange(enabled);
            }
          })
        }
        SettingsGroupDivider({ dividerColor: this.storedDividerColor })
        SettingsTargetRevealRegion({
          targetId: 'fallback_search_engine',
          highlightedTargetId: this.highlightedTargetId,
          accentColor: this.resolveAccentColor(),
          onAreaChanged: (targetId: string, area: Area): void => {
            this.revealController.rememberTargetArea(targetId, area);
          }
        }) {
          SettingsNavigationRow({
            title: $r('app.string.settings_search_engine_fallback'),
            desktopPresentation: this.desktopPresentation,
            value: this.resolveFallbackEngineName(),
            isEnabled: this.state.fallbackEnabled && this.state.fallbackEngineSelectable,
            primaryTextColor: this.resolvePrimaryTextColor(),
            secondaryTextColor: this.resolveSecondaryTextColor(),
            pressedBackgroundColor: this.resolvePressedBackground(),
            rowPosition: 'middle',
            onAction: () => {
              this.onOpenFallbackEngine();
            }
          })
        }
        SettingsGroupDivider({ dividerColor: this.storedDividerColor })
        SettingsTargetRevealRegion({
          targetId: 'fallback_notice',
          highlightedTargetId: this.highlightedTargetId,
          accentColor: this.resolveAccentColor(),
          onAreaChanged: (targetId: string, area: Area): void => {
            this.revealController.rememberTargetArea(targetId, area);
          }
        }) {
          SettingsSwitchRow({
            title: $r('app.string.settings_search_engine_fallback_notice'),
            desktopPresentation: this.desktopPresentation,
            checked: this.state.fallbackNoticeEnabled,
            isEnabled: this.state.fallbackEnabled,
            primaryTextColor: this.resolvePrimaryTextColor(),
            secondaryTextColor: this.resolveSecondaryTextColor(),
            pressedBackgroundColor: this.resolvePressedBackground(),
            rowPosition: 'last',
            onChange: (enabled: boolean) => {
              this.onFallbackNoticeEnabledChange(enabled);
            }
          })
        }
        }
        SettingsFooterText({
          text: $r('app.string.settings_search_engine_fallback_footer'),
          secondaryTextColor: this.resolveSecondaryTextColor()
        })
      }
    }
  }

  @Builder
  private buildSuggestionsSection() {
    SettingsTargetRevealRegion({
      targetId: 'suggestions_info',
      highlightedTargetId: this.highlightedTargetId,
      accentColor: this.resolveAccentColor(),
      onAreaChanged: (targetId: string, area: Area): void => {
        this.revealController.rememberTargetArea(targetId, area);
      }
    }) {
      SettingsSection({
        title: $r('app.string.settings_search_engine_suggestions'),
        secondaryTextColor: this.resolveSecondaryTextColor()
      }) {
        SettingsGroupCard({
          surfaceColor: this.resolveSurfaceBackground(),
          desktopPresentation: this.desktopPresentation
        }) {
        SettingsTargetRevealRegion({
          targetId: 'search_history_suggestions',
          highlightedTargetId: this.highlightedTargetId,
          accentColor: this.resolveAccentColor(),
          onAreaChanged: (targetId: string, area: Area): void => {
            this.revealController.rememberTargetArea(targetId, area);
          }
        }) {
          SettingsSwitchRow({
            title: $r('app.string.settings_search_engine_history_suggestions'),
            desktopPresentation: this.desktopPresentation,
            checked: this.state.historySuggestionsEnabled,
            primaryTextColor: this.resolvePrimaryTextColor(),
            secondaryTextColor: this.resolveSecondaryTextColor(),
            pressedBackgroundColor: this.resolvePressedBackground(),
            rowPosition: 'first',
            onChange: (enabled: boolean) => {
              this.onHistorySuggestionsChange(enabled);
            }
          })
        }
        SettingsGroupDivider({ dividerColor: this.storedDividerColor })
        SettingsTargetRevealRegion({
          targetId: 'browsing_history_suggestions',
          highlightedTargetId: this.highlightedTargetId,
          accentColor: this.resolveAccentColor(),
          onAreaChanged: (targetId: string, area: Area): void => {
            this.revealController.rememberTargetArea(targetId, area);
          }
        }) {
          SettingsSwitchRow({
            title: $r('app.string.settings_search_engine_browsing_suggestions'),
            desktopPresentation: this.desktopPresentation,
            checked: this.state.browsingHistorySuggestionsEnabled,
            primaryTextColor: this.resolvePrimaryTextColor(),
            secondaryTextColor: this.resolveSecondaryTextColor(),
            pressedBackgroundColor: this.resolvePressedBackground(),
            rowPosition: 'middle',
            onChange: (enabled: boolean) => {
              this.onBrowsingHistorySuggestionsChange(enabled);
            }
          })
        }
        SettingsGroupDivider({ dividerColor: this.storedDividerColor })
        SettingsTargetRevealRegion({
          targetId: 'bookmark_suggestions',
          highlightedTargetId: this.highlightedTargetId,
          accentColor: this.resolveAccentColor(),
          onAreaChanged: (targetId: string, area: Area): void => {
            this.revealController.rememberTargetArea(targetId, area);
          }
        }) {
          SettingsSwitchRow({
            title: $r('app.string.settings_search_engine_bookmark_suggestions'),
            desktopPresentation: this.desktopPresentation,
            checked: this.state.bookmarkSuggestionsEnabled,
            primaryTextColor: this.resolvePrimaryTextColor(),
            secondaryTextColor: this.resolveSecondaryTextColor(),
            pressedBackgroundColor: this.resolvePressedBackground(),
            rowPosition: 'middle',
            onChange: (enabled: boolean) => {
              this.onBookmarkSuggestionsChange(enabled);
            }
          })
        }
        SettingsGroupDivider({ dividerColor: this.storedDividerColor })
        SettingsTargetRevealRegion({
          targetId: 'open_tab_suggestions',
          highlightedTargetId: this.highlightedTargetId,
          accentColor: this.resolveAccentColor(),
          onAreaChanged: (targetId: string, area: Area): void => {
            this.revealController.rememberTargetArea(targetId, area);
          }
        }) {
          SettingsSwitchRow({
            title: $r('app.string.settings_search_engine_open_tabs'),
            desktopPresentation: this.desktopPresentation,
            checked: this.state.openTabSuggestionsEnabled,
            primaryTextColor: this.resolvePrimaryTextColor(),
            secondaryTextColor: this.resolveSecondaryTextColor(),
            pressedBackgroundColor: this.resolvePressedBackground(),
            rowPosition: 'middle',
            onChange: (enabled: boolean) => {
              this.onOpenTabSuggestionsChange(enabled);
            }
          })
        }
        SettingsGroupDivider({ dividerColor: this.storedDividerColor })
        SettingsTargetRevealRegion({
          targetId: 'remote_search_suggestions',
          highlightedTargetId: this.highlightedTargetId,
          accentColor: this.resolveAccentColor(),
          onAreaChanged: (targetId: string, area: Area): void => {
            this.revealController.rememberTargetArea(targetId, area);
          }
        }) {
          SettingsSwitchRow({
            title: $r('app.string.settings_search_engine_remote_suggestions'),
            desktopPresentation: this.desktopPresentation,
            checked: this.state.remoteSuggestionsEnabled,
            primaryTextColor: this.resolvePrimaryTextColor(),
            secondaryTextColor: this.resolveSecondaryTextColor(),
            pressedBackgroundColor: this.resolvePressedBackground(),
            rowPosition: 'last',
            onChange: (enabled: boolean) => {
              this.onRemoteSuggestionsChange(enabled);
            }
          })
        }
        }
        SettingsFooterText({
          text: $r('app.string.settings_search_engine_suggestions_footer'),
          secondaryTextColor: this.resolveSecondaryTextColor()
        })
      }
    }
  }

  @Builder
  private buildExternalAppSearchEntrySection() {
    SettingsSection({
      title: $r('app.string.settings_search_engine_more_ways'),
      secondaryTextColor: this.resolveSecondaryTextColor()
    }) {
      SettingsGroupCard({
        surfaceColor: this.resolveSurfaceBackground(),
        desktopPresentation: this.desktopPresentation
      }) {
        SettingsTargetRevealRegion({
          targetId: 'external_app_search',
          highlightedTargetId: this.highlightedTargetId,
          accentColor: this.resolveAccentColor(),
          onAreaChanged: (targetId: string, area: Area): void => {
            this.revealController.rememberTargetArea(targetId, area);
          }
        }) {
          SettingsNavigationRow({
            title: $r('app.string.settings_search_engine_external_app'),
            desktopPresentation: this.desktopPresentation,
            value: this.externalAppSearchSummary,
            primaryTextColor: this.resolvePrimaryTextColor(),
            secondaryTextColor: this.resolveSecondaryTextColor(),
            pressedBackgroundColor: this.resolvePressedBackground(),
            rowPosition: 'single',
            onAction: () => {
              this.onOpenExternalAppSearchSettings();
            }
          })
        }
      }
    }
  }

  @Builder
  private buildClearSearchHistorySection() {
    SettingsTargetRevealRegion({
      targetId: 'clear_search_history',
      highlightedTargetId: this.highlightedTargetId,
      accentColor: this.resolveAccentColor(),
      onAreaChanged: (targetId: string, area: Area): void => {
        this.revealController.rememberTargetArea(targetId, area);
      }
    }) {
      SettingsActionButton({
        title: $r('app.string.settings_search_engine_clear_history'),
        emphasis: 'danger',
        pressedBackgroundColor: this.resolvePressedBackground(),
        onAction: () => {
          this.onClearSearchHistory();
        }
      })
    }
  }

  private handleRevealRequest(): void {
    this.revealController.request(this.revealTargetId, this.revealRevision);
  }

  private resolveAccentColor(): ResourceColor {
    return `${this.accentColor}`.length > 0 ? this.accentColor : this.storedAccentColor;
  }

  private resolvePageBackground(): ResourceColor {
    return this.pageBackground === undefined ? this.storedPageBackgroundColor : this.pageBackground;
  }

  private resolveSurfaceBackground(): ResourceColor {
    return this.surfaceBackground === undefined ? this.storedSurfaceBackgroundColor : this.surfaceBackground;
  }

  private resolveControlBackground(): ResourceColor {
    return this.controlBackground === undefined ? this.storedPressedBackgroundColor : this.controlBackground;
  }

  private resolvePressedBackground(): ResourceColor {
    return this.pressedBackground === undefined ? this.storedPressedBackgroundColor : this.pressedBackground;
  }

  private resolvePrimaryTextColor(): ResourceColor {
    return this.primaryTextColor === undefined ? this.storedPrimaryTextColor : this.primaryTextColor;
  }

  private resolveSecondaryTextColor(): ResourceColor {
    return this.secondaryTextColor === undefined ? this.storedSecondaryTextColor : this.secondaryTextColor;
  }

  private resolveFallbackEngineName(): string {
    return this.state.fallbackEngineName.length > 0 ? this.state.fallbackEngineName : resolveAppResourceText($r('app.string.settings_search_engine_not_selected'));
  }

}
