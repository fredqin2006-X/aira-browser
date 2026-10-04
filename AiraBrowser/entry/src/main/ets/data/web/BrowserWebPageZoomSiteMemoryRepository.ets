import { preferences } from '@kit.ArkData';
import { AppRuntimeContext } from '../../app/runtime/AppRuntimeContext';

const PREFERENCES_NAME: string = 'aira_browser_web_page_zoom';
const SITE_PERCENTS_KEY: string = 'site_percents';

/**
 * Local origin-to-percent map for whole-page zoom. It stays on this device and is not synced.
 */
export class BrowserWebPageZoomSiteMemoryRepository {
  private store?: preferences.Preferences;
  private percents: Record<string, number> = {};
  private loaded: boolean = false;

  ensureLoaded(): void {
    if (this.loaded || !AppRuntimeContext.hasApplicationContext()) {
      return;
    }
    try {
      const store = preferences.getPreferencesSync(
        AppRuntimeContext.getApplicationContext(),
        { name: PREFERENCES_NAME }
      );
      this.store = store;
      this.percents = this.parsePercents(store.getSync(SITE_PERCENTS_KEY, '{}'));
      this.loaded = true;
    } catch (_error) {
      this.loaded = false;
    }
  }

  read(origin: string): number | undefined {
    this.ensureLoaded();
    const percent = this.percents[origin];
    return typeof percent === 'number' ? percent : undefined;
  }

  remember(origin: string, percent: number): void {
    this.ensureLoaded();
    if (this.percents[origin] === percent) {
      return;
    }
    this.percents[origin] = percent;
    this.persist();
  }

  forget(origin: string): void {
    this.ensureLoaded();
    if (this.percents[origin] === undefined) {
      return;
    }
    const next: Record<string, number> = {};
    const origins = Object.keys(this.percents);
    for (let index = 0; index < origins.length; index += 1) {
      const key = origins[index];
      if (key === origin) {
        continue;
      }
      next[key] = this.percents[key];
    }
    this.percents = next;
    this.persist();
  }

  private persist(): void {
    const store = this.store;
    if (store === undefined) {
      return;
    }
    try {
      store.putSync(SITE_PERCENTS_KEY, JSON.stringify(this.percents));
      void store.flush();
    } catch (_error) {
    }
  }

  private parsePercents(value: preferences.ValueType): Record<string, number> {
    if (typeof value !== 'string' || value.length === 0) {
      return {};
    }
    try {
      const parsed = JSON.parse(value) as Record<string, number>;
      const percents: Record<string, number> = {};
      const origins = Object.keys(parsed);
      for (let index = 0; index < origins.length; index += 1) {
        const origin = origins[index];
        const percent = parsed[origin];
        if (origin.length > 0 && typeof percent === 'number' && Number.isFinite(percent)) {
          percents[origin] = percent;
        }
      }
      return percents;
    } catch (_error) {
      return {};
    }
  }
}
