import {
  PersonalizationSyncConfig,
  PersonalizationSyncContentId,
  PersonalizationSyncItemId
} from '../../common/models/PersonalizationSyncModels';
import { BrowserSettingsIconBackgroundTokenSet } from '../../features/theme/BrowserThemePaletteModels';

export type PersonalizationSyncItemIconKey =
  | 'custom_homepage'
  | 'appearance'
  | 'activity_heatmap'
  | 'search'
  | 'bookshelf';

type PersonalizationSyncItemBackgroundRole =
  | 'homeShortcuts'
  | 'appearance'
  | 'activityHeatmap'
  | 'search'
  | 'novelBookshelf'
  | 'general';

interface PersonalizationSyncItemPresentationDescriptor {
  iconKey: PersonalizationSyncItemIconKey;
  backgroundRole: PersonalizationSyncItemBackgroundRole;
}

export interface PersonalizationSyncItemState {
  id: PersonalizationSyncContentId;
  title: ResourceStr;
  summary: ResourceStr;
  enabled: boolean;
}

export interface PersonalizationSyncSettingsState {
  title: ResourceStr;
  summary: ResourceStr;
  items: PersonalizationSyncItemState[];
}

export class PersonalizationSyncSettingsViewModel {
  buildDefaultState(
    config?: PersonalizationSyncConfig,
    novelBookshelfEnabled: boolean = true
  ): PersonalizationSyncSettingsState {
    return {
      title: $r('app.string.settings_sync_personalization_title'),
      summary: $r('app.string.settings_sync_personalization_summary'),
      items: [
        {
          id: 'home_shortcuts',
          title: $r('app.string.settings_sync_home_favorites'),
          summary: $r('app.string.settings_sync_home_favorites_summary'),
          enabled: this.resolveEnabled(config, 'home_shortcuts')
        },
        {
          id: 'core_preferences',
          title: $r('app.string.settings_sync_core_prefs'),
          summary: $r('app.string.settings_sync_core_prefs_summary'),
          enabled: this.resolveEnabled(config, 'core_preferences')
        },
        {
          id: 'activity_heatmap',
          title: $r('app.string.settings_sync_activity'),
          summary: $r('app.string.settings_sync_activity_summary'),
          enabled: this.resolveEnabled(config, 'activity_heatmap')
        },
        {
          id: 'search',
          title: $r('app.string.settings_sync_search'),
          summary: $r('app.string.settings_sync_search_summary'),
          enabled: this.resolveEnabled(config, 'search')
        },
        {
          id: 'novel_bookshelf',
          title: $r('app.string.settings_sync_bookshelf'),
          summary: $r('app.string.settings_sync_bookshelf_summary'),
          enabled: novelBookshelfEnabled
        }
      ]
    };
  }

  updateItemEnabled(
    state: PersonalizationSyncSettingsState,
    id: PersonalizationSyncContentId,
    enabled: boolean
  ): PersonalizationSyncSettingsState {
    return {
      title: state.title,
      summary: state.summary,
      items: state.items.map((item: PersonalizationSyncItemState): PersonalizationSyncItemState => {
        if (item.id !== id) {
          return {
            id: item.id,
            title: item.title,
            summary: item.summary,
            enabled: item.enabled
          };
        }
        return {
          id: item.id,
          title: item.title,
          summary: item.summary,
          enabled: enabled
        };
      })
    };
  }

  resolveItemIconKey(id: PersonalizationSyncContentId): PersonalizationSyncItemIconKey {
    return this.resolveItemPresentation(id).iconKey;
  }

  resolveItemIconBackgroundColor(
    id: PersonalizationSyncContentId,
    tokens: BrowserSettingsIconBackgroundTokenSet
  ): string {
    const role = this.resolveItemPresentation(id).backgroundRole;
    if (role === 'homeShortcuts') {
      return tokens.homeShortcuts;
    }
    if (role === 'appearance') {
      return tokens.appearance;
    }
    if (role === 'activityHeatmap') {
      return tokens.activityHeatmap;
    }
    if (role === 'search') {
      return tokens.search;
    }
    if (role === 'novelBookshelf') {
      return tokens.novelBookshelf;
    }
    return tokens.general;
  }

  resolveRowPosition(index: number, count: number): 'single' | 'first' | 'middle' | 'last' {
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

  private resolveEnabled(config: PersonalizationSyncConfig | undefined, id: PersonalizationSyncItemId): boolean {
    const item = config?.items.find((value) => value.id === id);
    return item === undefined ? true : item.enabled;
  }

  private resolveItemPresentation(id: PersonalizationSyncContentId): PersonalizationSyncItemPresentationDescriptor {
    if (id === 'home_shortcuts') {
      return { iconKey: 'custom_homepage', backgroundRole: 'homeShortcuts' };
    }
    if (id === 'core_preferences') {
      return { iconKey: 'appearance', backgroundRole: 'appearance' };
    }
    if (id === 'activity_heatmap') {
      return { iconKey: 'activity_heatmap', backgroundRole: 'activityHeatmap' };
    }
    if (id === 'search') {
      return { iconKey: 'search', backgroundRole: 'search' };
    }
    if (id === 'novel_bookshelf') {
      return { iconKey: 'bookshelf', backgroundRole: 'novelBookshelf' };
    }
    return { iconKey: 'custom_homepage', backgroundRole: 'general' };
  }
}
