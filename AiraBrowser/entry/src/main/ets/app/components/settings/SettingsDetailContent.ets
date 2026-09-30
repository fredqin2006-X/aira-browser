import {
  SettingsDetailActionButtonState,
  SettingsDetailGroupState,
  SettingsDetailOption,
  SettingsDetailRowAction,
  SettingsDetailRowState,
  SettingsDetailState
} from '../../../core/settings/SettingsDetailViewModel';
import { localizeAppearanceSettingsCopy } from '../../../core/settings/SettingsAppearanceCopy';
import { localizeAboutSettingsCopy } from '../../../core/settings/SettingsAboutCopy';
import { localizePrivacyModeSettingsCopy } from '../../../core/settings/SettingsPrivacyModeCopy';
import { localizePrivacyProtectionCopy } from '../../../core/settings/SettingsPrivacyProtectionCopy';
import { localizeAdvancedSettingsCopy } from '../../../core/settings/SettingsAdvancedCopy';
import { localizeExperimentsSettingsCopy } from '../../../core/settings/SettingsExperimentsCopy';
import { localizeGeneralSettingsCopy } from '../../../core/settings/SettingsGeneralCoordinator';
import { SettingsDetailActionResolver } from '../../../core/settings/SettingsDetailActionResolver';
import { BrowserTabsOverviewLayoutStyle, BrowserThemeMode } from '../../../common/models/BrowserModels';
import { BrowserDataBoundaryInput } from '../../../common/models/BrowserModels';
import {
  TabOverviewLayoutApplyResult,
  TabOverviewLayoutSettingsCoordinator,
  TabOverviewLayoutSettingsState
} from '../../../core/settings/TabOverviewLayoutSettingsCoordinator';
import {
  sharedPreferencesRepository,
  syncBrowserThemeAppStorage
} from '../../bootstrap/BrowserAppRuntime';
import {
  BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import {
  SettingsActionButton,
  SettingsDropdownRow,
  SettingsNavigationRow,
  SettingsOptionRow,
  SettingsStaticValueRow,
  SettingsSwitchRow
} from './SettingsRows';
import {
  SettingsDesktopActionButton,
  SettingsDesktopDivider,
  SettingsDesktopDropdownRow,
  SettingsDesktopGroup,
  SettingsDesktopNavigationRow,
  SettingsDesktopOptionRow,
  SettingsDesktopStaticValueRow,
  SettingsDesktopSwitchRow
} from './SettingsDesktopRows';
import {
  SettingsFooterText,
  SettingsGroupCard,
  SettingsGroupDivider,
  SettingsSection
} from './SettingsLayout';
import { ThemeModeOptionCard } from './ThemeModeOptionCard';
import { TabOverviewLayoutChoiceSheet } from './TabOverviewLayoutChoiceSheet';
import { DesktopTabPlacementChoiceDialog } from './DesktopTabPlacementChoiceDialog';
import { BrowserPrivacyProtectionOverview } from './BrowserPrivacyProtectionOverview';
import { BrowserWebSecuritySettingsContent } from './BrowserWebSecuritySettingsContent';
import {
  SettingsTargetRevealController,
  SettingsTargetRevealRegion
} from './SettingsTargetReveal';
import { applyDesktopDialogSheetChrome } from '../common/DesktopDialogSheetChrome';

/**
 * Two preview rows plus the switch, with the stacked 应用/取消 footer left clear below them.
 * A percentage left the switch in that footer. The system caps this if the window is shorter,
 * and the sheet's own bottom inset still lets the switch scroll out from under the buttons.
 */
const TAB_OVERVIEW_LAYOUT_SHEET_HEIGHT: Length = 720;

@Component
export struct SettingsDetailContent {
  private tabOverviewLayoutCoordinator: TabOverviewLayoutSettingsCoordinator =
    new TabOverviewLayoutSettingsCoordinator(sharedPreferencesRepository);
  @Prop state: SettingsDetailState = {
    id: 'general',
    title: $r('app.string.settings_general'),
    groups: [],
    actionButtons: []
  };
  @Prop surfaceBackground: ResourceColor = '';
  @Prop dividerColor: ResourceColor = '';
  @Prop accentColor: ResourceColor = '';
  @Prop onAccentColor: ResourceColor = '';
  @Prop pressedBackground: ResourceColor = '';
  @Prop primaryTextColor: ResourceColor = '';
  @Prop secondaryTextColor: ResourceColor = '';
  @Prop renderVersion: number = 0;
  @Prop themeRenderKey: string = '';
  @Prop isLargeScreen: boolean = false;
  @Prop dataScope: string = '';
  @Prop privacyMode: string = '';
  @Prop @Watch('handleRevealRequest') revealTargetId: string = '';
  @Prop @Watch('handleRevealRequest') revealRevision: number = 0;
  scroller?: Scroller;
  @StorageProp(BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY) private storedResolvedThemeMode: string = 'light';
  @State private tabOverviewLayoutState: TabOverviewLayoutSettingsState =
    this.tabOverviewLayoutCoordinator.buildInitialState();
  @State private tabStyleSheetVisible: boolean = false;
  @State private tabStyleSheetKind: string = 'overview';
  @State private desktopTabPlacementSaving: boolean = false;
  @State private desktopTabPlacement: string = 'horizontal';
  @State private highlightedTargetId: string = '';
  private actionResolver: SettingsDetailActionResolver = new SettingsDetailActionResolver();
  private revealController: SettingsTargetRevealController = new SettingsTargetRevealController(
    (targetId: string): void => {
      this.highlightedTargetId = targetId;
    }
  );
  onRowAction?: (row: SettingsDetailRowState, nextChecked?: boolean) => void;
  onDropdownSelect?: (row: SettingsDetailRowState, optionId: string) => void;
  onActionButton?: (button: SettingsDetailActionButtonState) => void;
  onTabOverviewLayoutApplied?: () => void;
  onOpenJavaScriptExceptions?: () => void;

  aboutToAppear(): void {
    this.revealController.bindScroller(this.scroller);
    this.handleRevealRequest();
  }

  aboutToDisappear(): void {
    this.revealController.dispose();
  }

  build() {
    // Sheet host is not the component root. The large-screen detail panel also
    // bindSheet()s this component, and a second bindSheet on the same node
    // replaces the first, so the tab-style sheet never opened.
    Column() {
      this.buildDetailBody()
    }
    .width('100%')
  }

  @Builder
  private buildDetailBody() {
    Column({ space: 16 }) {
      if (this.state.id === 'privacy_security') {
        BrowserPrivacyProtectionOverview({
          surfaceBackground: this.surfaceBackground,
          accentColor: this.accentColor,
          pressedBackground: this.pressedBackground,
          primaryTextColor: this.primaryTextColor,
          secondaryTextColor: this.secondaryTextColor,
          desktopPresentation: this.isLargeScreen,
          refreshRevision: this.renderVersion
        })
        BrowserWebSecuritySettingsContent({
          surfaceBackground: this.surfaceBackground,
          dividerColor: this.dividerColor,
          accentColor: this.accentColor,
          primaryTextColor: this.primaryTextColor,
          secondaryTextColor: this.secondaryTextColor,
          pressedBackground: this.pressedBackground,
          desktopPresentation: this.isLargeScreen,
          dataScope: this.dataScope,
          privacyMode: this.privacyMode,
          onOpenJavaScriptExceptions: (): void => {
            this.onOpenJavaScriptExceptions?.();
          }
        })
      }
      ForEach(this.state.groups, (group: SettingsDetailGroupState) => {
        this.buildSection(group)
      }, (group: SettingsDetailGroupState) => this.resolveGroupRenderKey(group))
      if (this.state.actionButtons.length > 0) {
        this.buildActionArea()
      }
    }
    .width('100%')
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.revealController.rememberContentArea(newArea);
    })
    .bindSheet($$this.tabStyleSheetVisible, this.buildTabStyleSheet(), this.resolveTabStyleSheetOptions())
  }

  private resolveTabStyleSheetOptions(): SheetOptions {
    if (this.tabStyleSheetKind === 'desktop') {
      return applyDesktopDialogSheetChrome({
        preferType: SheetType.CENTER,
        height: SheetSize.FIT_CONTENT,
        dragBar: false,
        showClose: false
      }, 's', true);
    }
    // Large screen presents this choice centered, not as a phone bottom sheet.
    // No onDisappear state work: every dismiss path already clears the visibility
    // flag, and the draft is reset by refreshDraft on the next open.
    return applyDesktopDialogSheetChrome({
      preferType: this.isLargeScreen ? SheetType.CENTER : SheetType.BOTTOM,
      height: TAB_OVERVIEW_LAYOUT_SHEET_HEIGHT,
      dragBar: !this.isLargeScreen,
      showClose: false
    }, 'm', this.isLargeScreen);
  }

  @Builder
  private buildTabStyleSheet() {
    if (this.tabStyleSheetKind === 'desktop') {
      this.buildDesktopTabPlacementDialog()
    } else {
      this.buildTabOverviewLayoutChoiceSheet()
    }
  }

  @Builder
  private buildSection(group: SettingsDetailGroupState) {
    if (this.shouldRenderThemeModePreview(group)) {
      this.buildThemeModePreviewSection(group)
    } else if (group.rows.length === 0 && this.resolveGroupActionButtons(group).length > 0) {
      this.buildStandaloneGroupActions(group)
      if ((group.footerText ?? '').trim().length > 0) {
        this.buildGroupFooter(group)
      }
    } else {
      SettingsSection({
        title: group.title,
        secondaryTextColor: this.secondaryTextColor
      }) {
        this.buildGroupSurface(group)

        if ((group.footerText ?? '').trim().length > 0) {
          this.buildGroupFooter(group)
        }
      }
    }
  }

  @Builder
  private buildGroupSurface(group: SettingsDetailGroupState) {
    if (this.isLargeScreen) {
      SettingsDesktopGroup({ surfaceColor: this.surfaceBackground }) {
        this.buildGroupContent(group)
      }
    } else {
      SettingsGroupCard({ surfaceColor: this.surfaceBackground }) {
        this.buildGroupContent(group)
      }
    }
  }

  @Builder
  private buildGroupContent(group: SettingsDetailGroupState) {
    ForEach(group.rows, (row: SettingsDetailRowState, index: number) => {
      this.buildRow(row, index, group.rows.length, group.id)
      if (index < group.rows.length - 1) {
        if (this.isLargeScreen) {
          SettingsDesktopDivider({ dividerColor: this.dividerColor })
        } else {
          SettingsGroupDivider({ dividerColor: this.dividerColor })
        }
      }
    }, (row: SettingsDetailRowState) => this.resolveRowRenderKey(row, group.id))
    this.buildGroupActions(group)
  }

  @Builder
  private buildThemeModePreviewSection(group: SettingsDetailGroupState) {
    SettingsSection({
      title: group.title,
      secondaryTextColor: this.secondaryTextColor
    }) {
      Column({ space: 16 }) {
        Row({ space: 16 }) {
        ForEach(this.resolveThemeModePreviewRows(group), (row: SettingsDetailRowState) => {
            this.buildThemeModeOptionCard(row, group)
          }, (row: SettingsDetailRowState) => this.resolveThemeModeCardRenderKey(row, group))
        }
        .width('100%')

        ForEach(this.resolveThemeModeSystemRows(group), (row: SettingsDetailRowState) => {
          this.buildThemeModeSystemRow(row, group)
        }, (row: SettingsDetailRowState) => this.resolveRowRenderKey(row, group.id))
      }
      .width('100%')

      if ((group.footerText ?? '').trim().length > 0) {
        this.buildGroupFooter(group)
      }
    }
  }

  @Builder
  private buildRow(row: SettingsDetailRowState, index: number, rowCount: number, groupId: string) {
    SettingsTargetRevealRegion({
      targetId: row.id,
      highlightedTargetId: this.highlightedTargetId,
      accentColor: this.accentColor,
      onAreaChanged: (targetId: string, area: Area): void => {
        this.revealController.rememberTargetArea(targetId, area);
      }
    }) {
      this.buildRowContent(row, index, rowCount, groupId)
    }
  }

  @Builder
  private buildRowContent(row: SettingsDetailRowState, index: number, rowCount: number, groupId: string) {
    if (this.isLargeScreen) {
      this.buildDesktopRowContent(row, groupId)
    } else if (row.kind === 'dropdown') {
      SettingsDropdownRow({
        title: this.localizeGeneralCopy(row.title),
        value: this.localizeGeneralCopy(row.value),
        description: this.localizeGeneralCopy(row.helperText),
        options: this.localizeGeneralOptions(row.options ?? []),
        rowPosition: this.resolveRowPosition(index, rowCount),
        isEnabled: this.isRowInteractive(row),
        primaryTextColor: this.primaryTextColor,
        secondaryTextColor: this.secondaryTextColor,
        pressedBackgroundColor: this.pressedBackground,
        onSelect: (optionId: string) => {
          this.onDropdownSelect?.(row, optionId);
        }
      })
    } else if (row.kind === 'navigation') {
      SettingsNavigationRow({
        title: this.localizeGeneralCopy(row.title),
        value: this.localizeGeneralCopy(row.value),
        valueSwatchColor: row.valueSwatchColor,
        description: this.localizeGeneralCopy(row.helperText),
        primaryTextColor: this.primaryTextColor,
        secondaryTextColor: this.secondaryTextColor,
        pressedBackgroundColor: this.pressedBackground,
        rowPosition: this.resolveRowPosition(index, rowCount),
        isEnabled: this.isRowInteractive(row),
        onAction: () => {
          this.handleNavigationRowAction(row);
        }
      })
    } else if (row.kind === 'option') {
      SettingsOptionRow({
        title: this.localizeGeneralCopy(row.title),
        helperText: this.localizeGeneralCopy(row.helperText),
        rowPosition: this.resolveRowPosition(index, rowCount),
        isSelected: row.isSelected,
        isEnabled: row.isEnabled,
        primaryTextColor: this.primaryTextColor,
        secondaryTextColor: this.secondaryTextColor,
        pressedBackgroundColor: this.pressedBackground,
        radioGroup: this.resolveOptionRadioGroup(groupId),
        radioValue: row.id,
        onAction: () => {
          this.onRowAction?.(row);
        }
      })
    } else if (row.kind === 'switch') {
      SettingsSwitchRow({
        title: this.localizeGeneralCopy(row.title),
        description: this.localizeGeneralCopy(row.helperText),
        checked: row.checked,
        rowPosition: this.resolveRowPosition(index, rowCount),
        isEnabled: row.isEnabled,
        primaryTextColor: this.primaryTextColor,
        secondaryTextColor: this.secondaryTextColor,
        pressedBackgroundColor: this.pressedBackground,
        onChange: (checked: boolean) => {
          this.onRowAction?.(row, checked);
        }
      })
    } else {
      SettingsStaticValueRow({
        title: this.localizeGeneralCopy(row.title),
        value: this.localizeGeneralCopy(row.value),
        description: this.localizeGeneralCopy(row.helperText),
        primaryTextColor: this.primaryTextColor,
        secondaryTextColor: this.secondaryTextColor,
        rowPosition: this.resolveRowPosition(index, rowCount)
      })
    }
  }

  @Builder
  private buildDesktopRowContent(row: SettingsDetailRowState, groupId: string) {
    if (row.kind === 'dropdown') {
      SettingsDesktopDropdownRow({
        title: this.localizeGeneralCopy(row.title),
        value: this.localizeGeneralCopy(row.value),
        options: this.localizeGeneralOptions(row.options ?? []),
        menuRadioGroup: `${this.state.id}_${groupId}_${row.id}_desktop_dropdown`,
        isEnabled: this.isRowInteractive(row),
        primaryTextColor: this.primaryTextColor,
        secondaryTextColor: this.secondaryTextColor,
        hoverBackgroundColor: this.pressedBackground,
        focusColor: this.accentColor,
        onSelect: (optionId: string) => {
          this.onDropdownSelect?.(row, optionId);
        }
      })
    } else if (row.kind === 'navigation') {
      SettingsDesktopNavigationRow({
        title: this.localizeGeneralCopy(row.title),
        value: this.localizeGeneralCopy(row.value),
        valueSwatchColor: row.valueSwatchColor,
        isEnabled: this.isRowInteractive(row),
        primaryTextColor: this.primaryTextColor,
        secondaryTextColor: this.secondaryTextColor,
        hoverBackgroundColor: this.pressedBackground,
        focusColor: this.accentColor,
        onAction: () => {
          this.handleNavigationRowAction(row);
        }
      })
    } else if (row.kind === 'option') {
      SettingsDesktopOptionRow({
        title: this.localizeGeneralCopy(row.title),
        isSelected: row.isSelected,
        isEnabled: row.isEnabled,
        radioGroup: this.resolveOptionRadioGroup(groupId),
        radioValue: row.id,
        primaryTextColor: this.primaryTextColor,
        secondaryTextColor: this.secondaryTextColor,
        hoverBackgroundColor: this.pressedBackground,
        focusColor: this.accentColor,
        onAction: () => {
          this.onRowAction?.(row);
        }
      })
    } else if (row.kind === 'switch') {
      SettingsDesktopSwitchRow({
        title: this.localizeGeneralCopy(row.title),
        checked: row.checked,
        isEnabled: row.isEnabled,
        primaryTextColor: this.primaryTextColor,
        secondaryTextColor: this.secondaryTextColor,
        hoverBackgroundColor: this.pressedBackground,
        focusColor: this.accentColor,
        onChange: (checked: boolean) => {
          this.onRowAction?.(row, checked);
        }
      })
    } else {
      SettingsDesktopStaticValueRow({
        title: this.localizeGeneralCopy(row.title),
        value: this.localizeGeneralCopy(row.value),
        primaryTextColor: this.primaryTextColor,
        secondaryTextColor: this.secondaryTextColor
      })
    }
  }

  @Builder
  private buildThemeModeOptionCard(row: SettingsDetailRowState, group: SettingsDetailGroupState) {
    SettingsTargetRevealRegion({
      targetId: row.id,
      highlightedTargetId: this.highlightedTargetId,
      accentColor: this.accentColor,
      regionLayoutWeight: 1,
      onAreaChanged: (targetId: string, area: Area): void => {
        this.revealController.rememberTargetArea(targetId, area);
      }
    }) {
      ThemeModeOptionCard({
        mode: this.resolveThemeModePreviewMode(row.action),
        title: this.localizeGeneralCopy(row.title),
        isSelected: this.isThemePreviewSelected(row, group),
        isEnabled: row.isEnabled,
        desktopPresentation: this.isLargeScreen,
        onAction: () => {
          this.onRowAction?.(row);
        }
      })
    }
  }

  @Builder
  private buildThemeModeSystemRow(row: SettingsDetailRowState, group: SettingsDetailGroupState) {
    if (this.isLargeScreen) {
      SettingsDesktopGroup({ surfaceColor: this.surfaceBackground }) {
        this.buildThemeModeSystemRowContent(row, group)
      }
    } else {
      SettingsGroupCard({ surfaceColor: this.surfaceBackground }) {
        this.buildThemeModeSystemRowContent(row, group)
      }
    }
  }

  @Builder
  private buildThemeModeSystemRowContent(row: SettingsDetailRowState, group: SettingsDetailGroupState) {
      SettingsTargetRevealRegion({
        targetId: row.id,
        highlightedTargetId: this.highlightedTargetId,
        accentColor: this.accentColor,
        onAreaChanged: (targetId: string, area: Area): void => {
          this.revealController.rememberTargetArea(targetId, area);
        }
      }) {
        if (this.isLargeScreen) {
          SettingsDesktopSwitchRow({
            title: $r('app.string.settings_screen_orientation_system_title'),
            checked: row.isSelected,
            isEnabled: row.isEnabled,
            primaryTextColor: this.primaryTextColor,
            secondaryTextColor: this.secondaryTextColor,
            hoverBackgroundColor: this.pressedBackground,
            focusColor: this.accentColor,
            onChange: (checked: boolean) => {
              this.handleThemeSystemSwitchChange(group, row, checked);
            }
          })
        } else {
          SettingsSwitchRow({
            title: $r('app.string.settings_screen_orientation_system_title'),
            description: '',
            checked: row.isSelected,
            rowPosition: 'single',
            isEnabled: row.isEnabled,
            primaryTextColor: this.primaryTextColor,
            secondaryTextColor: this.secondaryTextColor,
            pressedBackgroundColor: this.pressedBackground,
            onChange: (checked: boolean) => {
              this.handleThemeSystemSwitchChange(group, row, checked);
            }
          })
        }
      }
  }

  @Builder
  private buildGroupFooter(group: SettingsDetailGroupState) {
    SettingsFooterText({
      text: this.localizeGeneralCopy(group.footerText ?? ''),
      secondaryTextColor: this.secondaryTextColor
    })
  }

  @Builder
  private buildStandaloneGroupActions(group: SettingsDetailGroupState) {
    if (this.isLargeScreen) {
      Row({ space: 8 }) {
        ForEach(this.resolveGroupActionButtons(group), (button: SettingsDetailActionButtonState) => {
          this.buildRevealableActionButton(button)
        }, (button: SettingsDetailActionButtonState) => this.resolveActionButtonRenderKey(button))
      }
      .width('100%')
      .padding({ left: 8, right: 8 })
      .justifyContent(FlexAlign.End)
    } else {
      Column({ space: 8 }) {
        ForEach(this.resolveGroupActionButtons(group), (button: SettingsDetailActionButtonState) => {
          this.buildRevealableActionButton(button)
        }, (button: SettingsDetailActionButtonState) => this.resolveActionButtonRenderKey(button))
      }
      .width('100%')
      .padding({ left: 8, right: 8 })
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private buildGroupActions(group: SettingsDetailGroupState) {
    if (this.resolveGroupActionButtons(group).length > 0) {
      if (group.rows.length > 0) {
        if (this.isLargeScreen) {
          SettingsDesktopDivider({ dividerColor: this.dividerColor })
        } else {
          SettingsGroupDivider({ dividerColor: this.dividerColor })
        }
      }
      if (this.isLargeScreen) {
        Row({ space: 8 }) {
          ForEach(this.resolveGroupActionButtons(group), (button: SettingsDetailActionButtonState) => {
            this.buildRevealableActionButton(button)
          }, (button: SettingsDetailActionButtonState) => this.resolveActionButtonRenderKey(button))
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 8, bottom: 8 })
        .justifyContent(FlexAlign.End)
      } else {
        Column({ space: 4 }) {
          ForEach(this.resolveGroupActionButtons(group), (button: SettingsDetailActionButtonState) => {
            this.buildRevealableActionButton(button)
          }, (button: SettingsDetailActionButtonState) => this.resolveActionButtonRenderKey(button))
        }
        .width('100%')
        .padding({ top: group.rows.length > 0 ? 2 : 8, bottom: group.rows.length > 0 ? 2 : 8 })
        .alignItems(HorizontalAlign.Center)
      }
    }
  }

  @Builder
  private buildActionArea() {
    if (this.isLargeScreen) {
      Row({ space: 8 }) {
        ForEach(this.state.actionButtons, (button: SettingsDetailActionButtonState) => {
          this.buildRevealableActionButton(button)
        }, (button: SettingsDetailActionButtonState) => this.resolveActionButtonRenderKey(button))
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 2, bottom: 0 })
      .justifyContent(FlexAlign.End)
    } else {
      Column({ space: 4 }) {
        ForEach(this.state.actionButtons, (button: SettingsDetailActionButtonState) => {
          this.buildRevealableActionButton(button)
        }, (button: SettingsDetailActionButtonState) => this.resolveActionButtonRenderKey(button))
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 2, bottom: 0 })
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private buildRevealableActionButton(button: SettingsDetailActionButtonState) {
    SettingsTargetRevealRegion({
      targetId: button.id,
      highlightedTargetId: this.highlightedTargetId,
      accentColor: this.accentColor,
      onAreaChanged: (targetId: string, area: Area): void => {
        this.revealController.rememberTargetArea(targetId, area);
      }
    }) {
      if (this.isLargeScreen) {
        SettingsDesktopActionButton({
          title: this.localizeGeneralCopy(button.title),
          emphasis: button.emphasis,
          isEnabled: button.isEnabled,
          accentColor: this.accentColor,
          onAccentColor: this.onAccentColor,
          hoverBackgroundColor: this.pressedBackground,
          dangerColor: this.primaryTextColor,
          onAction: () => {
            this.onActionButton?.(button);
          }
        })
      } else {
        SettingsActionButton({
          title: this.localizeGeneralCopy(button.title),
          emphasis: button.emphasis,
          isEnabled: button.isEnabled,
          accentColor: this.accentColor,
          pressedBackgroundColor: this.pressedBackground,
          onAction: () => {
            this.onActionButton?.(button);
          }
        })
      }
    }
  }

  private handleRevealRequest(): void {
    this.revealController.request(this.revealTargetId, this.revealRevision);
  }

  private resolveGroupActionButtons(group: SettingsDetailGroupState): SettingsDetailActionButtonState[] {
    return group.actionButtons ?? [];
  }

  @Builder
  private buildTabOverviewLayoutChoiceSheet() {
    TabOverviewLayoutChoiceSheet({
      options: this.tabOverviewLayoutCoordinator.buildOptions(this.tabOverviewLayoutState),
      layoutMode: this.isLargeScreen ? 'large_screen' : 'phone',
      closeButtonAlwaysVisible: this.tabOverviewLayoutState.draftCloseButtonAlwaysVisible,
      isSaving: this.tabOverviewLayoutState.isSaving,
      errorMessage: this.tabOverviewLayoutState.errorMessage,
      onSelect: (style: BrowserTabsOverviewLayoutStyle) => {
        this.tabOverviewLayoutState =
          this.tabOverviewLayoutCoordinator.selectDraft(this.tabOverviewLayoutState, style);
      },
      onCloseButtonAlwaysVisibleChange: (alwaysVisible: boolean) => {
        this.tabOverviewLayoutState = this.tabOverviewLayoutCoordinator.setCloseButtonAlwaysVisibleDraft(
          this.tabOverviewLayoutState,
          alwaysVisible
        );
      },
      onCancel: () => {
        if (this.tabOverviewLayoutState.isSaving) {
          return;
        }
        this.tabOverviewLayoutState =
          this.tabOverviewLayoutCoordinator.cancelDraft(this.tabOverviewLayoutState);
        this.tabStyleSheetVisible = false;
      },
      onApply: () => {
        this.applyTabOverviewLayoutDraft();
      }
    })
  }

  @Builder
  private buildDesktopTabPlacementDialog() {
    DesktopTabPlacementChoiceDialog({
      selectedPlacement: this.desktopTabPlacement,
      isSaving: this.desktopTabPlacementSaving,
      onSelect: (placement: string): void => {
        this.applyDesktopTabPlacement(placement);
      },
      onClose: (): void => {
        this.tabStyleSheetVisible = false;
      }
    })
  }

  private handleNavigationRowAction(row: SettingsDetailRowState): void {
    if (row.action === 'show_tab_overview_layout_sheet') {
      this.tabOverviewLayoutState = this.tabOverviewLayoutCoordinator.refreshDraft();
      this.tabStyleSheetKind = 'overview';
      this.tabStyleSheetVisible = true;
      return;
    }
    if (row.action === 'show_desktop_tab_placement_sheet') {
      if (!row.isEnabled || this.desktopTabPlacementSaving) {
        return;
      }
      this.desktopTabPlacement = this.resolveDesktopTabPlacement();
      this.tabStyleSheetKind = 'desktop';
      this.tabStyleSheetVisible = true;
      return;
    }
    this.onRowAction?.(row);
  }

  private resolveDesktopTabPlacement(): string {
    return sharedPreferencesRepository.getPreferences().appearance.verticalTabsEnabled === true ?
      'vertical' : 'horizontal';
  }

  private applyDesktopTabPlacement(placement: string): void {
    if (this.desktopTabPlacementSaving) {
      return;
    }
    const verticalTabsEnabled = placement === 'vertical';
    if (this.desktopTabPlacement === (verticalTabsEnabled ? 'vertical' : 'horizontal')) {
      this.tabStyleSheetVisible = false;
      return;
    }
    const current = sharedPreferencesRepository.getPreferences().appearance;
    this.desktopTabPlacementSaving = true;
    this.desktopTabPlacement = verticalTabsEnabled ? 'vertical' : 'horizontal';
    sharedPreferencesRepository.updateVerticalTabsPresentation(
      verticalTabsEnabled,
      current.verticalTabsCollapsed !== false
    ).then((): void => {
      syncBrowserThemeAppStorage();
      this.desktopTabPlacementSaving = false;
      this.tabStyleSheetVisible = false;
      this.onTabOverviewLayoutApplied?.();
    }).catch((): void => {
      this.desktopTabPlacement = this.resolveDesktopTabPlacement();
      this.desktopTabPlacementSaving = false;
    });
  }

  private applyTabOverviewLayoutDraft(): void {
    if (this.tabOverviewLayoutState.isSaving) {
      return;
    }
    const applyingState = this.tabOverviewLayoutCoordinator.beginApply(this.tabOverviewLayoutState);
    this.tabOverviewLayoutState = applyingState;
    this.tabOverviewLayoutCoordinator.apply(applyingState, this.buildBoundaryInput())
      .then((result: TabOverviewLayoutApplyResult) => {
        this.tabOverviewLayoutState = result.state;
        if (!result.succeeded) {
          return;
        }
        this.tabStyleSheetVisible = false;
        this.onTabOverviewLayoutApplied?.();
      });
  }

  private resolveGroupRenderKey(group: SettingsDetailGroupState): string {
    let key = `${this.resolveEffectiveThemeRenderKey()}_${this.renderVersion}_${group.id}_${group.footerText ?? ''}`;
    for (let index = 0; index < group.rows.length; index += 1) {
      key = `${key}_${this.resolveRowRenderKey(group.rows[index], group.id)}`;
    }
    const actionButtons = this.resolveGroupActionButtons(group);
    for (let index = 0; index < actionButtons.length; index += 1) {
      const button = actionButtons[index];
      key = `${key}_${this.resolveActionButtonRenderKey(button)}`;
    }
    return key;
  }

  private buildBoundaryInput(): BrowserDataBoundaryInput {
    return {
      dataScope: this.dataScope,
      privacyMode: this.privacyMode
    };
  }

  private localizeGeneralCopy(value: string): ResourceStr {
    if (this.state.id === 'general') {
      return localizeGeneralSettingsCopy(value);
    }
    if (this.state.id === 'appearance_toolbar') {
      return localizeAppearanceSettingsCopy(value);
    }
    if (this.state.id === 'private_mode') {
      return localizePrivacyModeSettingsCopy(value);
    }
    if (this.state.id === 'about') {
      return localizeAboutSettingsCopy(value);
    }
    if (this.state.id === 'privacy_security' || this.state.id === 'site_settings') {
      return localizePrivacyProtectionCopy(value);
    }
    if (this.state.id === 'advanced_settings' || this.state.id === 'app_service_mode') {
      return localizeAdvancedSettingsCopy(value);
    }
    if (this.state.id === 'experiments') {
      return localizeExperimentsSettingsCopy(value);
    }
    return value;
  }

  private localizeGeneralOptions(options: SettingsDetailOption[]): SettingsDetailOption[] {
    if (this.state.id !== 'general' && this.state.id !== 'appearance_toolbar' && this.state.id !== 'private_mode' &&
      this.state.id !== 'about' && this.state.id !== 'privacy_security' && this.state.id !== 'site_settings' &&
      this.state.id !== 'advanced_settings' && this.state.id !== 'app_service_mode' &&
      this.state.id !== 'experiments') {
      return options;
    }
    const localized: SettingsDetailOption[] = [];
    for (let index = 0; index < options.length; index += 1) {
      const option = options[index];
      const label = typeof option.label === 'string' ? this.localizeGeneralCopy(option.label) : option.label;
      localized.push({
        id: option.id,
        label: label,
        helperText: option.helperText,
        isSelected: option.isSelected,
        isEnabled: option.isEnabled
      });
    }
    return localized;
  }

  private resolveRowRenderKey(row: SettingsDetailRowState, groupId: string): string {
    const isInteractive = this.isRowInteractive(row);
    return `${this.resolveEffectiveThemeRenderKey()}_${this.renderVersion}_${groupId}_${row.id}_${row.checked ? '1' : '0'}_` +
      `${row.isSelected ? '1' : '0'}_${isInteractive ? '1' : '0'}_${row.value}_${row.valueSwatchColor}_` +
      `${row.helperText}`;
  }

  private resolveOptionRadioGroup(groupId: string): string {
    return `${this.state.id}_${groupId}`;
  }

  private resolveThemeModeCardRenderKey(row: SettingsDetailRowState, group: SettingsDetailGroupState): string {
    return `${this.resolveRowRenderKey(row, group.id)}_${this.isThemePreviewSelected(row, group) ? 'card-selected' : 'card-idle'}_` +
      `${this.storedResolvedThemeMode}`;
  }

  private resolveActionButtonRenderKey(button: SettingsDetailActionButtonState): string {
    return `${this.resolveEffectiveThemeRenderKey()}_${this.renderVersion}_${button.id}_` +
      `${button.isEnabled ? '1' : '0'}_${button.emphasis}_${button.title}`;
  }

  private resolveEffectiveThemeRenderKey(): string {
    if (this.themeRenderKey.length > 0) {
      return this.themeRenderKey;
    }
    return `${this.surfaceBackground}_${this.dividerColor}_${this.accentColor}_${this.onAccentColor}_` +
      `${this.pressedBackground}_${this.primaryTextColor}_${this.secondaryTextColor}`;
  }

  private isRowInteractive(row: SettingsDetailRowState): boolean {
    return row.isEnabled || row.action === 'open_app_icon_settings';
  }

  private shouldRenderThemeModePreview(group: SettingsDetailGroupState): boolean {
    return this.state.id === 'appearance_toolbar' && group.id === 'theme_mode';
  }

  private resolveThemeModePreviewRows(group: SettingsDetailGroupState): SettingsDetailRowState[] {
    const rows: SettingsDetailRowState[] = [];
    const lightRow = this.resolveThemeModeRow(group, 'light');
    const darkRow = this.resolveThemeModeRow(group, 'dark');
    if (lightRow !== undefined) {
      rows.push(lightRow);
    }
    if (darkRow !== undefined) {
      rows.push(darkRow);
    }
    return rows;
  }

  private resolveThemeModeSystemRows(group: SettingsDetailGroupState): SettingsDetailRowState[] {
    const systemRow = this.resolveThemeModeRow(group, 'system');
    if (systemRow === undefined) {
      return [];
    }
    return [systemRow];
  }

  private resolveThemeModeRow(
    group: SettingsDetailGroupState,
    mode: BrowserThemeMode
  ): SettingsDetailRowState | undefined {
    const action = this.resolveThemeModeAction(mode);
    return group.rows.find((row: SettingsDetailRowState) => row.action === action);
  }

  private isThemePreviewSelected(row: SettingsDetailRowState, group: SettingsDetailGroupState): boolean {
    const mode = this.resolveThemeModePreviewMode(row.action);
    const systemRow = this.resolveThemeModeRow(group, 'system');
    if (systemRow !== undefined && systemRow.isSelected && (mode === 'light' || mode === 'dark')) {
      return this.storedResolvedThemeMode === mode;
    }
    return row.isSelected;
  }

  private handleThemeSystemSwitchChange(
    group: SettingsDetailGroupState,
    systemRow: SettingsDetailRowState,
    checked: boolean
  ): void {
    if (checked) {
      this.onRowAction?.(systemRow);
      return;
    }
    const fallbackMode: BrowserThemeMode = this.storedResolvedThemeMode === 'dark' ? 'dark' : 'light';
    const fallbackRow = this.resolveThemeModeRow(group, fallbackMode);
    if (fallbackRow !== undefined) {
      this.onRowAction?.(fallbackRow);
    }
  }

  private resolveThemeModePreviewMode(action: SettingsDetailRowAction): BrowserThemeMode {
    return this.actionResolver.resolveThemeMode(action) ?? 'system';
  }

  private resolveThemeModeAction(mode: BrowserThemeMode): string {
    if (mode === 'light') {
      return 'set_theme_light';
    }
    if (mode === 'dark') {
      return 'set_theme_dark';
    }
    return 'set_theme_system';
  }

  private resolveRowPosition(index: number, count: number): 'single' | 'first' | 'middle' | 'last' {
    if (count <= 1) {
      return 'single';
    }
    if (index === 0) {
      return 'first';
    }
    if (index === count - 1) {
      return 'last';
    }
    return 'middle';
  }

}
