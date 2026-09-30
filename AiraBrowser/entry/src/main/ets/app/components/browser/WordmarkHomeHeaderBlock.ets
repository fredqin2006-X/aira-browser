import { ExternalAppSearchTargetId, SearchSuggestion } from '../../../common/models/BrowserModels';
import { BrowserTabHomeContentAction } from '../../../core/browser/BrowserTabHomeCoordinator';
import {
  createDefaultHomeContentThemePresentationState,
  HomeContentThemePresentationState
} from '../../../core/browser/HomeContentPresentationState';
import { CenteredHomeHeader } from './CenteredHomeHeader';

/**
 * Stateless wordmark and search field. 简约 and 极简 each mount their own copy and pass
 * their own literals. This block keeps no scroll, height, or visibility of its own.
 */
@Component
export struct WordmarkHomeHeaderBlock {
  @Prop theme: HomeContentThemePresentationState = createDefaultHomeContentThemePresentationState();
  @Prop horizontalPadding: number = 0;
  @Prop searchPresented: boolean = false;
  @Prop searchGeometryEnabled: boolean = true;
  @Prop inlineSearch: boolean = false;
  @Prop inlineSearchActive: boolean = false;
  @Prop searchSuggestions: SearchSuggestion[] = [];
  @Prop searchViewportHeight: number = 0;
  @Prop searchPopupReservedTop: number = 0;
  @Prop searchDismissVersion: number = 0;
  @Prop showScanButton: boolean = true;
  @Prop softenSearchBorder: boolean = false;
  @Prop searchSideInset: number = 0;
  @Prop wordmarkOpensSettings: boolean = true;

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

  build() {
    Column() {
      CenteredHomeHeader({
        textColor: this.theme.primaryTextColor,
        secondaryTextColor: this.theme.secondaryTextColor,
        searchPresented: this.searchPresented,
        searchGeometryEnabled: this.searchGeometryEnabled,
        inlineSearch: this.inlineSearch,
        searchSuggestions: this.searchSuggestions,
        searchViewportHeight: this.searchViewportHeight,
        searchPopupReservedTop: this.searchPopupReservedTop,
        searchDismissVersion: this.searchDismissVersion,
        onOpenSearch: () => {
          this.onOpenSearch();
        },
        showScanButton: this.showScanButton,
        softenSearchBorder: this.softenSearchBorder,
        searchSideInset: this.searchSideInset,
        wordmarkOpensSettings: this.wordmarkOpensSettings,
        onOpenSettings: () => {
          this.onAction({ type: 'open_home_settings' });
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
        onOpenSuggestion: (suggestion: SearchSuggestion): void => {
          this.onOpenSearchSuggestion(suggestion);
        },
        onDeleteSuggestion: (suggestion: SearchSuggestion): void => {
          this.onDeleteSearchSuggestion(suggestion);
        },
        onClearSuggestions: (): void => {
          this.onClearSearchSuggestions();
        },
        onExternalSearch: (targetId: ExternalAppSearchTargetId, query: string): void => {
          this.onExternalSearch(targetId, query);
        }
      })
    }
    .width('100%')
    .zIndex(this.inlineSearch && this.inlineSearchActive ? 2 : 0)
    .clip(false)
    .padding({
      left: this.horizontalPadding,
      right: this.horizontalPadding
    })
  }
}
