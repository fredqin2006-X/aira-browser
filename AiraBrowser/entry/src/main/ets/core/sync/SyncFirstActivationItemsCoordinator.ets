import {
  PersonalizationSyncContentId
} from '../../common/models/PersonalizationSyncModels';
import {
  SyncBookmarkActivationProvider
} from './SyncActivationModels';
import {
  PersonalizationSyncItemState,
  PersonalizationSyncSettingsViewModel
} from './PersonalizationSyncSettingsViewModel';

export type SyncFirstActivationItemId = 'bookmarks' | 'history' | PersonalizationSyncContentId;

export interface SyncFirstActivationItemState {
  id: SyncFirstActivationItemId;
  title: ResourceStr;
  summary: ResourceStr;
  enabled: boolean;
  kind: 'bookmarks' | 'history' | 'personalization';
}

export interface SyncFirstActivationItemsState {
  title: ResourceStr;
  summary: ResourceStr;
  items: SyncFirstActivationItemState[];
}

export class SyncFirstActivationItemsCoordinator {
  private personalizationViewModel: PersonalizationSyncSettingsViewModel = new PersonalizationSyncSettingsViewModel();

  buildDefaultState(bookmarkProvider: SyncBookmarkActivationProvider = 'aira_cloud'): SyncFirstActivationItemsState {
    const personalizationState = this.personalizationViewModel.buildDefaultState();
    const items: SyncFirstActivationItemState[] = [
      {
        id: 'bookmarks',
        title: $r('app.string.settings_sync_bookmarks'),
        summary: bookmarkProvider === 'huawei_space'
          ? $r('app.string.settings_sync_bookmarks_huawei_summary')
          : $r('app.string.settings_sync_bookmarks_summary'),
        enabled: true,
        kind: 'bookmarks'
      },
      {
        id: 'history',
        title: $r('app.string.settings_sync_history'),
        summary: $r('app.string.settings_sync_history_summary'),
        enabled: true,
        kind: 'history'
      }
    ];
    personalizationState.items.forEach((item: PersonalizationSyncItemState) => {
      items.push({
        id: item.id,
        title: item.title,
        summary: item.summary,
        enabled: item.enabled,
        kind: 'personalization'
      });
    });
    return {
      title: $r('app.string.settings_sync_choose_content_title'),
      summary: $r('app.string.settings_sync_choose_content_summary'),
      items: items
    };
  }

  buildStateFromExperience(
    bookmarkEnabled: boolean,
    historyEnabled: boolean,
    personalizationItems: PersonalizationSyncItemState[]
  ): SyncFirstActivationItemsState {
    const state = this.buildDefaultState();
    return {
      title: state.title,
      summary: state.summary,
      items: state.items.map((item: SyncFirstActivationItemState): SyncFirstActivationItemState => {
        if (item.id === 'bookmarks') {
          return {
            id: item.id,
            title: item.title,
            summary: item.summary,
            enabled: bookmarkEnabled,
            kind: item.kind
          };
        }
        if (item.id === 'history') {
          return {
            id: item.id,
            title: item.title,
            summary: item.summary,
            enabled: historyEnabled,
            kind: item.kind
          };
        }
        const savedItem = personalizationItems.find((value: PersonalizationSyncItemState): boolean => {
          return value.id === item.id;
        });
        return {
          id: item.id,
          title: item.title,
          summary: item.summary,
          enabled: savedItem?.enabled ?? item.enabled,
          kind: item.kind
        };
      })
    };
  }

  updateItemEnabled(
    state: SyncFirstActivationItemsState,
    id: SyncFirstActivationItemId,
    enabled: boolean
  ): SyncFirstActivationItemsState {
    return {
      title: state.title,
      summary: state.summary,
      items: state.items.map((item: SyncFirstActivationItemState): SyncFirstActivationItemState => {
        return {
          id: item.id,
          title: item.title,
          summary: item.summary,
          enabled: item.id === id ? enabled : item.enabled,
          kind: item.kind
        };
      })
    };
  }

  hasSelectedItems(state: SyncFirstActivationItemsState): boolean {
    return state.items.some((item: SyncFirstActivationItemState) => item.enabled);
  }

}
