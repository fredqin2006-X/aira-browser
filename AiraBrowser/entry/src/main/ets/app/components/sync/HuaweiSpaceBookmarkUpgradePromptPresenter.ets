import { SyncExperienceCoordinator } from '../../../core/sync/SyncExperienceCoordinator';
import { showCenteredAlertDialog } from '../common/CenteredDialogSurface';
import { SettingsNavigationCoordinator } from '../../router/SettingsNavigationCoordinator';

export class HuaweiSpaceBookmarkUpgradePromptPresenter {
  private syncExperienceCoordinator: SyncExperienceCoordinator;
  private navigationCoordinator: SettingsNavigationCoordinator = new SettingsNavigationCoordinator();
  private presenting: boolean = false;

  constructor(syncExperienceCoordinator: SyncExperienceCoordinator) {
    this.syncExperienceCoordinator = syncExperienceCoordinator;
  }

  async presentIfNeeded(): Promise<void> {
    if (this.presenting) {
      return;
    }
    const state = await this.syncExperienceCoordinator.prepareHuaweiSpaceBookmarkUpgrade();
    if (!state.shouldPresent) {
      return;
    }
    this.presenting = true;
    try {
      showCenteredAlertDialog({
        title: $r('app.string.sync_ui_huawei_space_bookmark_upgrade_prompt_presenter_004'),
        message: $r('app.string.sync_ui_huawei_space_bookmark_upgrade_prompt_presenter_001'),
        autoCancel: false,
        primaryButton: {
          value: $r('app.string.sync_ui_huawei_space_bookmark_upgrade_prompt_presenter_003'),
          action: () => {
            this.presenting = false;
            void this.syncExperienceCoordinator.acknowledgeHuaweiSpaceBookmarkUpgradePrompt();
          }
        },
        secondaryButton: {
          value: $r('app.string.sync_ui_huawei_space_bookmark_upgrade_prompt_presenter_002'),
          action: () => {
            this.presenting = false;
            void this.syncExperienceCoordinator.acknowledgeHuaweiSpaceBookmarkUpgradePrompt()
              .finally((): void => {
                this.navigationCoordinator.openSyncSettings({
                  dataScope: 'profile_persistent',
                  privacyMode: 'regular',
                  boundarySource: 'huawei_space_bookmark_g6_upgrade'
                });
              });
          }
        }
      });
    } catch (error) {
      this.presenting = false;
      if (error instanceof Error) {
        throw error;
      }
      throw new Error(JSON.stringify(error));
    }
  }
}
