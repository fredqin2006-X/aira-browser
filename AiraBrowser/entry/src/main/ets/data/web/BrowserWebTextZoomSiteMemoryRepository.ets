import { preferences } from '@kit.ArkData';
import { AppRuntimeContext } from '../../app/runtime/AppRuntimeContext';

const PREFERENCES_NAME: string = 'aira_browser_web_text_zoom';
const SITE_RATIOS_KEY: string = 'site_ratios';

/**
 * Local origin-to-ratio map for webpage text size. It is not part of synced preferences:
 * remembering a site's text size should stay on this device.
 */
export class BrowserWebTextZoomSiteMemoryRepository {
  private store?: preferences.Preferences;
  private ratios: Record<string, number> = {};
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
      this.ratios = this.parseRatios(store.getSync(SITE_RATIOS_KEY, '{}'));
      this.loaded = true;
    } catch (_error) {
      this.loaded = false;
    }
  }

  read(origin: string): number | undefined {
    this.ensureLoaded();
    const ratio = this.ratios[origin];
    return typeof ratio === 'number' ? ratio : undefined;
  }

  remember(origin: string, ratio: number): void {
    this.ensureLoaded();
    if (this.ratios[origin] === ratio) {
      return;
    }
    this.ratios[origin] = ratio;
    this.persist();
  }

  forget(origin: string): void {
    this.ensureLoaded();
    if (this.ratios[origin] === undefined) {
      return;
    }
    const next: Record<string, number> = {};
    const origins = Object.keys(this.ratios);
    for (let index = 0; index < origins.length; index += 1) {
      const key = origins[index];
      if (key === origin) {
        continue;
      }
      next[key] = this.ratios[key];
    }
    this.ratios = next;
    this.persist();
  }

  private persist(): void {
    const store = this.store;
    if (store === undefined) {
      return;
    }
    try {
      store.putSync(SITE_RATIOS_KEY, JSON.stringify(this.ratios));
      void store.flush();
    } catch (_error) {
    }
  }

  private parseRatios(value: preferences.ValueType): Record<string, number> {
    if (typeof value !== 'string' || value.length === 0) {
      return {};
    }
    try {
      const parsed = JSON.parse(value) as Record<string, number>;
      const ratios: Record<string, number> = {};
      const origins = Object.keys(parsed);
      for (let index = 0; index < origins.length; index += 1) {
        const origin = origins[index];
        const ratio = parsed[origin];
        if (origin.length > 0 && typeof ratio === 'number' && Number.isFinite(ratio)) {
          ratios[origin] = ratio;
        }
      }
      return ratios;
    } catch (_error) {
      return {};
    }
  }
}
