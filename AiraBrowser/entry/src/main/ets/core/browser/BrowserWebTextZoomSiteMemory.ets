import { BrowserWebTextZoomSiteMemoryRepository } from '../../data/web/BrowserWebTextZoomSiteMemoryRepository';
import { SiteIdentityService } from '../../services/web/SiteIdentityService';
import { BrowserWebTextZoomViewModel } from './BrowserWebTextZoomViewModel';

/**
 * Remembers a webpage text-size ratio for one site origin.
 * Pages without a saved ratio keep the current session ratio.
 */
export class BrowserWebTextZoomSiteMemory {
  private repository: BrowserWebTextZoomSiteMemoryRepository = new BrowserWebTextZoomSiteMemoryRepository();
  private identityService: SiteIdentityService = new SiteIdentityService();
  private zoomViewModel: BrowserWebTextZoomViewModel = new BrowserWebTextZoomViewModel();

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
    const ratio = this.repository.read(origin);
    if (ratio === undefined) {
      return undefined;
    }
    return this.zoomViewModel.normalizeRatio(ratio);
  }

  remember(origin: string, ratio: number): void {
    if (origin.length === 0) {
      return;
    }
    this.repository.remember(origin, this.zoomViewModel.normalizeRatio(ratio));
  }

  forget(origin: string): void {
    if (origin.length === 0) {
      return;
    }
    this.repository.forget(origin);
  }
}

export const sharedBrowserWebTextZoomSiteMemory: BrowserWebTextZoomSiteMemory = new BrowserWebTextZoomSiteMemory();
