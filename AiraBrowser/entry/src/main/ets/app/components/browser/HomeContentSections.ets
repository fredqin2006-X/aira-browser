import {
  createDefaultHomeContentSectionsPresentationState,
  createDefaultHomeContentThemePresentationState,
  HomeContentSectionsPresentationState,
  HomeContentThemePresentationState
} from '../../../core/browser/HomeContentPresentationState';
import { ExternalAppSearchTargetId, SearchSuggestion } from '../../../common/models/BrowserModels';
import {
  BrowserHomePageStyle,
  resolveMountedSystemHomeFrame
} from '../../../common/models/HomePagePresentationSettingsModels';
import { BrowserTabHomeContentAction } from '../../../core/browser/BrowserTabHomeCoordinator';
import { ClassicHomeFrame } from './ClassicHomeFrame';
import { CenteredHomePageFrame } from './CenteredHomeFrame';
import { MinimalHomeFrame } from './MinimalHomeFrame';

/**
 * Mounts exactly one system homepage.
 *
 * 经典, 简约, and 极简 are different components. Switching style destroys the previous
 * frame, including its scroller, measured height, and drag state. Do not keep those on
 * this host, and do not describe one frame as a flag on another.
 */
@Component
export struct HomeContentSections {
  @Prop homePageStyle: BrowserHomePageStyle = 'classic';
  @Prop showShortcuts: boolean = true;
  @Prop largeScreenShell: boolean = false;
  @Prop recentlyClosedExpanded: boolean = true;
  @Prop presentation: HomeContentSectionsPresentationState =
    createDefaultHomeContentSectionsPresentationState();
  @Prop theme: HomeContentThemePresentationState = createDefaultHomeContentThemePresentationState();
  @Prop searchPresented: boolean = false;
  @Prop searchGeometryEnabled: boolean = true;
  @Prop inlineSearch: boolean = false;
  @Prop inlineSearchActive: boolean = false;
  @Prop searchSuggestions: SearchSuggestion[] = [];
  @Prop searchDismissVersion: number = 0;
  @Prop viewportHeight: number = 0;
  @Prop topSafeInset: number = 0;
  @Prop bottomReserve: number = 0;
  @Link contextMenuShortcutId: string;

  onAction: (action: BrowserTabHomeContentAction) => void = (_action: BrowserTabHomeContentAction) => {};
  onOpenSearch: () => void = () => {};
  onScan: () => void = () => {};
  onInlineSearchSession: (active: boolean, query: string) => void =
    (_active: boolean, _query: string) => {};
  onSubmitSearch: (query: string) => void = (_query: string) => {};
  onOpenSearchSuggestion: (suggestion: SearchSuggestion) => void =
    (_suggestion: SearchSuggestion) => {};
  onDeleteSearchSuggestion: (suggestion: SearchSuggestion) => void =
    (_suggestion: SearchSuggestion) => {};
  onClearSearchSuggestions: () => void = () => {};
  onExternalSearch: (targetId: ExternalAppSearchTargetId, query: string) => void =
    (_targetId: ExternalAppSearchTargetId, _query: string) => {};
  onDismissInlineSearch: () => void = () => {};

  build() {
    if (this.resolveFrame() === 'minimal') {
      this.buildMinimalFrame()
    } else if (this.resolveFrame() === 'centered') {
      this.buildCenteredFrame()
    } else {
      this.buildClassicFrame()
    }
  }

  private resolveFrame(): BrowserHomePageStyle {
    return resolveMountedSystemHomeFrame(this.homePageStyle);
  }

  @Builder
  private buildClassicFrame() {
    ClassicHomeFrame({
      showShortcuts: this.showShortcuts,
      recentlyClosedExpanded: this.recentlyClosedExpanded,
      presentation: this.presentation,
      theme: this.theme,
      contextMenuShortcutId: $contextMenuShortcutId,
      onAction: (action: BrowserTabHomeContentAction) => {
        this.onAction(action);
      }
    })
  }

  @Builder
  private buildCenteredFrame() {
    CenteredHomePageFrame({
      showShortcuts: this.showShortcuts,
      largeScreenShell: this.largeScreenShell,
      presentation: this.presentation,
      theme: this.theme,
      searchPresented: this.searchPresented,
      searchGeometryEnabled: this.searchGeometryEnabled,
      inlineSearch: this.inlineSearch,
      inlineSearchActive: this.inlineSearchActive,
      searchSuggestions: this.searchSuggestions,
      searchDismissVersion: this.searchDismissVersion,
      viewportHeight: this.viewportHeight,
      topSafeInset: this.topSafeInset,
      bottomReserve: this.bottomReserve,
      contextMenuShortcutId: $contextMenuShortcutId,
      onAction: (action: BrowserTabHomeContentAction) => {
        this.onAction(action);
      },
      onOpenSearch: () => {
        this.onOpenSearch();
      },
      onScan: () => {
        this.onScan();
      },
      onInlineSearchSession: (active: boolean, query: string): void => {
        this.onInlineSearchSession(active, query);
      },
      onSubmitSearch: (query: string): void => {
        this.onSubmitSearch(query);
      },
      onOpenSearchSuggestion: (suggestion: SearchSuggestion): void => {
        this.onOpenSearchSuggestion(suggestion);
      },
      onDeleteSearchSuggestion: (suggestion: SearchSuggestion): void => {
        this.onDeleteSearchSuggestion(suggestion);
      },
      onClearSearchSuggestions: (): void => {
        this.onClearSearchSuggestions();
      },
      onExternalSearch: (targetId: ExternalAppSearchTargetId, query: string): void => {
        this.onExternalSearch(targetId, query);
      },
      onDismissInlineSearch: (): void => {
        this.onDismissInlineSearch();
      }
    })
  }

  @Builder
  private buildMinimalFrame() {
    MinimalHomeFrame({
      presentation: this.presentation,
      theme: this.theme,
      searchPresented: this.searchPresented,
      searchGeometryEnabled: this.searchGeometryEnabled,
      inlineSearch: this.inlineSearch,
      inlineSearchActive: this.inlineSearchActive,
      searchSuggestions: this.searchSuggestions,
      searchDismissVersion: this.searchDismissVersion,
      viewportHeight: this.viewportHeight,
      topSafeInset: this.topSafeInset,
      bottomReserve: this.bottomReserve,
      onAction: (action: BrowserTabHomeContentAction) => {
        this.onAction(action);
      },
      onOpenSearch: () => {
        this.onOpenSearch();
      },
      onScan: () => {
        this.onScan();
      },
      onInlineSearchSession: (active: boolean, query: string): void => {
        this.onInlineSearchSession(active, query);
      },
      onSubmitSearch: (query: string): void => {
        this.onSubmitSearch(query);
      },
      onOpenSearchSuggestion: (suggestion: SearchSuggestion): void => {
        this.onOpenSearchSuggestion(suggestion);
      },
      onDeleteSearchSuggestion: (suggestion: SearchSuggestion): void => {
        this.onDeleteSearchSuggestion(suggestion);
      },
      onClearSearchSuggestions: (): void => {
        this.onClearSearchSuggestions();
      },
      onExternalSearch: (targetId: ExternalAppSearchTargetId, query: string): void => {
        this.onExternalSearch(targetId, query);
      },
      onDismissInlineSearch: (): void => {
        this.onDismissInlineSearch();
      }
    })
  }
}
