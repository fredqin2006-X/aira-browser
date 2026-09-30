import { preferences } from '@kit.ArkData';
import { AppRuntimeContext } from '../../app/runtime/AppRuntimeContext';

const PREFERENCES_NAME: string = 'aira_cross_device_link_guide';
const STATE_KEY: string = 'state_v2';

/**
 * Device-local memory for the one-time 与电脑互联 lesson. It records only that
 * this device already opened the page, and that the user asked not to be told
 * again. Nothing here changes pairing, push, or tab presence. v1 was the centered
 * card preview and is ignored, so that preview does not spend the sheet.
 */
export interface CrossDeviceLinkGuideState {
  shownAt: number;
  completedAt: number;
}

export function buildEmptyCrossDeviceLinkGuideState(): CrossDeviceLinkGuideState {
  return {
    shownAt: 0,
    completedAt: 0
  };
}

export class CrossDeviceLinkGuideRepository {
  private store?: preferences.Preferences;
  private storePromise?: Promise<preferences.Preferences>;
  private state: CrossDeviceLinkGuideState = buildEmptyCrossDeviceLinkGuideState();

  async initialize(): Promise<void> {
    const store = await this.getStore();
    const raw = await store.get(STATE_KEY, '');
    this.state = this.parseState(typeof raw === 'string' ? raw : '');
  }

  getState(): CrossDeviceLinkGuideState {
    return {
      shownAt: this.state.shownAt,
      completedAt: this.state.completedAt
    };
  }

  hasCompleted(): boolean {
    return this.state.shownAt > 0 || this.state.completedAt > 0;
  }

  async markShown(now: number = Date.now()): Promise<CrossDeviceLinkGuideState> {
    if (this.state.shownAt <= 0) {
      this.state = {
        shownAt: now,
        completedAt: this.state.completedAt
      };
      await this.persist();
    }
    return this.getState();
  }

  async markCompleted(now: number = Date.now()): Promise<CrossDeviceLinkGuideState> {
    if (this.state.completedAt <= 0) {
      this.state = {
        shownAt: this.state.shownAt > 0 ? this.state.shownAt : now,
        completedAt: now
      };
      await this.persist();
    }
    return this.getState();
  }

  private async persist(): Promise<void> {
    const store = await this.getStore();
    await store.put(STATE_KEY, JSON.stringify(this.state));
    await store.flush();
  }

  private parseState(raw: string): CrossDeviceLinkGuideState {
    if (raw.length === 0) {
      return buildEmptyCrossDeviceLinkGuideState();
    }
    try {
      const parsed = JSON.parse(raw) as CrossDeviceLinkGuideState;
      return {
        shownAt: this.normalizeTimestamp(parsed?.shownAt),
        completedAt: this.normalizeTimestamp(parsed?.completedAt)
      };
    } catch (_error) {
      return buildEmptyCrossDeviceLinkGuideState();
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
