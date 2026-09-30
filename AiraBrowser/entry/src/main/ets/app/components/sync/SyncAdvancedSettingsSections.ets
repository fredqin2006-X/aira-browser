import { AiraSyncRemoteKind } from '../../../common/models/AiraSyncModels';
import {
  SyncAdvancedProviderActionState,
  SyncAdvancedSettingsViewModel
} from '../../../core/sync/SyncAdvancedSettingsViewModel';
import { SettingsActionButton } from '../settings/SettingsRows';
import { SettingsSection } from '../settings/SettingsLayout';

@Component
export struct SyncAdvancedOperationsSection {
  @Prop mergeActionLabel: ResourceStr = '';
  @Prop actionState: SyncAdvancedProviderActionState = {
    showHuaweiCloud: false,
    showHuaweiSpace: false,
    showWebdav: false,
    mergeRequiresPro: false
  };
  @Prop isBusy: boolean = false;
  @Prop isPrivateSession: boolean = false;
  @Prop accentColor: ResourceColor = '';
  @Prop pressedBackgroundColor: ResourceColor = '';
  private viewModel: SyncAdvancedSettingsViewModel = new SyncAdvancedSettingsViewModel();
  onMerge?: () => void;
  onCheckProvider?: (remoteKind: AiraSyncRemoteKind) => void;
  onPushProvider?: (remoteKind: AiraSyncRemoteKind) => void;
  onPullProvider?: (remoteKind: AiraSyncRemoteKind) => void;

  build() {
    Column({ space: 16 }) {
      SettingsSection({ title: $r('app.string.settings_sync_advanced_merge_section') }) {
        this.buildActionButton(this.mergeActionLabel, () => {
          this.onMerge?.();
        }, false, this.actionState.mergeRequiresPro)
      }
      if (this.actionState.showHuaweiCloud) {
        this.buildProviderOperationSection('aira_cloud')
      }
      if (this.actionState.showHuaweiSpace) {
        this.buildProviderOperationSection('huawei_space')
      }
      if (this.actionState.showWebdav) {
        this.buildProviderOperationSection('webdav')
      }
    }
    .width('100%')
  }

  @Builder
  private buildProviderOperationSection(remoteKind: AiraSyncRemoteKind) {
    SettingsSection({ title: this.viewModel.resolveProviderSectionTitle(remoteKind) }) {
      this.buildActionButton(this.viewModel.resolveProviderCheckActionLabel(remoteKind), () => {
        this.onCheckProvider?.(remoteKind);
      })
      this.buildActionButton(this.viewModel.resolvePushActionLabel(remoteKind), () => {
        this.onPushProvider?.(remoteKind);
      })
      this.buildActionButton(this.viewModel.resolvePullActionLabel(remoteKind), () => {
        this.onPullProvider?.(remoteKind);
      }, true)
    }
  }

  @Builder
  private buildActionButton(
    label: ResourceStr,
    action: () => void,
    isDestructive: boolean = false,
    requiresPro: boolean = false
  ) {
    SettingsActionButton({
      title: label,
      emphasis: isDestructive ? 'danger' : 'primary',
      isEnabled: !this.isBusy && !this.isPrivateSession,
      membershipBadge: requiresPro ? 'pro' : 'none',
      accentColor: this.accentColor,
      pressedBackgroundColor: this.pressedBackgroundColor,
      onAction: action
    })
  }

}

@Component
export struct SyncAdvancedProviderSelectionSection {
  @Prop actionState: SyncAdvancedProviderActionState = {
    showHuaweiCloud: false,
    showHuaweiSpace: false,
    showWebdav: false,
    mergeRequiresPro: false
  };
  @Prop activeRemoteKind: AiraSyncRemoteKind = 'none';
  @Prop isBusy: boolean = false;
  @Prop isPrivateSession: boolean = false;
  @Prop accentColor: ResourceColor = '';
  @Prop pressedBackgroundColor: ResourceColor = '';
  private viewModel: SyncAdvancedSettingsViewModel = new SyncAdvancedSettingsViewModel();
  onSelectProvider?: (remoteKind: AiraSyncRemoteKind) => void;

  build() {
    Column() {
      if (this.countConfiguredProviders() > 1) {
        SettingsSection({ title: $r('app.string.settings_sync_advanced_current_method') }) {
          if (this.actionState.showHuaweiSpace) {
            this.buildProviderSwitchButtons('huawei_space')
          }
          if (this.actionState.showWebdav) {
            this.buildProviderSwitchButtons('webdav')
          }
          if (this.actionState.showHuaweiCloud) {
            this.buildProviderSwitchButtons('aira_cloud')
          }
        }
      }
    }
    .width('100%')
  }

  @Builder
  private buildActionButton(
    label: ResourceStr,
    remoteKind: AiraSyncRemoteKind
  ) {
    SettingsActionButton({
      title: this.activeRemoteKind === remoteKind
        ? this.viewModel.resolveCurrentSwitchActionLabel(remoteKind)
        : label,
      emphasis: 'primary',
      isEnabled: !this.isBusy && !this.isPrivateSession && this.activeRemoteKind !== remoteKind,
      accentColor: this.accentColor,
      pressedBackgroundColor: this.pressedBackgroundColor,
      onAction: () => {
        this.onSelectProvider?.(remoteKind);
      }
    })
  }

  @Builder
  private buildProviderSwitchButtons(remoteKind: AiraSyncRemoteKind) {
    this.buildActionButton(this.viewModel.resolveSwitchActionLabel(remoteKind), remoteKind)
  }

  private countConfiguredProviders(): number {
    let count = 0;
    if (this.actionState.showHuaweiCloud) {
      count++;
    }
    if (this.actionState.showHuaweiSpace) {
      count++;
    }
    if (this.actionState.showWebdav) {
      count++;
    }
    return count;
  }
}
