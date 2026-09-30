import {
  BookmarkStorageScope,
  BrowserDataScope
} from '../../common/models/BrowserModels';
import { BookmarkRepository } from '../../data/repositories/BrowserRepositories';
import { BookmarkMutationService } from '../../services/bookmarks/BookmarkMutationService';
import { BrowserPrivacyEffectPolicyService } from '../../services/privacy/BrowserPrivacyEffectPolicyService';
import { HomeShortcutToggleService } from '../../services/shortcuts/HomeShortcutToggleService';
import { BookmarkFolderSelectionPreparationCoordinator } from './BookmarkFolderSelectionPreparationCoordinator';
import { BookmarkFolderOptionView } from './BookmarkFolderSelectionViewModel';
import { BrowserBookmarkScopeService } from './BrowserBookmarkScopeService';
import { BrowserProfileBoundaryService } from './BrowserProfileBoundaryService';
import { BrowserSearchSuggestionCoordinator } from './BrowserSearchSuggestionCoordinator';
import {
  BrowserTransientSurfaceCoordinator,
  BrowserTransientSurfaceToken
} from './BrowserTransientSurfaceCoordinator';

export type BrowserBookmarkActionSource = 'current_page' | 'reader_article' | 'context_link';

export interface BrowserBookmarkActionState {
  hasBookmark: boolean;
  label: ResourceStr;
  icon: Resource;
  disabledMessage: ResourceStr;
  bookmarkId?: string;
}

export interface BrowserBookmarkActionTarget {
  source: BrowserBookmarkActionSource;
  title: string;
  url: string;
  dataScope: BrowserDataScope | string;
  privacyMode: string;
  enabled: boolean;
  homeShortcutScenarioId: string;
}

export interface BrowserBookmarkRemoveConfirmation {
  bookmarkId: string;
  scope: BookmarkStorageScope;
  source: BrowserBookmarkActionSource;
}

export interface BrowserBookmarkActionSessionSnapshot {
  actionVersion: number;
  scope: BookmarkStorageScope;
  addToHome: boolean;
  preparing: boolean;
  options: BookmarkFolderOptionView[];
}

export interface BrowserBookmarkFolderSelectionAction {
  type: 'set_add_to_home' | 'preview_folder' | 'dismiss' | 'confirm_add';
  selected?: boolean;
  folderId?: string;
}

export interface BrowserBookmarkActionShell {
  applySnapshot: (snapshot: BrowserBookmarkActionSessionSnapshot) => void;
  showToast: (message: ResourceStr) => void;
  presentPersistentWriteBlocked: (helperText: ResourceStr, summaryLine: string) => void;
  confirmRemove: (confirmation: BrowserBookmarkRemoveConfirmation) => void;
  refreshHomeShortcuts: () => void;
}

export interface BrowserBookmarkActionCoordinatorOptions {
  repository: BookmarkRepository;
  folderPreparationCoordinator: BookmarkFolderSelectionPreparationCoordinator;
  searchSuggestionCoordinator: BrowserSearchSuggestionCoordinator;
  homeShortcutToggleService: HomeShortcutToggleService;
  transientSurfaceCoordinator: BrowserTransientSurfaceCoordinator;
  overlayRevealDelayMs: number;
  overlayDismissDurationMs: number;
}

export class BrowserBookmarkActionCoordinator {
  private readonly options: BrowserBookmarkActionCoordinatorOptions;
  private readonly mutationService: BookmarkMutationService;
  private readonly scopeService: BrowserBookmarkScopeService = new BrowserBookmarkScopeService();
  private readonly profileBoundaryService: BrowserProfileBoundaryService = new BrowserProfileBoundaryService();
  private readonly privacyEffectPolicy: BrowserPrivacyEffectPolicyService = new BrowserPrivacyEffectPolicyService();
  private readonly shell: BrowserBookmarkActionShell;
  private snapshot: BrowserBookmarkActionSessionSnapshot = {
    actionVersion: 0,
    scope: 'regular',
    addToHome: false,
    preparing: false,
    options: []
  };
  private pendingTarget?: BrowserBookmarkActionTarget;
  private anchoredPreparationSequence: number = 0;

  constructor(options: BrowserBookmarkActionCoordinatorOptions, shell: BrowserBookmarkActionShell) {
    this.options = options;
    this.mutationService = new BookmarkMutationService(options.repository);
    this.shell = shell;
  }

  getSnapshot(): BrowserBookmarkActionSessionSnapshot {
    return this.cloneSnapshot();
  }

  buildActionState(target: BrowserBookmarkActionTarget): BrowserBookmarkActionState {
    const scope = this.resolveTargetScope(target);
    const url = target.url.trim();
    const disabledMessage = this.buildDisabledMessage(target, scope);
    if (!target.enabled || url.length <= 0) {
      return this.buildAddState(disabledMessage);
    }
    const bookmark = this.options.repository.findBookmarkByUrl(url, scope);
    if (bookmark === undefined) {
      return this.buildAddState(disabledMessage);
    }
    return {
      hasBookmark: true,
      label: $r('app.string.bottom_panel_remove_bookmark'),
      icon: $r('sys.symbol.bookmark_fill'),
      disabledMessage: disabledMessage,
      bookmarkId: bookmark.id
    };
  }

  toggle(target: BrowserBookmarkActionTarget): void {
    const state = this.buildActionState(target);
    if (!target.enabled || target.url.trim().length <= 0) {
      this.shell.showToast(state.disabledMessage);
      return;
    }
    const scope = this.resolveTargetScope(target);
    if (state.bookmarkId !== undefined) {
      this.shell.confirmRemove({
        bookmarkId: state.bookmarkId,
        scope: scope,
        source: target.source
      });
    } else {
      this.startAdd(target);
    }
  }

  startAdd(target: BrowserBookmarkActionTarget): void {
    const url = target.url.trim();
    if (!target.enabled || url.length <= 0) {
      this.shell.showToast(this.buildActionState(target).disabledMessage);
      return;
    }
    const scope = this.resolveTargetScope(target);
    this.prepareAddSession(target, scope);
    const token = this.options.transientSurfaceCoordinator.present({
      id: 'bookmark_folder_selection',
      revealDelayMs: this.options.overlayRevealDelayMs,
      dismissDurationMs: this.options.overlayDismissDurationMs
    });
    void this.prepareFolderOptions(scope, token);
  }

  openAnchored(target: BrowserBookmarkActionTarget): void {
    const state = this.buildActionState(target);
    if (!target.enabled || target.url.trim().length <= 0) {
      this.shell.showToast(state.disabledMessage);
      return;
    }
    const scope = this.resolveTargetScope(target);
    if (state.bookmarkId !== undefined) {
      this.shell.confirmRemove({
        bookmarkId: state.bookmarkId,
        scope: scope,
        source: target.source
      });
      return;
    }
    this.prepareAddSession(target, scope);
    const requestId = ++this.anchoredPreparationSequence;
    void this.prepareAnchoredFolderOptions(scope, requestId);
  }

  handleFolderSelectionAction(action: BrowserBookmarkFolderSelectionAction): void {
    if (action.type === 'set_add_to_home') {
      if (action.selected !== undefined) {
        this.setAddToHome(action.selected);
      }
      return;
    }
    if (action.type === 'preview_folder') {
      if (action.folderId !== undefined) {
        void this.previewFolder(action.folderId);
      }
      return;
    }
    if (action.type === 'dismiss') {
      this.dismiss();
      return;
    }
    if (action.folderId !== undefined) {
      this.confirmAdd(action.folderId);
    }
  }

  private setAddToHome(selected: boolean): void {
    this.snapshot.addToHome = this.snapshot.scope === 'regular' && selected;
    this.emitSnapshot();
  }

  private async previewFolder(folderId: string): Promise<void> {
    const token = this.options.transientSurfaceCoordinator.currentToken('bookmark_folder_selection');
    if (token === undefined) {
      return;
    }
    const scope = this.snapshot.scope;
    try {
      const options = await this.options.folderPreparationCoordinator.prepareFolderPreview(
        scope,
        folderId,
        this.snapshot.options
      );
      this.applyPreparedOptions(scope, token, options);
    } catch (_error) {
    }
  }

  private dismiss(): void {
    this.pendingTarget = undefined;
    this.anchoredPreparationSequence += 1;
    this.options.transientSurfaceCoordinator.dismiss('bookmark_folder_selection');
  }

  private confirmAdd(targetFolderId: string): void {
    const target = this.pendingTarget;
    const scope = this.snapshot.scope;
    const addToHome = this.snapshot.addToHome;
    this.pendingTarget = undefined;
    this.anchoredPreparationSequence += 1;
    this.options.transientSurfaceCoordinator.reset('bookmark_folder_selection');
    if (target !== undefined) {
      void this.addBookmark(target, scope, targetFolderId, addToHome);
    }
  }

  async removeConfirmed(confirmation: BrowserBookmarkRemoveConfirmation): Promise<void> {
    try {
      const deleted = await this.mutationService.deleteNode(confirmation.bookmarkId);
      if (deleted) {
        this.refreshBookmarkSurfaces(confirmation.scope);
      }
      this.shell.showToast(deleted ?
        $r('app.string.bottom_panel_bookmark_removed') :
        $r('app.string.bottom_panel_bookmark_missing'));
    } catch (_error) {
      this.shell.showToast($r('app.string.bottom_panel_bookmark_remove_failed'));
    }
  }

  private async addBookmark(
    target: BrowserBookmarkActionTarget,
    scope: BookmarkStorageScope,
    targetFolderId: string,
    addToHome: boolean
  ): Promise<void> {
    if (scope === 'regular' && !this.allowPersistentWrite(target)) {
      return;
    }
    const url = target.url.trim();
    const title = target.title.trim().length > 0 ? target.title.trim() : url;
    try {
      await this.mutationService.createBookmarkIfMissing({
        type: 'bookmark',
        title: title,
        url: url,
        parentId: targetFolderId.trim().length > 0 ? targetFolderId.trim() : undefined,
        scope: scope
      });
      this.refreshBookmarkSurfaces(scope);
      if (addToHome && scope === 'regular') {
        try {
          const result = await this.options.homeShortcutToggleService.addIfMissing({
            title: title,
            url: url,
            scenarioId: target.homeShortcutScenarioId
          });
          this.shell.refreshHomeShortcuts();
          this.shell.showToast(result.added ?
            $r('app.string.bottom_panel_bookmark_added_home') :
            $r('app.string.bottom_panel_bookmark_added_home_exists'));
        } catch (_error) {
          this.shell.showToast($r('app.string.bottom_panel_bookmark_added_home_failed'));
        }
        return;
      }
      this.shell.showToast(scope === 'private' ?
        $r('app.string.bottom_panel_bookmark_added_private') :
        $r('app.string.bottom_panel_bookmark_added'));
    } catch (_error) {
      this.shell.showToast($r('app.string.bottom_panel_bookmark_add_failed'));
    }
  }

  private allowPersistentWrite(target: BrowserBookmarkActionTarget): boolean {
    const boundary = this.profileBoundaryService.buildBoundary({
      dataScope: target.dataScope,
      privacyMode: target.privacyMode
    });
    const scope = this.resolveTargetScope(target);
    if (scope === 'private') {
      const privateBookmarkPolicy = this.privacyEffectPolicy.resolveDataPolicyForBoundary(
        'private_bookmarks',
        boundary
      );
      if (!privateBookmarkPolicy.persistentWriteAllowed) {
        this.shell.presentPersistentWriteBlocked(
          $r('app.string.bookmark_action_private_blocked'),
          privateBookmarkPolicy.summaryLine
        );
      }
      return privateBookmarkPolicy.persistentWriteAllowed;
    }
    const decision = this.privacyEffectPolicy.decide({
      intent: 'regular_profile_management_mutation',
      requestingBoundary: boundary,
      targetScope: 'regular_profile_data',
      targetIsClear: true
    });
    if (decision.outcome !== 'allow') {
      this.shell.presentPersistentWriteBlocked(
        $r('app.string.bookmark_action_regular_blocked'),
        decision.diagnosticSummary
      );
    }
    return decision.outcome === 'allow';
  }

  private async prepareFolderOptions(
    scope: BookmarkStorageScope,
    token: BrowserTransientSurfaceToken
  ): Promise<void> {
    try {
      const options = await this.options.folderPreparationCoordinator.prepare(scope);
      this.applyPreparedOptions(scope, token, options);
    } catch (_error) {
      if (this.options.transientSurfaceCoordinator.isCurrent(token)) {
        this.snapshot.preparing = false;
        this.emitSnapshot();
      }
    }
  }

  private async prepareAnchoredFolderOptions(scope: BookmarkStorageScope, requestId: number): Promise<void> {
    try {
      const options = await this.options.folderPreparationCoordinator.prepare(scope);
      if (requestId !== this.anchoredPreparationSequence || this.snapshot.scope !== scope) {
        return;
      }
      this.snapshot.preparing = false;
      this.snapshot.options = options;
      this.emitSnapshot();
    } catch (_error) {
      if (requestId === this.anchoredPreparationSequence) {
        this.snapshot.preparing = false;
        this.emitSnapshot();
      }
    }
  }

  private prepareAddSession(target: BrowserBookmarkActionTarget, scope: BookmarkStorageScope): void {
    this.anchoredPreparationSequence += 1;
    this.pendingTarget = target;
    this.snapshot.scope = scope;
    this.snapshot.addToHome = false;
    this.snapshot.preparing = this.options.folderPreparationCoordinator.getCachedOptions(scope).length <= 0;
    this.snapshot.options = this.options.folderPreparationCoordinator.getResponsiveOptions(scope);
    this.emitSnapshot();
  }

  private applyPreparedOptions(
    scope: BookmarkStorageScope,
    token: BrowserTransientSurfaceToken,
    options: BookmarkFolderOptionView[]
  ): void {
    if (!this.options.transientSurfaceCoordinator.isCurrent(token) || this.snapshot.scope !== scope) {
      return;
    }
    this.snapshot.preparing = false;
    this.snapshot.options = options;
    this.emitSnapshot();
  }

  private refreshBookmarkSurfaces(scope: BookmarkStorageScope): void {
    if (scope === 'regular') {
      this.options.searchSuggestionCoordinator.invalidate();
    }
    this.options.folderPreparationCoordinator.invalidate(scope);
    void this.options.folderPreparationCoordinator.prepare(scope, true);
    this.snapshot.actionVersion += 1;
    this.emitSnapshot();
  }

  private emitSnapshot(): void {
    this.shell.applySnapshot(this.cloneSnapshot());
  }

  private cloneSnapshot(): BrowserBookmarkActionSessionSnapshot {
    return {
      actionVersion: this.snapshot.actionVersion,
      scope: this.snapshot.scope,
      addToHome: this.snapshot.addToHome,
      preparing: this.snapshot.preparing,
      options: this.snapshot.options.slice()
    };
  }

  private resolveTargetScope(target: BrowserBookmarkActionTarget): BookmarkStorageScope {
    return this.scopeService.resolveScopeForBoundary(target.dataScope, target.privacyMode);
  }

  private buildDisabledMessage(target: BrowserBookmarkActionTarget, scope: BookmarkStorageScope): ResourceStr {
    if (target.source === 'reader_article') {
      return scope === 'private' ?
        $r('app.string.bottom_panel_article_private_bookmark_unavailable') :
        $r('app.string.bottom_panel_article_link_unavailable');
    }
    return scope === 'private' ?
      $r('app.string.bottom_panel_private_bookmark_unavailable') :
      $r('app.string.bottom_panel_bookmark_unavailable');
  }

  private buildAddState(disabledMessage: ResourceStr): BrowserBookmarkActionState {
    return {
      hasBookmark: false,
      label: $r('app.string.bottom_panel_action_bookmark'),
      icon: $r('sys.symbol.bookmark'),
      disabledMessage: disabledMessage
    };
  }
}
