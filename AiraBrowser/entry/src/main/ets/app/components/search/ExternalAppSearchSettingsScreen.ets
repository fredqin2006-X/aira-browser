import {
  ExternalAppSearchTargetId
} from '../../../common/models/BrowserModels';
import { isPrivateBoundaryRoute } from '../../../common/utils/RouteParamUtils';
import { BrowserThemeViewState } from '../../../core/theme/BrowserThemeViewState';
import {
  ExternalAppSearchTarget
} from '../../../services/search/ExternalAppSearchService';
import { ExternalAppSearchTargetList } from './ExternalAppSearchTargetList';
import { SettingsHdsScaffold } from '../settings/SettingsHdsScaffold';
import {
  SettingsGroupCard,
  SettingsFooterText,
  SettingsPresentationScrollBody,
  SettingsSection
} from '../settings/SettingsLayout';
import { SettingsSwitchRow } from '../settings/SettingsRows';

@Component
export struct ExternalAppSearchSettingsScreen {
  @Prop featureEnabled: boolean = true;
  @Prop selectedTargetIds: ExternalAppSearchTargetId[] = [];
  @Prop targets: ExternalAppSearchTarget[] = [];
  @Prop dataScope: string = '';
  @Prop privacyMode: string = '';
  @Prop theme: BrowserThemeViewState;
  @Prop useTopSafeInset: boolean = true;
  @Prop desktopPresentation: boolean = false;
  onBack: () => void = () => {};
  onFeatureEnabledChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onTargetEnabledChange: (targetId: ExternalAppSearchTargetId, enabled: boolean) => void =
    (_targetId: ExternalAppSearchTargetId, _enabled: boolean) => {};
  onTargetOrderChange: (targetOrder: ExternalAppSearchTargetId[]) => void =
    (_targetOrder: ExternalAppSearchTargetId[]) => {};

  build() {
    SettingsHdsScaffold({
      title: $r('app.string.settings_search_engine_external_app'),
      backIconKind: 'back',
      pageBackground: this.theme.pageBackground,
      headerButtonBackground: this.theme.controlBackground,
      primaryTextColor: this.theme.textPrimary,
      dividerColor: this.theme.divider,
      showPrivateIndicator: isPrivateBoundaryRoute(this.dataScope, this.privacyMode),
      showBackButton: !this.desktopPresentation,
      showTitleBar: !this.desktopPresentation,
      useTopSafeInset: this.useTopSafeInset,
      desktopPresentation: this.desktopPresentation,
      onBack: () => {
        this.onBack();
      }
    }) {
      SettingsPresentationScrollBody({
        contentSpace: 18,
        desktopPresentation: this.desktopPresentation,
        topPadding: 16,
        bottomPadding: 32
      }) {
        this.buildMasterSection()
        this.buildTargetSection()
      }
    }
  }

  @Builder
  private buildMasterSection() {
    SettingsSection({
      title: $r('app.string.settings_search_engine_external_feature'),
      secondaryTextColor: this.theme.textSecondary
    }) {
      SettingsGroupCard({
        surfaceColor: this.theme.surfaceBackground,
        desktopPresentation: this.desktopPresentation
      }) {
        SettingsSwitchRow({
          title: $r('app.string.settings_search_engine_external_show_entries'),
          desktopPresentation: this.desktopPresentation,
          checked: this.featureEnabled,
          primaryTextColor: this.theme.textPrimary,
          secondaryTextColor: this.theme.textSecondary,
          pressedBackgroundColor: this.theme.pressedBackground,
          rowPosition: 'single',
          onChange: (enabled: boolean) => {
            this.onFeatureEnabledChange(enabled);
          }
        })
      }
      SettingsFooterText({
        text: $r('app.string.settings_search_engine_external_show_note'),
        secondaryTextColor: this.theme.textSecondary
      })
    }
  }

  @Builder
  private buildTargetSection() {
    SettingsSection({
      title: $r('app.string.settings_search_engine_external_shown_apps'),
      secondaryTextColor: this.theme.textSecondary
    }) {
      ExternalAppSearchTargetList({
        featureEnabled: this.featureEnabled,
        selectedTargetIds: this.selectedTargetIds,
        targets: this.targets,
        theme: this.theme,
        desktopPresentation: this.desktopPresentation,
        onTargetEnabledChange: (targetId: ExternalAppSearchTargetId, enabled: boolean) => {
          this.onTargetEnabledChange(targetId, enabled);
        },
        onTargetOrderChange: (targetOrder: ExternalAppSearchTargetId[]) => {
          this.onTargetOrderChange(targetOrder);
        }
      })
      SettingsFooterText({
        text: $r('app.string.settings_search_engine_external_reorder_note'),
        secondaryTextColor: this.theme.textSecondary
      })
    }
  }
}
