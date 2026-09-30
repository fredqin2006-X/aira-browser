import { HistorySiteAggregate } from '../../common/models/BrowserModels';
import { HistoryFeature, HistoryManagementBoundary } from './HistoryFeature';

export interface HistorySitePageStatus {
  loading: boolean;
  error: ResourceStr;
}

// One bounded query context per screen. The UI owns presentation, while this
// owner serializes first-page/pagination work and rejects stale results.
export class HistorySitePageController {
  private sequence: number = 0;
  private query: string = '';
  private offset: number = 0;
  private hasMore: boolean = false;
  private initialized: boolean = false;
  private loading: boolean = false;
  private revision: number = -1;
  private mutationCount: number = 0;
  private deferredLimit: number = 0;
  private deferredBoundary?: HistoryManagementBoundary;
  private deferredPublish?: (sites: HistorySiteAggregate[], append: boolean) => void;
  private statusListener?: (status: HistorySitePageStatus) => void;

  private feature: HistoryFeature;

  constructor(feature: HistoryFeature) {
    this.feature = feature;
  }

  setStatusListener(listener?: (status: HistorySitePageStatus) => void): void {
    this.statusListener = listener;
  }

  canReuse(query: string): boolean {
    return this.initialized && this.query === query.trim() && this.revision >= 0 &&
      this.revision === this.feature.getDataRevision() && !this.feature.isMutationPending() &&
      this.mutationCount === 0;
  }

  cancel(): void {
    this.sequence += 1;
    this.setStatus(false, '');
  }

  invalidate(): void {
    this.cancel();
    this.initialized = false;
    this.revision = -1;
  }

  beginMutation(): void {
    this.mutationCount += 1;
    this.invalidate();
  }

  finishMutation(): void {
    this.mutationCount = Math.max(0, this.mutationCount - 1);
    if (this.mutationCount === 0 && this.deferredPublish !== undefined &&
      this.deferredBoundary !== undefined) {
      const limit = this.deferredLimit;
      const boundary = this.deferredBoundary;
      const publish = this.deferredPublish;
      this.deferredLimit = 0;
      this.deferredBoundary = undefined;
      this.deferredPublish = undefined;
      this.loadPage(limit, boundary, false, publish);
    }
  }

  loadFirstPage(
    query: string,
    limit: number,
    boundary: HistoryManagementBoundary,
    publish: (sites: HistorySiteAggregate[], append: boolean) => void
  ): void {
    this.invalidate();
    this.query = query.trim();
    this.offset = 0;
    this.hasMore = false;
    if (this.mutationCount > 0) {
      this.deferredLimit = limit;
      this.deferredBoundary = boundary;
      this.deferredPublish = publish;
      this.setStatus(true, '');
      return;
    }
    this.loadPage(limit, boundary, false, publish);
  }

  loadNextPage(
    limit: number,
    boundary: HistoryManagementBoundary,
    publish: (sites: HistorySiteAggregate[], append: boolean) => void
  ): void {
    if (this.loading || this.mutationCount > 0 || !this.initialized || !this.hasMore) {
      return;
    }
    if (!this.canReuse(this.query)) {
      this.loadFirstPage(this.query, limit, boundary, publish);
      return;
    }
    this.loadPage(limit, boundary, true, publish);
  }

  private loadPage(
    limit: number,
    boundary: HistoryManagementBoundary,
    append: boolean,
    publish: (sites: HistorySiteAggregate[], append: boolean) => void
  ): void {
    const sequence = ++this.sequence;
    const revision = this.feature.getDataRevision();
    const startedDuringMutation = this.feature.isMutationPending();
    this.setStatus(true, '');
    this.feature.refreshSitePageForManagement(this.query, this.offset, limit, boundary)
      .then((sites: HistorySiteAggregate[]) => {
        if (sequence !== this.sequence) {
          return;
        }
        if (startedDuringMutation || this.feature.isMutationPending() ||
          revision !== this.feature.getDataRevision()) {
          this.initialized = false;
          this.setStatus(false, $r('app.string.history_stale'));
          return;
        }
        this.offset += sites.length;
        this.hasMore = sites.length >= limit;
        this.initialized = true;
        this.revision = revision;
        publish(sites, append);
        this.setStatus(false, '');
      })
      .catch((_error: Error) => {
        if (sequence === this.sequence) {
          this.setStatus(false, $r('app.string.history_load_sites_failed'));
        }
      });
  }

  private setStatus(loading: boolean, error: ResourceStr): void {
    this.loading = loading;
    this.statusListener?.({ loading: loading, error: error });
  }
}
