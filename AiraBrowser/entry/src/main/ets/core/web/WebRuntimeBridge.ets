import { webview } from '@kit.ArkWeb';
import { resolveAppResourceText } from '../resources/AppResourceText';
import { BrowserDownloadNavigationStateCoordinator } from '../browser/BrowserDownloadNavigationStateCoordinator';
import { BrowserTabState } from '../tabs/TabManager';

export interface WebNavigationState {
  history: string[];
  index: number;
}

export interface WebNavigationCapabilities {
  canGoBack: boolean;
  canGoForward: boolean;
}

export interface WebPagePresentation {
  currentUrl: string;
  addressInput: string;
  currentTitle: string;
  helperMessage: string;
  pageProgress: number;
  isLoading: boolean;
}

export interface WebNavigateHistoryResult {
  handled: boolean;
  navigation: WebNavigationState;
  targetUrl?: string;
  errorMessage?: string;
}

export interface WebSessionRestorePlan {
  tabId: string;
  snapshotPath: string;
  targetUrl: string;
  helperMessage: string;
}

export interface WebWindowOpenAction {
  type: 'ignore' | 'download' | 'external' | 'new_tab';
  targetUrl: string;
  helperMessage: string;
  title: string;
}

export interface WebFileSelectorPlan {
  type: 'save' | 'select' | 'folder_unsupported';
  suggestedName: string;
  maxSelectNumber: number;
  suffixFilters: string[];
}

export interface WebHttpAuthDialogModel {
  host: string;
  realm: string;
}

export interface WebSslWarningModel {
  title: string;
  message: string;
  cancelLabel: string;
  confirmLabel: string;
}

const WEB_FILE_FILTER_IMAGE_SUFFIXES: string = '.jpg,.jpeg,.png,.gif,.bmp,.webp,.svg,.heic,.heif';
const WEB_FILE_FILTER_VIDEO_SUFFIXES: string = '.mp4,.mov,.m4v,.mkv,.webm,.avi';
const WEB_FILE_FILTER_AUDIO_SUFFIXES: string = '.mp3,.m4a,.aac,.wav,.flac,.ogg,.opus';
const WEB_FILE_FILTER_TEXT_SUFFIXES: string = '.txt,.md,.csv,.json,.xml,.log';
export const WEB_TRANSIENT_LOADING_TITLE: string = '页面加载中';

export class WebRuntimeBridge {
  private downloadNavigationStateCoordinator: BrowserDownloadNavigationStateCoordinator;

  constructor(downloadNavigationStateCoordinator: BrowserDownloadNavigationStateCoordinator) {
    this.downloadNavigationStateCoordinator = downloadNavigationStateCoordinator;
  }

  getCapabilitySummary(): string {
    return 'Web 组件运行时、事件桥接、下载与导航状态将统一收口到 core/web。';
  }

  getDefaultSearchPlaceholder(): string {
    return resolveAppResourceText($r('app.string.aira_search_card_placeholder'));
  }

  getInitialHomeUrl(): string {
    return 'https://developer.huawei.com/consumer/cn/doc/';
  }

  createController(): webview.WebviewController {
    return new webview.WebviewController();
  }

  loadPendingUrl(controller: webview.WebviewController, pendingUrl: string, currentUrl: string): void {
    const targetUrl = pendingUrl.length > 0 ? pendingUrl : currentUrl;
    if (targetUrl.length === 0) {
      return;
    }
    controller.loadUrl(targetUrl);
  }

  buildSessionRestorePlan(tab: BrowserTabState, reason: string): WebSessionRestorePlan | undefined {
    if (tab.isHome) {
      return undefined;
    }

    return {
      tabId: tab.id,
      snapshotPath: tab.webStatePath,
      targetUrl: this.resolveSessionRestoreTargetUrl(tab),
      helperMessage: reason === 'controller-attach'
        ? resolveAppResourceText($r('app.string.browser_browser_shell_view_model_038'))
        : resolveAppResourceText($r('app.string.web_runtime_switching_tab'))
    };
  }

  resolvePageBegin(event: OnPageBeginEvent, addressDisplayText: string): WebPagePresentation {
    return {
      currentUrl: event.url,
      addressInput: addressDisplayText,
      currentTitle: WEB_TRANSIENT_LOADING_TITLE,
      helperMessage: resolveAppResourceText($r('app.string.web_runtime_page_loading')),
      pageProgress: 0,
      isLoading: true
    };
  }

  resolvePageEnd(event: OnPageEndEvent, addressDisplayText: string, currentTitle: string): WebPagePresentation {
    return {
      currentUrl: event.url,
      addressInput: addressDisplayText,
      currentTitle: currentTitle,
      helperMessage: resolveAppResourceText($r('app.string.web_runtime_page_loaded')),
      pageProgress: 100,
      isLoading: false
    };
  }

  syncNavigationState(
    _controller: webview.WebviewController,
    _controllerAttached: boolean,
    _navigation: WebNavigationState
  ): WebNavigationCapabilities {
    return {
      canGoBack: false,
      canGoForward: false
    };
  }

  recordNavigation(navigation: WebNavigationState, url: string): WebNavigationState {
    if (url.length === 0) {
      return navigation;
    }
    if (navigation.index >= 0 && navigation.index < navigation.history.length &&
      this.normalizeNavigationTarget(navigation.history[navigation.index]) === this.normalizeNavigationTarget(url)) {
      return navigation;
    }

    const retainedHistory = navigation.index >= 0 ? navigation.history.slice(0, navigation.index + 1) : [];
    const nextHistory = retainedHistory.concat([url]);
    return {
      history: nextHistory,
      index: nextHistory.length - 1
    };
  }

  navigateHistory(
    controller: webview.WebviewController,
    navigation: WebNavigationState,
    step: number
  ): WebNavigateHistoryResult {
    const nextIndex = navigation.index + step;
    if (nextIndex < 0 || nextIndex >= navigation.history.length) {
      const result: WebNavigateHistoryResult = {
        handled: false,
        navigation: navigation
      };
      return result;
    }

    const targetUrl = navigation.history[nextIndex];
    try {
      controller.loadUrl(targetUrl);
      const nextNavigation: WebNavigationState = {
        history: navigation.history.slice(),
        index: nextIndex
      };
      const result: WebNavigateHistoryResult = {
        handled: true,
        navigation: nextNavigation,
        targetUrl: targetUrl
      };
      return result;
    } catch (error) {
      const result: WebNavigateHistoryResult = {
        handled: true,
        navigation: navigation,
        errorMessage: resolveAppResourceText($r('app.string.web_runtime_history_failed', JSON.stringify(error)))
      };
      return result;
    }
  }

  canLoadInWebView(url: string): boolean {
    const scheme = this.getUrlScheme(url);
    return scheme === 'http' || scheme === 'https' || scheme === 'file' || scheme === 'about' || scheme === 'data' ||
      scheme === 'blob' || scheme === 'javascript';
  }

  buildWindowOpenAction(targetUrl: string, isAlert: boolean): WebWindowOpenAction {
    const trimmedUrl = targetUrl.trim();
    if (trimmedUrl.length === 0) {
      return {
        type: 'ignore',
        targetUrl: '',
        helperMessage: resolveAppResourceText($r('app.string.web_runtime_no_address')),
        title: ''
      };
    }

    if (!this.canLoadInWebView(trimmedUrl)) {
      return {
        type: 'download',
        targetUrl: trimmedUrl,
        helperMessage: resolveAppResourceText($r('app.string.web_runtime_external_resource', trimmedUrl)),
        title: trimmedUrl
      };
    }

    return {
      type: 'new_tab',
      targetUrl: trimmedUrl,
      helperMessage: isAlert
        ? resolveAppResourceText($r('app.string.web_runtime_popup_opened'))
        : resolveAppResourceText($r('app.string.web_runtime_link_opened')),
      title: isAlert ? resolveAppResourceText($r('app.string.web_runtime_new_window')) : trimmedUrl
    };
  }

  buildFileSelectorPlan(fileSelector: FileSelectorParam): WebFileSelectorPlan {
    const mode = fileSelector.getMode();
    if (mode === FileSelectorMode.FileSaveMode) {
      return {
        type: 'save',
        suggestedName: this.resolveWebFileSuggestedName(fileSelector),
        maxSelectNumber: 1,
        suffixFilters: this.resolveWebFileSuffixFilters(fileSelector)
      };
    }

    if (mode === FileSelectorMode.FileOpenFolderMode) {
      return {
        type: 'folder_unsupported',
        suggestedName: '',
        maxSelectNumber: 0,
        suffixFilters: []
      };
    }

    return {
      type: 'select',
      suggestedName: '',
      maxSelectNumber: mode === FileSelectorMode.FileOpenMultipleMode ? 100 : 1,
      suffixFilters: this.resolveWebFileSuffixFilters(fileSelector)
    };
  }

  buildHttpAuthDialogModel(event: OnHttpAuthRequestEvent): WebHttpAuthDialogModel {
    return {
      host: event.host,
      realm: event.realm
    };
  }

  buildSslWarningModel(event: SslErrorEvent): WebSslWarningModel {
    const url = event.url.length > 0 ? event.url : resolveAppResourceText($r('app.string.web_runtime_current_page'));
    return {
      title: resolveAppResourceText($r('app.string.web_runtime_cert_title')),
      message: resolveAppResourceText($r('app.string.web_runtime_cert_message', url)),
      cancelLabel: resolveAppResourceText($r('app.string.web_runtime_back_safe')),
      confirmLabel: resolveAppResourceText($r('app.string.web_runtime_continue'))
    };
  }

  buildHttpsFirstFallbackWarningModel(failedUrl: string, fallbackUrl: string): WebSslWarningModel {
    const url = failedUrl.length > 0 ? failedUrl : resolveAppResourceText($r('app.string.web_runtime_current_page'));
    return {
      title: resolveAppResourceText($r('app.string.web_runtime_https_title')),
      message: resolveAppResourceText($r('app.string.web_runtime_https_message', url, fallbackUrl)),
      cancelLabel: resolveAppResourceText($r('app.string.web_runtime_back_safe')),
      confirmLabel: resolveAppResourceText($r('app.string.web_runtime_use_http'))
    };
  }

  getUrlScheme(url: string): string {
    const match = url.trim().match(/^([a-z][a-z0-9+.-]*):/i);
    return match === null ? '' : match[1].toLowerCase();
  }

  private resolveSessionRestoreTargetUrl(tab: BrowserTabState): string {
    return this.downloadNavigationStateCoordinator.resolveRestorableNavigation(tab).url;
  }

  private resolveWebFileSuggestedName(fileSelector: FileSelectorParam): string {
    try {
      const suggestedName = fileSelector.getSuggestedName().trim();
      if (suggestedName.length > 0) {
        return suggestedName;
      }
    } catch (_error) {
    }

    const title = fileSelector.getTitle().trim();
    return title.length > 0 ? title : `aira-upload-${Date.now()}`;
  }

  private resolveWebFileSuffixFilters(fileSelector: FileSelectorParam): Array<string> {
    const acceptTypes = fileSelector.getAcceptType()
      .map((item: string) => item.trim().toLowerCase())
      .filter((item: string) => item.length > 0);
    if (acceptTypes.length === 0 || acceptTypes.includes('*/*') || acceptTypes.includes('*')) {
      return [];
    }

    const mappedFilters: string[] = [];
    const extensionFilters: string[] = [];
    acceptTypes.forEach((acceptType: string) => {
      if (acceptType.startsWith('.')) {
        extensionFilters.push(acceptType);
        return;
      }
      switch (acceptType) {
        case 'image/*':
          mappedFilters.push(this.buildFileFilter($r('app.string.media_resource_kind_image'), WEB_FILE_FILTER_IMAGE_SUFFIXES));
          return;
        case 'video/*':
          mappedFilters.push(this.buildFileFilter($r('app.string.media_resource_tab_video'), WEB_FILE_FILTER_VIDEO_SUFFIXES));
          return;
        case 'audio/*':
          mappedFilters.push(this.buildFileFilter($r('app.string.media_resource_kind_audio'), WEB_FILE_FILTER_AUDIO_SUFFIXES));
          return;
        case 'text/*':
          mappedFilters.push(this.buildFileFilter($r('app.string.browser_ui_browser_download_management_row_003'), WEB_FILE_FILTER_TEXT_SUFFIXES));
          return;
        case 'application/pdf':
          extensionFilters.push('.pdf');
          return;
        case 'application/json':
          extensionFilters.push('.json');
          return;
        case 'application/zip':
        case 'application/x-zip-compressed':
          extensionFilters.push('.zip');
          return;
        case 'text/plain':
          extensionFilters.push('.txt');
          return;
        case 'text/csv':
          extensionFilters.push('.csv');
          return;
        case 'application/xml':
        case 'text/xml':
          extensionFilters.push('.xml');
          return;
        default:
          return;
      }
    });

    const uniqueMappedFilters = Array.from(new Set(mappedFilters));
    const uniqueExtensions = Array.from(new Set(extensionFilters));
    if (uniqueExtensions.length > 0) {
      uniqueMappedFilters.push(this.buildFileFilter($r('app.string.web_runtime_allowed_files'), uniqueExtensions.join(',')));
    }
    return uniqueMappedFilters;
  }

  private buildFileFilter(label: ResourceStr, suffixes: string): string {
    return `${resolveAppResourceText(label)}|${suffixes}`;
  }

  private normalizeNavigationTarget(url: string): string {
    const trimmed = url.trim().toLowerCase();
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }
}
