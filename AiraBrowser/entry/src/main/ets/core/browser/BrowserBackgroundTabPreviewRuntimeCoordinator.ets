import { webview } from '@kit.ArkWeb';
import { TabRuntimeState } from '../../common/models/BrowserModels';
import { BrowserTabState } from '../tabs/TabManager';
import { WebTabRuntimeRecord } from '../web/WebTabRuntime';
import { BrowserHostedWebNodeDisposeReason } from './BrowserRuntimeActionReason';
import { BrowserWebHostAttachState } from './BrowserWebHostCoordinator';
import {
  BrowserBackgroundTabPreviewCoordinator,
  BrowserBackgroundTabPreviewFinishReason,
  BrowserBackgroundTabPreviewRequest
} from './BrowserBackgroundTabPreviewCoordinator';

export interface BrowserBackgroundTabPreviewRuntimeHost {
  resolveTab: (tabId: string) => BrowserTabState | undefined;
  getActiveTabId: () => string;
  getPreviewHostedTabId: () => string;
  hasUsablePreview: (tabId: string) => boolean;
  markBackgroundHot: (
    tabId: string,
    maxCount: number,
    releaseReason: BrowserHostedWebNodeDisposeReason
  ) => void;
  refreshRuntime: (tab: BrowserTabState, tabIdWhenMissing: string) => WebTabRuntimeRecord | undefined;
  markControllerAttached: (tabId: string) => WebTabRuntimeRecord | undefined;
  applyUserAgent: (tabId: string, controller?: webview.WebviewController) => void;
  syncPreview: (tab: BrowserTabState, runtime: WebTabRuntimeRecord) => BrowserWebHostAttachState;
  isHostedControllerAttached: (tabId: string) => boolean;
  capturePreview: (tabId: string) => Promise<boolean>;
  applyBackgroundPreviewRuntimeState: (tabId: string, runtimeState: TabRuntimeState) => void;
  loadUrl: (request: BrowserBackgroundTabPreviewRequest) => boolean;
  releaseBackgroundHot: (tabId: string, releaseReason: BrowserHostedWebNodeDisposeReason) => void;
  recordRuntimeEvent: (type: string, message: string, tabId: string) => void;
}

export interface BrowserBackgroundTabPreviewRuntimeOptions {
  maxBackgroundHotTabCount: number;
  maxAttachAttempts: number;
  attachRetryDelayMs: number;
}

export class BrowserBackgroundTabPreviewRuntimeCoordinator {
  private readonly previewCoordinator: BrowserBackgroundTabPreviewCoordinator;
  private readonly host: BrowserBackgroundTabPreviewRuntimeHost;
  private readonly options: BrowserBackgroundTabPreviewRuntimeOptions;
  private loadIssuedTabIds: string[] = [];
  private timeoutTimer: number = -1;

  constructor(
    host: BrowserBackgroundTabPreviewRuntimeHost,
    options: BrowserBackgroundTabPreviewRuntimeOptions,
    previewCoordinator: BrowserBackgroundTabPreviewCoordinator = new BrowserBackgroundTabPreviewCoordinator()
  ) {
    this.previewCoordinator = previewCoordinator;
    this.host = host;
    this.options = options;
  }

  getActiveRequestTabId(): string {
    return this.previewCoordinator.getActiveRequest()?.tabId ?? '';
  }

  shouldTreatProgressAsPageReady(progress: number): boolean {
    return this.previewCoordinator.shouldTreatProgressAsPageReady(progress);
  }

  shouldFinishForActiveTabChange(activeTabId: string): boolean {
    return this.previewCoordinator.shouldFinishForActiveTabChange(activeTabId);
  }

  cancelRequestsOnly(): void {
    this.previewCoordinator.cancelAll();
  }

  removeLoadIssued(tabId: string): void {
    this.loadIssuedTabIds = this.loadIssuedTabIds
      .filter((issuedTabId: string) => issuedTabId !== tabId);
  }

  clearCaptureTimers(): void {
    if (this.timeoutTimer >= 0) {
      clearTimeout(this.timeoutTimer);
      this.timeoutTimer = -1;
    }
  }

  scheduleCandidate(
    tabId: string,
    source: string
  ): void {
    // Background open has to load the hidden page, or the prompt stays at its 1% placeholder.
    // Do not snapshot that page: webPageSnapshot re-lays a detached document and stores a white card.
    const host = this.resolveHost();
    const options = this.resolveOptions();
    if (host === undefined || options === undefined) {
      return;
    }
    const tab = host.resolveTab(tabId);
    if (tab === undefined) {
      return;
    }
    const request = this.previewCoordinator.enqueueCandidate({
      tab: tab,
      activeTabId: host.getActiveTabId(),
      hasPreview: host.hasUsablePreview(tabId)
    });
    if (request === undefined || request.tabId !== tabId) {
      return;
    }
    host.recordRuntimeEvent('background_tab_preview_queued', `source=${source} url=${request.url}`, tabId);
    this.startIfNeeded();
  }

  startIfNeeded(): void {
    const host = this.resolveHost();
    const options = this.resolveOptions();
    if (host === undefined || options === undefined) {
      return;
    }
    const request = this.previewCoordinator.getActiveRequest();
    if (request === undefined || request.tabId === host.getPreviewHostedTabId()) {
      return;
    }
    const tab = host.resolveTab(request.tabId);
    if (tab === undefined) {
      this.finishPreview(request.tabId, 'tab_removed');
      return;
    }
    if (tab.id === host.getActiveTabId()) {
      this.finishPreview(request.tabId, 'tab_activated');
      return;
    }
    if (host.hasUsablePreview(request.tabId)) {
      this.finishPreview(request.tabId, 'preview_existing');
      return;
    }
    host.markBackgroundHot(request.tabId, options.maxBackgroundHotTabCount, 'background_preview_release');
    this.scheduleAttach(request.tabId, 0, 0);
  }

  attachIfReady(
    tabId: string,
    attempt: number
  ): void {
    const host = this.resolveHost();
    const options = this.resolveOptions();
    if (host === undefined || options === undefined) {
      return;
    }
    const request = this.previewCoordinator.getActiveRequest();
    if (request === undefined || request.tabId !== tabId) {
      return;
    }
    const tab = host.resolveTab(tabId);
    if (tab === undefined) {
      this.finishPreview(tabId, 'tab_removed');
      return;
    }
    if (tab.id === host.getActiveTabId()) {
      this.finishPreview(tabId, 'tab_activated');
      return;
    }
    const runtime = host.refreshRuntime(tab, tabId);
    if (runtime === undefined) {
      this.finishPreview(tabId, 'attach_failed');
      return;
    }
    const attachState = host.syncPreview(tab, runtime);
    if (!attachState.attached || !attachState.webControllerAttached) {
      host.recordRuntimeEvent('background_tab_preview_attach_pending', request.url, request.tabId);
      if (attempt < options.maxAttachAttempts) {
        this.scheduleAttach(tabId, attempt + 1, options.attachRetryDelayMs);
        return;
      }
      this.finishPreview(tabId, 'attach_failed');
      return;
    }
    this.continueAfterControllerAttached(tabId);
  }

  tryHandleControllerAttached(tabId: string): boolean {
    const host = this.resolveHost();
    if (host === undefined) {
      return false;
    }
    if (tabId === host.getActiveTabId() || tabId !== host.getPreviewHostedTabId()) {
      return false;
    }
    this.handleControllerAttached(tabId, host);
    return true;
  }

  private handleControllerAttached(tabId: string, host: BrowserBackgroundTabPreviewRuntimeHost): void {
    const runtime = host.markControllerAttached(tabId);
    host.applyUserAgent(tabId, runtime?.controller);
    host.recordRuntimeEvent('background_tab_preview_controller_attached', tabId, tabId);
    this.continueAfterControllerAttached(tabId);
  }

  continueAfterControllerAttached(tabId: string): void {
    const host = this.resolveHost();
    if (host === undefined) {
      return;
    }
    const request = this.previewCoordinator.getActiveRequest();
    if (request === undefined || request.tabId !== tabId || host.getPreviewHostedTabId() !== tabId) {
      return;
    }
    const tab = host.resolveTab(tabId);
    if (tab === undefined) {
      this.finishPreview(tabId, 'tab_removed');
      return;
    }
    if (tab.id === host.getActiveTabId()) {
      this.finishPreview(tabId, 'tab_activated');
      return;
    }
    if (this.hasLoadIssued(tabId)) {
      return;
    }
    if (!host.isHostedControllerAttached(tabId)) {
      host.recordRuntimeEvent('background_tab_preview_web_attach_pending', request.url, tabId);
      return;
    }
    this.markLoadIssued(tabId);
    this.applyBackgroundPreviewRuntimeState(request.tabId, 'background-hot', host);
    this.scheduleLoadTimeout(request);
    const issued = host.loadUrl(request);
    host.recordRuntimeEvent(
      issued ? 'background_tab_preview_load_issued' : 'background_tab_preview_load_failed',
      request.url,
      request.tabId
    );
    if (!issued) {
      this.finishPreview(request.tabId, 'load_failed');
    }
  }

  schedulePageReadyCapture(
    tabId: string,
    source: string
  ): void {
    const host = this.resolveHost();
    if (host === undefined) {
      return;
    }
    const request = this.previewCoordinator.getActiveRequest();
    if (request === undefined || request.tabId !== tabId) {
      return;
    }
    host.recordRuntimeEvent('background_tab_preview_load_ready', source, tabId);
    this.finishPreview(tabId, 'loaded');
  }

  finishPreview(
    tabId: string,
    reason: BrowserBackgroundTabPreviewFinishReason
  ): void {
    const host = this.resolveHost();
    const options = this.resolveOptions();
    if (host === undefined || options === undefined) {
      return;
    }
    if (host.getPreviewHostedTabId() === tabId) {
      this.clearCaptureTimers();
      this.applyBackgroundPreviewRuntimeState(tabId, 'background-hot', host);
    }
    this.removeLoadIssued(tabId);
    this.previewCoordinator.clearInitialCapture(tabId);
    const nextRequest = this.previewCoordinator.complete({
      tabId: tabId,
      reason: reason
    });
    host.recordRuntimeEvent('background_tab_preview_finished', `reason=${reason}`, tabId);
    if (reason === 'attach_failed' || reason === 'load_failed') {
      host.releaseBackgroundHot(tabId, 'background_preview_release');
    }
    if (nextRequest !== undefined && nextRequest.tabId !== tabId) {
      this.scheduleStart(0);
    }
  }

  cancelAll(source: string): void {
    const host = this.resolveHost();
    if (host === undefined) {
      return;
    }
    const request = this.previewCoordinator.getActiveRequest();
    this.clearCaptureTimers();
    const hostedTabId = host.getPreviewHostedTabId();
    if (hostedTabId.length > 0) {
      host.releaseBackgroundHot(hostedTabId, 'background_preview_release');
    }
    this.clearLoadIssued();
    this.previewCoordinator.cancelAll();
    if (request !== undefined) {
      host.recordRuntimeEvent('background_tab_preview_cancelled', source, request.tabId);
    }
  }

  private applyBackgroundPreviewRuntimeState(
    tabId: string,
    runtimeState: TabRuntimeState,
    host: BrowserBackgroundTabPreviewRuntimeHost
  ): void {
    const tab = host.resolveTab(tabId);
    if (tab === undefined || tab.id === host.getActiveTabId() || tab.isHome) {
      return;
    }
    host.applyBackgroundPreviewRuntimeState(tabId, runtimeState);
  }

  private scheduleLoadTimeout(request: BrowserBackgroundTabPreviewRequest): void {
    this.clearCaptureTimers();
    this.timeoutTimer = setTimeout(() => {
      this.timeoutTimer = -1;
      const activeRequest = this.previewCoordinator.getActiveRequest();
      if (activeRequest === undefined || activeRequest.tabId !== request.tabId) {
        return;
      }
      this.finishPreview(request.tabId, 'timeout');
    }, request.maxRuntimeMs);
  }

  private scheduleAttach(
    tabId: string,
    attempt: number,
    delayMs: number
  ): void {
    setTimeout(() => {
      this.attachIfReady(tabId, attempt);
    }, delayMs);
  }

  private scheduleStart(delayMs: number): void {
    setTimeout(() => {
      this.startIfNeeded();
    }, delayMs);
  }

  private resolveHost(): BrowserBackgroundTabPreviewRuntimeHost | undefined {
    return this.host;
  }

  private resolveOptions(): BrowserBackgroundTabPreviewRuntimeOptions | undefined {
    return this.options;
  }

  private hasLoadIssued(tabId: string): boolean {
    return this.loadIssuedTabIds.includes(tabId);
  }

  private markLoadIssued(tabId: string): void {
    if (tabId.trim().length <= 0 || this.loadIssuedTabIds.includes(tabId)) {
      return;
    }
    this.loadIssuedTabIds = this.loadIssuedTabIds.concat([tabId]);
  }

  private clearLoadIssued(): void {
    this.loadIssuedTabIds = [];
  }
}
