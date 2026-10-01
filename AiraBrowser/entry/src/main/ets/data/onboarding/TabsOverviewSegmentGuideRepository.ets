import { preferences } from '@kit.ArkData';
import { AppRuntimeContext } from '../../app/runtime/AppRuntimeContext';

const PREFERENCES_NAME: string = 'aira_tabs_overview_segment_guide';
const STATE_KEY: string = 'state_v1';

/**
 * Device-local memory for the one-time tab-overview segment lesson. Only a
 * finished walk is recorded. Leaving halfway does not spend the lesson.
 */
export interface TabsOverviewSegmentGuideState {
  completedAt: number;
}

export function buildEmptyTabsOverviewSegmentGuideState(): TabsOverviewSegmentGuideState {
  return {
    completedAt: 0
  };
}

export class TabsOverviewSegmentGuideRepository {
  private store?: preferences.Preferences;
  private storePromise?: Promise<preferences.Preferences>;
  private state: TabsOverviewSegmentGuideState = buildEmptyTabsOverviewSegmentGuideState();
  private ready: boolean = false;

  async initialize(): Promise<void> {
    if (this.ready) {
      return;
    }
    const store = await this.getStore();
    this.state = this.normalizeState(store.getSync(STATE_KEY, '{}'));
    this.ready = true;
  }

  hasCompleted(): boolean {
    return this.state.completedAt > 0;
  }

  async markCompleted(now: number = Date.now()): Promise<TabsOverviewSegmentGuideState> {
    if (this.state.completedAt <= 0) {
      this.state = {
        completedAt: Math.max(0, Math.floor(now))
      };
      await this.persist();
    }
    return this.getState();
  }

  getState(): TabsOverviewSegmentGuideState {
    return {
      completedAt: this.state.completedAt
    };
  }

  private async persist(): Promise<void> {
    const store = await this.getStore();
    store.putSync(STATE_KEY, JSON.stringify(this.state));
    store.flushSync();
  }

  private normalizeState(value: preferences.ValueType): TabsOverviewSegmentGuideState {
    const raw = String(value ?? '').trim();
    if (raw.length === 0) {
      return buildEmptyTabsOverviewSegmentGuideState();
    }
    try {
      const parsed = JSON.parse(raw) as Record<string, number | undefined> | undefined;
      return {
        completedAt: this.normalizeTimestamp(parsed?.completedAt)
      };
    } catch (_error) {
      return buildEmptyTabsOverviewSegmentGuideState();
    }
  }

  private normalizeTimestamp(value: number | undefined): number {
    if (typeof value !== 'number' || !Number.isFinite(value)) {
      return 0;
    }
    return Math.max(0, Math.floor(value));
  }

  private async getStore(): Promise<preferences.Preferences> {
    if (this.store !== undefined) {
      return this.store;
    }
    if (this.storePromise === undefined) {
      this.storePromise = preferences.getPreferences(AppRuntimeContext.getApplicationContext(), PREFERENCES_NAME)
        .then((store: preferences.Preferences): preferences.Preferences => {
          this.store = store;
          return store;
        });
    }
    return this.storePromise;
  }
}
