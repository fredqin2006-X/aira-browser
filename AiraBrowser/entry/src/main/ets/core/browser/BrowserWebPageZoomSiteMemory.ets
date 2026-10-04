import { BrowserWebPageZoomSiteMemoryRepository } from '../../data/web/BrowserWebPageZoomSiteMemoryRepository';
import { SiteIdentityService } from '../../services/web/SiteIdentityService';

const WEB_PAGE_ZOOM_DEFAULT_PERCENT: number = 100;
const WEB_PAGE_ZOOM_MIN_PERCENT: number = 25;
const WEB_PAGE_ZOOM_MAX_PERCENT: number = 500;

/**
 * Chrome-style page zoom memory: one percent per site origin.
 * 100% clears the site. There is no checkbox.
 */
export class BrowserWebPageZoomSiteMemory {
  private repository: BrowserWebPageZoomSiteMemoryRepository = new BrowserWebPageZoomSiteMemoryRepository();
  private identityService: SiteIdentityService = new SiteIdentityService();

  ensureLoaded(): void {
    this.repository.ensureLoaded();
  }

  resolveOrigin(url: string): string {
    return this.identityService.resolve(url).primaryOrigin;
  }

  read(origin: string): number | undefined {
    if (origin.length === 0) {
      return undefined;
    }
    const percent = this.repository.read(origin);
    if (percent === undefined) {
      return undefined;
    }
    return this.normalizePercent(percent);
  }

  commit(origin: string, percent: number): void {
    if (origin.length === 0) {
      return;
    }
    const normalized = this.normalizePercent(percent);
    if (normalized === undefined || normalized === WEB_PAGE_ZOOM_DEFAULT_PERCENT) {
      this.repository.forget(origin);
      return;
    }
    this.repository.remember(origin, normalized);
  }

  private normalizePercent(percent: number): number | undefined {
    if (!Number.isFinite(percent)) {
      return undefined;
    }
    const rounded = Math.round(percent);
    if (rounded < WEB_PAGE_ZOOM_MIN_PERCENT || rounded > WEB_PAGE_ZOOM_MAX_PERCENT) {
      return undefined;
    }
    return rounded;
  }
}

export const sharedBrowserWebPageZoomSiteMemory: BrowserWebPageZoomSiteMemory = new BrowserWebPageZoomSiteMemory();
