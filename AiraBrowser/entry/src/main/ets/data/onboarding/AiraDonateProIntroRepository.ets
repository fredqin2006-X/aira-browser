import { preferences } from '@kit.ArkData';
import { AppRuntimeContext } from '../../app/runtime/AppRuntimeContext';

const PREFERENCES_NAME: string = 'aira_donate_pro_intro';
const SHOWN_AT_KEY: string = 'shown_at';

/**
 * Device-local memory for the one-time 捐赠Pro explanation. It records only that
 * this device already opened the membership page. It does not grant, purchase,
 * or claim anything.
 */
export class AiraDonateProIntroRepository {
  private store?: preferences.Preferences;
  private storePromise?: Promise<preferences.Preferences>;
  private shownAt: number = 0;

  async initialize(): Promise<void> {
    const store = await this.requireStore();
    const raw = await store.get(SHOWN_AT_KEY, 0);
    this.shownAt = typeof raw === 'number' && raw > 0 ? raw : 0;
  }

  hasShown(): boolean {
    return this.shownAt > 0;
  }

  async markShown(now: number = Date.now()): Promise<void> {
    if (this.shownAt > 0) {
      return;
    }
    this.shownAt = now;
    const store = await this.requireStore();
    await store.put(SHOWN_AT_KEY, now);
    await store.flush();
  }

  private async requireStore(): Promise<preferences.Preferences> {
    if (this.store !== undefined) {
      return this.store;
    }
    if (this.storePromise === undefined) {
      this.storePromise = preferences.getPreferences(AppRuntimeContext.getApplicationContext(), PREFERENCES_NAME);
    }
    this.store = await this.storePromise;
    return this.store;
  }
}
