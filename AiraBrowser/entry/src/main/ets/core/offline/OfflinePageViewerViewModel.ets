import {
  OfflinePageOpenStatus,
  OfflinePageSaveStatus,
  OfflinePageViewerInfoRow,
  OfflinePageViewerState
} from '../../common/models/OfflinePageModels';
import { BrowserResolvedThemeMode, ReaderModeTheme } from '../../common/models/BrowserModels';
import {
  BrowserBottomChromeGestureSource,
  BrowserBottomChromePresentation,
  BrowserBottomChromePresentationFacts,
  BrowserBottomChromePresentationViewModel
} from '../browser/BrowserBottomChromePresentationViewModel';
import { BrowserBottomAddressPanelHeaderAction } from '../browser/BrowserBottomAddressPanelViewModel';
import { BrowserBottomChromeScrollPresentation } from '../browser/BrowserBottomChromeScrollCoordinator';
import { BrowserBottomPanelResponsiveState } from '../browser/BrowserBottomPanelResponsiveViewModel';
import { HomeSearchPanelDetent } from '../browser/HomeSearchPanelDetentViewModel';
import { resolveAppResourceText } from '../resources/AppResourceText';

export type OfflinePageViewerBackAction =
  'dismiss_reader_image_preview' |
  'dismiss_reader_panel' |
  'close_reader_mode' |
  'collapse_offline_bottom_panel' |
  'route_back';
export type OfflinePageScrollTouchPhase = 'down' | 'move' | 'up' | 'cancel';

const OFFLINE_PAGE_SCROLL_GESTURE_GRACE_MS: number = 350;

export interface OfflinePageViewerBackState {
  readerModeVisible: boolean;
  readerImagePreviewVisible: boolean;
  readerPanelVisible: boolean;
  offlineBottomPanelExpanded: boolean;
}

export interface OfflineBottomChromeGestureState {
  returnHomeDrag: boolean;
  progress: number;
}

export interface OfflineBottomChromePresentationInput {
  currentDetent: HomeSearchPanelDetent;
  scrollPresentation: BrowserBottomChromeScrollPresentation;
  returnHomeDrag: boolean;
  returnHomeProgress: number;
  responsiveState: BrowserBottomPanelResponsiveState;
  panelExpansionEnabled: boolean;
  addressInput: string;
  addressDisplayText: string;
  placeholder: string;
  leadingHeaderActions: BrowserBottomAddressPanelHeaderAction[];
  trailingHeaderActions: BrowserBottomAddressPanelHeaderAction[];
}

export interface OfflineBottomChromeGestureReleasePlan {
  interceptPanelRelease: boolean;
  shouldReturnHome: boolean;
}

export class OfflinePageViewerViewModel {
  private bottomChromePresentationViewModel: BrowserBottomChromePresentationViewModel =
    new BrowserBottomChromePresentationViewModel();
  private scrollGestureActive: boolean = false;
  private scrollMoveObserved: boolean = false;
  private recentScrollGestureUntilAt: number = 0;

  createInitialBackState(): OfflinePageViewerBackState {
    return {
      readerModeVisible: false,
      readerImagePreviewVisible: false,
      readerPanelVisible: false,
      offlineBottomPanelExpanded: false
    };
  }

  resolveBackAction(state: OfflinePageViewerBackState): OfflinePageViewerBackAction {
    if (state.readerModeVisible) {
      if (state.readerImagePreviewVisible) {
        return 'dismiss_reader_image_preview';
      }
      if (state.readerPanelVisible) {
        return 'dismiss_reader_panel';
      }
      return 'close_reader_mode';
    }
    if (state.offlineBottomPanelExpanded) {
      return 'collapse_offline_bottom_panel';
    }
    return 'route_back';
  }

  buildBottomChromePresentation(
    input: OfflineBottomChromePresentationInput
  ): BrowserBottomChromePresentation {
    const facts: BrowserBottomChromePresentationFacts = {
      scene: 'web',
      addressFocused: false,
      addressEditable: false,
      currentDetent: input.currentDetent,
      scrollPresentation: input.scrollPresentation,
      returnHomeDrag: input.returnHomeDrag,
      returnHomeProgress: input.returnHomeProgress,
      panelWidth: input.responsiveState.panelWidth,
      floatingHeaderHorizontalPadding: input.responsiveState.floatingHeaderHorizontalPadding,
      restingChromeOuterSize: input.responsiveState.restingChromeOuterSize,
      restingChromeOuterGap: input.responsiveState.restingChromeOuterGap,
      panelExpansionEnabled: input.panelExpansionEnabled,
      addressInput: input.addressInput,
      addressDisplayText: input.addressDisplayText,
      placeholder: input.placeholder,
      leadingHeaderActions: input.leadingHeaderActions,
      trailingHeaderActions: input.trailingHeaderActions
    };
    return this.bottomChromePresentationViewModel.buildPresentation(facts);
  }

  beginBottomChromeGesture(source: BrowserBottomChromeGestureSource): OfflineBottomChromeGestureState {
    return {
      returnHomeDrag: this.bottomChromePresentationViewModel.isOuterGestureSource(source),
      progress: 0
    };
  }

  updateBottomChromeGesture(
    source: BrowserBottomChromeGestureSource,
    offsetY: number
  ): OfflineBottomChromeGestureState {
    const gesture = this.bottomChromePresentationViewModel.resolveReturnHomeGesture({
      source,
      offsetY,
      eligible: true
    });
    return {
      returnHomeDrag: this.bottomChromePresentationViewModel.isOuterGestureSource(source),
      progress: gesture.progress
    };
  }

  resolveBottomChromeGestureRelease(
    source: BrowserBottomChromeGestureSource,
    offsetY: number
  ): OfflineBottomChromeGestureReleasePlan {
    const outerSource = this.bottomChromePresentationViewModel.isOuterGestureSource(source);
    const gesture = this.bottomChromePresentationViewModel.resolveReturnHomeGesture({
      source,
      offsetY,
      eligible: outerSource
    });
    return {
      interceptPanelRelease: outerSource,
      shouldReturnHome: gesture.armed
    };
  }

  resolveBottomChromeMenuDetent(currentDetent: HomeSearchPanelDetent): HomeSearchPanelDetent {
    return currentDetent === 'middle' ? 'low' : 'middle';
  }

  recordScrollTouchPhase(phase: OfflinePageScrollTouchPhase, now: number = Date.now()): void {
    const normalizedNow = Math.max(0, Math.floor(now));
    if (phase === 'down') {
      this.scrollGestureActive = false;
      this.scrollMoveObserved = false;
      this.recentScrollGestureUntilAt = 0;
      return;
    }
    if (phase === 'move') {
      this.scrollGestureActive = true;
      this.scrollMoveObserved = true;
      this.recentScrollGestureUntilAt = normalizedNow + OFFLINE_PAGE_SCROLL_GESTURE_GRACE_MS;
      return;
    }
    this.scrollGestureActive = false;
    if (phase === 'up' && this.scrollMoveObserved) {
      this.recentScrollGestureUntilAt = normalizedNow + OFFLINE_PAGE_SCROLL_GESTURE_GRACE_MS;
    } else {
      this.recentScrollGestureUntilAt = 0;
    }
    this.scrollMoveObserved = false;
  }

  isScrollPresentationChangeAllowed(now: number = Date.now()): boolean {
    const normalizedNow = Math.max(0, Math.floor(now));
    return this.scrollGestureActive || normalizedNow <= this.recentScrollGestureUntilAt;
  }

  resetScrollInteraction(): void {
    this.scrollGestureActive = false;
    this.scrollMoveObserved = false;
    this.recentScrollGestureUntilAt = 0;
  }

  resolveEffectiveReaderTheme(
    readerTheme: ReaderModeTheme,
    systemTheme: BrowserResolvedThemeMode
  ): ReaderModeTheme {
    return readerTheme === 'system' ? systemTheme : readerTheme;
  }

  shouldUseLightStatusBarContent(
    readerModeVisible: boolean,
    readerTheme: ReaderModeTheme,
    readerSystemTheme: BrowserResolvedThemeMode,
    resolvedAppTheme: BrowserResolvedThemeMode
  ): boolean {
    if (readerModeVisible) {
      const effectiveTheme = this.resolveEffectiveReaderTheme(readerTheme, readerSystemTheme);
      return effectiveTheme === 'dark' || effectiveTheme === 'charcoal';
    }
    return resolvedAppTheme === 'dark';
  }

  buildInfoRows(state: OfflinePageViewerState): OfflinePageViewerInfoRow[] {
    return [
      { id: 'title', label: $r('app.string.offline_details_label_title'), value: this.resolveTitle(state), multiline: false },
      { id: 'site', label: $r('app.string.offline_details_label_site'), value: this.resolveSite(state), multiline: false },
      {
        id: 'original',
        label: $r('app.string.offline_details_label_original'),
        value: state.originalUrl,
        multiline: true
      },
      {
        id: 'saved_at',
        label: $r('app.string.offline_details_label_saved_at'),
        value: this.formatDateTime(state.savedAt),
        multiline: false
      },
      {
        id: 'updated_at',
        label: $r('app.string.offline_details_label_updated_at'),
        value: this.formatDateTime(state.updatedAt),
        multiline: false
      },
      { id: 'size', label: $r('app.string.offline_details_label_size'), value: this.formatBytes(state.totalBytes), multiline: false },
      {
        id: 'resources',
        label: $r('app.string.offline_details_label_resources'),
        value: this.formatResourceSummary(state.resourceCount, state.failedResourceCount),
        multiline: false
      },
      {
        id: 'save_status',
        label: $r('app.string.offline_details_label_save_status'),
        value: this.resolveSaveStatusText(state.saveStatus),
        multiline: false
      },
      {
        id: 'open_status',
        label: $r('app.string.offline_details_label_open_status'),
        value: this.resolveOpenStatusText(state.openStatus),
        multiline: false
      }
    ];
  }

  private resolveTitle(state: OfflinePageViewerState): string {
    const title = state.title.trim();
    return title.length > 0 ? title : resolveAppResourceText($r('app.string.offline_unnamed_page'));
  }

  private resolveSite(state: OfflinePageViewerState): string {
    const siteName = state.siteName.trim();
    if (siteName.length > 0) {
      return siteName;
    }
    const host = state.host.trim();
    return host.length > 0 ? host : resolveAppResourceText($r('app.string.offline_unknown_source'));
  }

  private formatResourceSummary(resourceCount: number, failedResourceCount: number): ResourceStr {
    const savedCount = Math.max(0, Math.floor(resourceCount));
    const failedCount = Math.max(0, Math.floor(failedResourceCount));
    if (failedCount > 0) {
      return $r('app.string.offline_resource_summary_failed', savedCount, failedCount);
    }
    return $r('app.string.offline_resource_summary', savedCount);
  }

  private resolveSaveStatusText(status: OfflinePageSaveStatus): ResourceStr {
    if (status === 'saved') {
      return $r('app.string.offline_save_status_saved');
    }
    if (status === 'partial_saved') {
      return $r('app.string.offline_save_status_partial');
    }
    if (status === 'saving') {
      return $r('app.string.offline_save_status_saving');
    }
    return $r('app.string.offline_save_status_failed');
  }

  private resolveOpenStatusText(status: OfflinePageOpenStatus): ResourceStr {
    if (status === 'available') {
      return $r('app.string.offline_open_status_available');
    }
    if (status === 'missing_snapshot') {
      return $r('app.string.offline_open_status_missing_snapshot');
    }
    if (status === 'missing_assets') {
      return $r('app.string.offline_open_status_missing_assets');
    }
    return $r('app.string.offline_open_status_corrupted');
  }

  private formatDateTime(value: number): ResourceStr {
    if (value <= 0) {
      return $r('app.string.offline_value_unavailable');
    }
    const date = new Date(value);
    return `${date.getFullYear()}-${this.pad2(date.getMonth() + 1)}-${this.pad2(date.getDate())} ` +
      `${this.pad2(date.getHours())}:${this.pad2(date.getMinutes())}`;
  }

  private formatBytes(value: number): string {
    const bytes = Math.max(0, Math.floor(value));
    if (bytes < 1024) {
      return `${bytes} B`;
    }
    const kb = bytes / 1024;
    if (kb < 1024) {
      return `${this.formatOneDecimal(kb)} KB`;
    }
    const mb = kb / 1024;
    return `${this.formatOneDecimal(mb)} MB`;
  }

  private formatOneDecimal(value: number): string {
    return (Math.round(value * 10) / 10).toString();
  }

  private pad2(value: number): string {
    return value < 10 ? `0${value}` : value.toString();
  }
}
