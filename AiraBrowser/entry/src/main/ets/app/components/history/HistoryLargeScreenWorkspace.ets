import { hasAppResourceText, resolveAppResourceText } from '../../../core/resources/AppResourceText';
import { localizeHistoryHost } from '../../../core/resources/HistoryBookmarkDisplayText';
import { pasteboard } from '@kit.BasicServicesKit';
import { showCenteredAlertDialog } from '../common/CenteredDialogSurface';
import { KeyCode } from '@kit.InputKit';
import {
  HistoryWorkspaceSessionCoordinator,
  HistoryWorkspaceSelectionMode,
  HistoryWorkspaceSnapshot,
  createEmptyHistoryWorkspaceSnapshot
} from '../../../core/history/HistoryWorkspaceSessionCoordinator';
import {
  HistoryDisplayVisit,
  HistorySiteGroup,
  HistoryViewMode
} from '../../../features/history/HistoryViewModel';
import { HistoryTimelineDataSource } from '../../../features/history/HistoryTimelineDataSource';
import {
  SiteIconListPresenter,
  SiteIconListRenderState,
  SiteIconListResolvedIcon,
  SiteIconListTarget
} from '../../../core/siteicons/SiteIconListPresenter';
import {
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { historyWorkspaceSessionRuntime } from '../../runtime/HistoryWorkspaceSessionRuntime';
import { HistoryFeature, HistoryManagementBoundary } from '../../../features/history/HistoryFeature';
import {
  sharedHistoryRepository,
  sharedPreferencesRepository,
  sharedRecentlyClosedTabRepository
} from '../../bootstrap/BrowserAppRuntime';
import { HISTORY_LARGE_SCREEN_SEARCH_FOCUS_KEY } from './HistoryLargeScreenHeader';
import {
  ManagementLargeScreenIconButton,
  ManagementLargeScreenNavItem,
  ManagementLargeScreenNavSection,
  ManagementLargeScreenShell,
  ManagementLargeScreenTextButton
} from '../common/ManagementLargeScreenShell';
import { HistoryLargeScreenTimeline } from './HistoryLargeScreenTimeline';
import { HistoryLargeScreenSites } from './HistoryLargeScreenSites';
import { AiraIcon } from '../common/AiraIcon';
import { DEFAULT_THEME_PALETTE } from '../../../features/theme/palettes/DefaultThemePalette';

const HISTORY_ROUTE_PUBLISH_DEBOUNCE_MS: number = 200;

@Component
export struct HistoryLargeScreenWorkspace {
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY)
  private storedPrimaryTextColor: string = DEFAULT_THEME_PALETTE.light.textPrimary;
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY)
  private storedSecondaryTextColor: string = DEFAULT_THEME_PALETTE.light.textSecondary;

  @Prop @Watch('handleSessionIdentityChanged') tabId: string = '';
  @Prop @Watch('handleRouteUrlChanged') routeUrl: string = '';
  @Prop @Watch('handleSessionIdentityChanged') privateMode: boolean = false;
  onRouteChange: (tabId: string, routeUrl: string) => void =
    (_tabId: string, _routeUrl: string): void => {};
  onOpenHistory: (url: string, title: string, openInNewTab: boolean) => void =
    (_url: string, _title: string, _openInNewTab: boolean): void => {};

  private coordinator: HistoryWorkspaceSessionCoordinator = new HistoryWorkspaceSessionCoordinator(
    new HistoryFeature(
      sharedHistoryRepository,
      sharedPreferencesRepository,
      sharedRecentlyClosedTabRepository
    ),
    new HistoryManagementBoundary('profile_persistent', 'regular')
  );
  private readonly timelineDataSource: HistoryTimelineDataSource = new HistoryTimelineDataSource();
  private readonly timelineScroller: ListScroller = new ListScroller();
  private readonly sitesScroller: ListScroller = new ListScroller();
  private readonly siteIconPresenter: SiteIconListPresenter = new SiteIconListPresenter();
  @State private snapshot: HistoryWorkspaceSnapshot = createEmptyHistoryWorkspaceSnapshot();
  @State private iconStates: SiteIconListRenderState[] = [];
  @State private shiftPressed: boolean = false;
  @State private controlPressed: boolean = false;
  private routePublishTimer: number = -1;
  private sessionBindingRevision: number = 0;
  private mounted: boolean = false;

  aboutToAppear(): void {
    this.mounted = true;
    this.siteIconPresenter.bindDomainUpdates(
      (): SiteIconListTarget[] => this.buildIconTargets(),
      (result: SiteIconListResolvedIcon): void => {
        this.applyResolvedIcon(result);
      }
    );
    void this.initialize();
  }

  aboutToDisappear(): void {
    this.captureScrollOffset();
    this.mounted = false;
    this.sessionBindingRevision += 1;
    this.cancelRoutePublish();
    this.siteIconPresenter.dispose();
  }

  build() {
    ManagementLargeScreenShell({
      title: this.resolveWorkspaceTitle(),
      badge: this.resolveWorkspaceBadge(),
      searchPlaceholder: $r('app.string.history_search'),
      searchQuery: this.snapshot.query,
      searchFocusKey: HISTORY_LARGE_SCREEN_SEARCH_FOCUS_KEY,
      onSearchChange: (query: string): void => {
        void this.updateQuery(query);
      },
      sidebar: (): void => {
        this.buildSidebar()
      },
      toolbarActions: (): void => {
        this.buildToolbarActions()
      },
      content: (): void => {
        this.buildWorkspaceContent()
      }
    })
    .width('100%')
    .height('100%')
    .focusable(true)
    .keyboardShortcut('f', [ModifierKey.CTRL], (): void => {
      this.focusSearch();
    })
    .keyboardShortcut('a', [ModifierKey.CTRL], (): void => {
      this.applySnapshot(this.coordinator.selectAll());
    })
    .onKeyEvent((event: KeyEvent): boolean => this.handleKeyEvent(event))
  }

  @Builder
  private buildSidebar() {
    ManagementLargeScreenNavSection({ title: $r('app.string.history_view_menu') })
    ManagementLargeScreenNavItem({
      title: $r('app.string.history_timeline'),
      selected: this.snapshot.viewMode === 'timeline' && this.snapshot.site.length === 0,
      iconId: 'browser.shortcut.history',
      onSelect: (): void => {
        void this.updateViewMode('timeline');
      }
    })
    ManagementLargeScreenNavItem({
      title: $r('app.string.history_by_site'),
      selected: this.snapshot.viewMode === 'sites',
      iconId: 'browser.toolbar.siteInfo',
      onSelect: (): void => {
        void this.updateViewMode('sites');
      }
    })
    if (this.snapshot.site.length > 0) {
      ManagementLargeScreenNavSection({ title: $r('app.string.history_current_site') })
      ManagementLargeScreenNavItem({
        title: this.snapshot.site,
        selected: true,
        showIcon: false,
        onSelect: (): void => {
        }
      })
    }
  }

  @Builder
  private buildToolbarActions() {
    if (this.snapshot.selectedVisitIds.length > 0) {
      ManagementLargeScreenTextButton({
        label: $r('app.string.ui_open'),
        isEnabled: !this.snapshot.busy,
        onAction: (): void => {
          this.confirmOpenSelection();
        }
      })
      ManagementLargeScreenTextButton({
        label: $r('app.string.settings_delete'),
        isEnabled: !this.snapshot.busy,
        onAction: (): void => {
          this.confirmDeleteSelection();
        }
      })
      ManagementLargeScreenTextButton({
        label: $r('app.string.ui_done'),
        onAction: (): void => {
          this.applySnapshot(this.coordinator.clearSelection());
        }
      })
    } else {
      if (this.snapshot.site.length > 0) {
        ManagementLargeScreenTextButton({
          label: $r('app.string.history_back_to_sites'),
          onAction: (): void => {
            void this.updateViewMode('sites');
          }
        })
      }
      ManagementLargeScreenIconButton({
        iconId: 'browser.tabs.delete',
        label: $r('app.string.history_clear_all'),
        isEnabled: !this.snapshot.busy && this.resolveVisibleItemCount() > 0,
        onAction: (): void => {
          this.confirmClearAll();
        }
      })
    }
  }

  @Builder
  private buildWorkspaceContent() {
    Column() {
      if (this.snapshot.loading && this.resolveVisibleItemCount() === 0) {
        this.buildLoadingState()
      } else if (this.resolveVisibleItemCount() === 0) {
        this.buildEmptyState()
      } else if (this.snapshot.viewMode === 'sites') {
        HistoryLargeScreenSites({
          sites: this.snapshot.sites,
          icons: this.iconStates,
          listScroller: this.sitesScroller,
          onOpenSite: (site: HistorySiteGroup): void => {
            void this.openSite(site);
          },
          onOpenLatest: (site: HistorySiteGroup, openInNewTab: boolean): void => {
            this.onOpenHistory(site.latestUrl, site.latestTitle, openInNewTab);
          },
          onCopyLink: (site: HistorySiteGroup): void => {
            this.copyLink(site.latestUrl);
          },
          onDeleteSite: (site: HistorySiteGroup): void => {
            this.confirmDeleteSite(site);
          },
          onReachEnd: (): void => {
            void this.loadNextPage();
          },
          onIconLoadError: (
            target: SiteIconListTarget,
            currentUri: string,
            sourceRevision: number
          ): void => {
            this.siteIconPresenter.resolvePixelMapAfterUriFailure(
              target,
              currentUri,
              sourceRevision,
              (result: SiteIconListResolvedIcon): void => this.applyResolvedIcon(result)
            );
          }
        })
      } else {
        HistoryLargeScreenTimeline({
          dataSource: this.timelineDataSource,
          listScroller: this.timelineScroller,
          icons: this.iconStates,
          selectedVisitIds: this.snapshot.selectedVisitIds,
          shiftPressed: this.shiftPressed,
          controlPressed: this.controlPressed,
          onOpenVisit: (visit: HistoryDisplayVisit, openInNewTab: boolean): void => {
            this.onOpenHistory(visit.url, visit.title, openInNewTab);
          },
          onSelectVisit: (visitId: string, mode: HistoryWorkspaceSelectionMode): void => {
            this.applySnapshot(this.coordinator.selectVisit(visitId, mode));
          },
          onDeleteVisit: (visit: HistoryDisplayVisit): void => {
            this.confirmDeleteVisit(visit);
          },
          onDeleteSelection: (): void => {
            this.confirmDeleteSelection();
          },
          onCopyLink: (visit: HistoryDisplayVisit): void => {
            this.copyLink(visit.url);
          },
          onReachEnd: (): void => {
            void this.loadNextPage();
          },
          onIconLoadError: (
            target: SiteIconListTarget,
            currentUri: string,
            sourceRevision: number
          ): void => {
            this.siteIconPresenter.resolvePixelMapAfterUriFailure(
              target,
              currentUri,
              sourceRevision,
              (result: SiteIconListResolvedIcon): void => {
                this.applyResolvedIcon(result);
              }
            );
          }
        })
      }

      if (hasAppResourceText(this.snapshot.message) && this.resolveVisibleItemCount() > 0) {
        Text(this.snapshot.message)
          .width('100%')
          .fontSize(12)
          .fontColor(this.storedSecondaryTextColor)
          .textAlign(TextAlign.Center)
          .padding({ top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildLoadingState() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(28)
        .height(28)
      Text($r('app.string.history_loading'))
        .fontSize(13)
        .fontColor(this.storedSecondaryTextColor)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildEmptyState() {
    Column({ space: 12 }) {
      AiraIcon({
        airaIconId: this.snapshot.query.length > 0 ? 'settings.search' : 'browser.shortcut.history',
        iconSize: 34,
        iconColor: this.storedSecondaryTextColor
      })
      Text(this.snapshot.query.length > 0 ? $r('app.string.history_no_match') : $r('app.string.history_empty'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.storedPrimaryTextColor)
      if (hasAppResourceText(this.snapshot.message)) {
        Text(this.snapshot.message)
          .constraintSize({ maxWidth: 480 })
          .fontSize(13)
          .lineHeight(19)
          .textAlign(TextAlign.Center)
          .fontColor(this.storedSecondaryTextColor)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  private async initialize(): Promise<void> {
    const normalizedTabId = this.tabId.trim();
    if (normalizedTabId.length === 0) {
      return;
    }
    const bindingRevision = ++this.sessionBindingRevision;
    this.coordinator = historyWorkspaceSessionRuntime.acquire(normalizedTabId, this.privateMode);
    const task = this.coordinator.activate(this.routeUrl);
    this.applySnapshot(this.coordinator.getSnapshot());
    const snapshot = await task;
    if (!this.isBindingCurrent(bindingRevision, normalizedTabId, this.coordinator)) {
      return;
    }
    this.applySnapshot(snapshot);
    this.publishRouteNow();
    this.restoreScrollOffset(bindingRevision, normalizedTabId, this.coordinator);
  }

  private handleSessionIdentityChanged(): void {
    this.cancelRoutePublish();
    this.iconStates = [];
    void this.initialize();
  }

  private handleRouteUrlChanged(): void {
    if (this.routeUrl.trim().length === 0 || this.routeUrl.trim() === this.snapshot.routeUrl) {
      return;
    }
    this.cancelRoutePublish();
    void this.applyExternalRoute(this.routeUrl);
  }

  private async applyExternalRoute(routeUrl: string): Promise<void> {
    const bindingRevision = this.sessionBindingRevision;
    const tabId = this.tabId.trim();
    const coordinator = this.coordinator;
    this.captureScrollOffset();
    const task = coordinator.applyRoute(routeUrl);
    this.applySnapshot(coordinator.getSnapshot());
    const snapshot = await task;
    if (!this.isBindingCurrent(bindingRevision, tabId, coordinator)) {
      return;
    }
    this.applySnapshot(snapshot);
    this.restoreScrollOffset(bindingRevision, tabId, coordinator);
  }

  private async updateQuery(query: string): Promise<void> {
    const bindingRevision = this.sessionBindingRevision;
    const tabId = this.tabId.trim();
    const coordinator = this.coordinator;
    const task = coordinator.setQuery(query);
    this.applySnapshot(coordinator.getSnapshot());
    this.scheduleRoutePublish();
    const snapshot = await task;
    if (!this.isBindingCurrent(bindingRevision, tabId, coordinator)) {
      return;
    }
    this.applySnapshot(snapshot);
    this.scheduleRoutePublish();
  }

  private async updateViewMode(viewMode: HistoryViewMode): Promise<void> {
    const bindingRevision = this.sessionBindingRevision;
    const tabId = this.tabId.trim();
    const coordinator = this.coordinator;
    this.captureScrollOffset();
    const task = coordinator.setViewMode(viewMode);
    this.applySnapshot(coordinator.getSnapshot());
    const snapshot = await task;
    if (!this.isBindingCurrent(bindingRevision, tabId, coordinator)) {
      return;
    }
    this.applySnapshot(snapshot);
    this.publishRouteNow();
    this.restoreScrollOffset(bindingRevision, tabId, coordinator);
  }

  private async openSite(site: HistorySiteGroup): Promise<void> {
    const bindingRevision = this.sessionBindingRevision;
    const tabId = this.tabId.trim();
    const coordinator = this.coordinator;
    this.captureScrollOffset();
    const task = coordinator.openSite(site);
    this.applySnapshot(coordinator.getSnapshot());
    const snapshot = await task;
    if (!this.isBindingCurrent(bindingRevision, tabId, coordinator)) {
      return;
    }
    this.applySnapshot(snapshot);
    this.publishRouteNow();
    this.restoreScrollOffset(bindingRevision, tabId, coordinator);
  }

  private async loadNextPage(): Promise<void> {
    const bindingRevision = this.sessionBindingRevision;
    const tabId = this.tabId.trim();
    const coordinator = this.coordinator;
    const task = coordinator.loadNextPage();
    this.applySnapshot(coordinator.getSnapshot());
    const snapshot = await task;
    if (this.isBindingCurrent(bindingRevision, tabId, coordinator)) {
      this.applySnapshot(snapshot);
    }
  }

  private applySnapshot(snapshot: HistoryWorkspaceSnapshot): void {
    this.snapshot = snapshot;
    this.timelineDataSource.replaceGroups(snapshot.groups);
    this.resolveIcons();
  }

  private resolveIcons(): void {
    this.siteIconPresenter.resolveTargets(
      this.buildIconTargets(),
      (result: SiteIconListResolvedIcon): void => {
        this.applyResolvedIcon(result);
      },
      {
        shouldSkipTarget: (target: SiteIconListTarget): boolean =>
          this.siteIconPresenter.hasResolvedIcon(this.iconStates, target)
      }
    );
  }

  private buildIconTargets(): SiteIconListTarget[] {
    if (this.snapshot.viewMode === 'sites') {
      return this.snapshot.sites.map((site: HistorySiteGroup): SiteIconListTarget => ({
        id: site.key,
        url: site.latestUrl,
        domain: site.host
      }));
    }
    return this.snapshot.visits.map((visit: HistoryDisplayVisit): SiteIconListTarget => {
      return {
        id: visit.id,
        url: visit.url,
        domain: visit.host
      };
    });
  }

  private applyResolvedIcon(result: SiteIconListResolvedIcon): void {
    this.iconStates = this.siteIconPresenter.applyResolvedIcon(this.iconStates, result);
  }

  private confirmDeleteVisit(visit: HistoryDisplayVisit): void {
    showCenteredAlertDialog({
      title: $r('app.string.history_delete_title'),
      message: $r('app.string.history_delete_one', visit.title),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.settings_account_cancel'),
        action: (): void => {}
      },
      secondaryButton: {
        value: $r('app.string.settings_delete'),
        fontColor: this.storedPrimaryTextColor,
        action: (): void => {
          void this.deleteVisit(visit.id);
        }
      }
    });
  }

  private confirmDeleteSelection(): void {
    const selectedCount = this.snapshot.selectedVisitIds.length;
    if (selectedCount <= 0) {
      return;
    }
    showCenteredAlertDialog({
      title: $r('app.string.history_delete_title'),
      message: $r('app.string.history_delete_many', selectedCount),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.settings_account_cancel'),
        action: (): void => {}
      },
      secondaryButton: {
        value: $r('app.string.settings_delete'),
        fontColor: this.storedPrimaryTextColor,
        action: (): void => {
          void this.deleteSelection();
        }
      }
    });
  }

  private confirmClearAll(): void {
    showCenteredAlertDialog({
      title: $r('app.string.history_clear_all'),
      message: $r('app.string.history_clear_confirm'),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.settings_account_cancel'),
        action: (): void => {}
      },
      secondaryButton: {
        value: $r('app.string.ui_clear'),
        fontColor: this.storedPrimaryTextColor,
        action: (): void => {
          void this.clearAll();
        }
      }
    });
  }

  private confirmDeleteSite(site: HistorySiteGroup): void {
    showCenteredAlertDialog({
      title: $r('app.string.history_delete_site_title'),
      message: $r('app.string.history_delete_site_confirm', resolveAppResourceText(localizeHistoryHost(site.host))),
      autoCancel: true,
      primaryButton: { value: $r('app.string.settings_account_cancel'), action: (): void => {} },
      secondaryButton: {
        value: $r('app.string.settings_delete'),
        fontColor: this.storedPrimaryTextColor,
        action: (): void => {
          void this.deleteSite(site.host);
        }
      }
    });
  }

  private confirmOpenSelection(): void {
    const visits = this.coordinator.getSelectedVisits();
    if (visits.length === 0) {
      return;
    }
    if (visits.length <= 14) {
      this.openSelectionInNewTabs(visits);
      return;
    }
    showCenteredAlertDialog({
      title: $r('app.string.history_open_many_title'),
      message: $r('app.string.history_open_many_confirm', visits.length),
      autoCancel: true,
      primaryButton: { value: $r('app.string.settings_account_cancel'), action: (): void => {} },
      secondaryButton: {
        value: $r('app.string.ui_open'),
        action: (): void => this.openSelectionInNewTabs(visits)
      }
    });
  }

  private openSelectionInNewTabs(visits: HistoryDisplayVisit[]): void {
    visits.forEach((visit: HistoryDisplayVisit): void => {
      this.onOpenHistory(visit.url, visit.title, true);
    });
    this.applySnapshot(this.coordinator.clearSelection());
  }

  private async deleteVisit(visitId: string): Promise<void> {
    const bindingRevision = this.sessionBindingRevision;
    const tabId = this.tabId.trim();
    const coordinator = this.coordinator;
    const task = coordinator.deleteVisit(visitId);
    this.applySnapshot(coordinator.getSnapshot());
    const snapshot = await task;
    if (this.isBindingCurrent(bindingRevision, tabId, coordinator)) {
      this.applySnapshot(snapshot);
    }
  }

  private async deleteSelection(): Promise<void> {
    const bindingRevision = this.sessionBindingRevision;
    const tabId = this.tabId.trim();
    const coordinator = this.coordinator;
    const task = coordinator.deleteSelection();
    this.applySnapshot(coordinator.getSnapshot());
    const snapshot = await task;
    if (this.isBindingCurrent(bindingRevision, tabId, coordinator)) {
      this.applySnapshot(snapshot);
    }
  }

  private async clearAll(): Promise<void> {
    const bindingRevision = this.sessionBindingRevision;
    const tabId = this.tabId.trim();
    const coordinator = this.coordinator;
    const task = coordinator.clearAll();
    this.applySnapshot(coordinator.getSnapshot());
    const snapshot = await task;
    if (this.isBindingCurrent(bindingRevision, tabId, coordinator)) {
      this.applySnapshot(snapshot);
    }
  }

  private async deleteSite(host: string): Promise<void> {
    const bindingRevision = this.sessionBindingRevision;
    const tabId = this.tabId.trim();
    const coordinator = this.coordinator;
    const task = coordinator.deleteSite(host);
    this.applySnapshot(coordinator.getSnapshot());
    const snapshot = await task;
    if (this.isBindingCurrent(bindingRevision, tabId, coordinator)) {
      this.applySnapshot(snapshot);
    }
  }

  private copyLink(url: string): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
      pasteboard.getSystemPasteboard().setData(data)
        .then((): void => {
          this.showToast($r('app.string.history_link_copied'));
        })
        .catch((_error: Error): void => {
          this.showToast($r('app.string.ui_copy_failed'));
        });
    } catch (_error) {
      this.showToast($r('app.string.ui_copy_failed'));
    }
  }

  private showToast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 1500
      });
    } catch (_error) {
    }
  }

  private focusSearch(): void {
    setTimeout((): void => {
      focusControl.requestFocus(HISTORY_LARGE_SCREEN_SEARCH_FOCUS_KEY);
    }, 0);
  }

  private handleKeyEvent(event: KeyEvent): boolean {
    const isDown = event.type === KeyType.Down;
    const isUp = event.type === KeyType.Up;
    if (event.keyCode === KeyCode.KEYCODE_SHIFT_LEFT || event.keyCode === KeyCode.KEYCODE_SHIFT_RIGHT) {
      this.shiftPressed = isDown ? true : (isUp ? false : this.shiftPressed);
      return false;
    }
    if (event.keyCode === KeyCode.KEYCODE_CTRL_LEFT || event.keyCode === KeyCode.KEYCODE_CTRL_RIGHT) {
      this.controlPressed = isDown ? true : (isUp ? false : this.controlPressed);
      return false;
    }
    if (!isDown) {
      return false;
    }
    if (event.keyCode === KeyCode.KEYCODE_DEL && this.snapshot.selectedVisitIds.length > 0) {
      this.confirmDeleteSelection();
      return true;
    }
    if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
      if (this.snapshot.selectedVisitIds.length > 0) {
        this.applySnapshot(this.coordinator.clearSelection());
      } else if (this.snapshot.query.length > 0) {
        void this.updateQuery('');
      }
      return true;
    }
    if (event.keyCode === KeyCode.KEYCODE_ENTER || event.keyCode === KeyCode.KEYCODE_NUMPAD_ENTER ||
      event.keyCode === KeyCode.KEYCODE_DPAD_CENTER) {
      const selectedId = this.snapshot.selectedVisitIds[0] ?? '';
      const visit = this.coordinator.findVisit(selectedId);
      if (visit !== undefined) {
        this.onOpenHistory(visit.url, visit.title, false);
        return true;
      }
    }
    return false;
  }

  private resolveWorkspaceTitle(): ResourceStr {
    if (this.snapshot.selectedVisitIds.length > 0) {
      return $r('app.string.history_selected', this.snapshot.selectedVisitIds.length);
    }
    if (this.snapshot.site.length > 0) {
      return localizeHistoryHost(this.snapshot.site);
    }
    return $r('app.string.app_shortcut_history');
  }

  private resolveWorkspaceBadge(): ResourceStr {
    if (this.snapshot.selectedVisitIds.length > 0 || this.snapshot.loading) {
      return '';
    }
    if (this.privateMode) {
      return $r('app.string.history_regular');
    }
    return $r('app.string.history_item_count', this.resolveVisibleItemCount());
  }

  private scheduleRoutePublish(): void {
    this.cancelRoutePublish();
    this.routePublishTimer = setTimeout((): void => {
      this.routePublishTimer = -1;
      this.publishRouteNow();
    }, HISTORY_ROUTE_PUBLISH_DEBOUNCE_MS);
  }

  private cancelRoutePublish(): void {
    if (this.routePublishTimer >= 0) {
      clearTimeout(this.routePublishTimer);
      this.routePublishTimer = -1;
    }
  }

  private publishRouteNow(): void {
    if (!this.mounted) {
      return;
    }
    const nextRoute = this.snapshot.routeUrl.trim();
    if (nextRoute.length > 0 && nextRoute !== this.routeUrl.trim()) {
      this.onRouteChange(this.tabId.trim(), nextRoute);
    }
  }

  private resolveVisibleItemCount(): number {
    return this.snapshot.viewMode === 'sites' ? this.snapshot.sites.length : this.snapshot.visits.length;
  }

  private captureScrollOffset(): void {
    try {
      const scroller = this.snapshot.viewMode === 'sites' ? this.sitesScroller : this.timelineScroller;
      this.coordinator.rememberScrollOffset(scroller.currentOffset().yOffset);
    } catch (_error) {
    }
  }

  private restoreScrollOffset(
    bindingRevision: number,
    tabId: string,
    coordinator: HistoryWorkspaceSessionCoordinator
  ): void {
    const offsetY = coordinator.getScrollOffset();
    setTimeout((): void => {
      if (!this.isBindingCurrent(bindingRevision, tabId, coordinator)) {
        return;
      }
      const scroller = this.snapshot.viewMode === 'sites' ? this.sitesScroller : this.timelineScroller;
      try {
        scroller.scrollTo({ xOffset: 0, yOffset: offsetY, animation: false });
      } catch (_error) {
      }
    }, 0);
  }

  private isBindingCurrent(
    bindingRevision: number,
    tabId: string,
    coordinator: HistoryWorkspaceSessionCoordinator
  ): boolean {
    return this.mounted && bindingRevision === this.sessionBindingRevision &&
      tabId === this.tabId.trim() && coordinator === this.coordinator;
  }
}
