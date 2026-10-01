import { resolveAppResourceText } from '../../core/resources/AppResourceText';

export interface WebLoadErrorPresentationInput {
  url: string;
  pendingUrl: string;
  title: string;
  errorMessage: string;
  runtimeDegradedMessage: string;
  crashed: boolean;
  context?: 'web_page' | 'custom_homepage';
}

export interface WebLoadErrorPresentation {
  title: string;
  summary: string;
  host: string;
  primaryActionLabel: string;
  secondaryActionLabel: string;
  tertiaryActionLabel: string;
  detailLabel: string;
  detailText: string;
  hints: string[];
}

export class WebLoadErrorPresentationService {
  build(input: WebLoadErrorPresentationInput): WebLoadErrorPresentation {
    const targetUrl = this.resolveTargetUrl(input.url, input.pendingUrl);
    const host = this.extractHost(targetUrl);
    const normalizedError = this.normalizeErrorMessage(input.errorMessage);
    const isCustomHomepage = input.context === 'custom_homepage';
    const title = input.crashed
      ? resolveAppResourceText($r('app.string.web_error_tab_unrecoverable'))
      : this.resolveTitle(normalizedError, isCustomHomepage);
    const summary = this.resolveSummary(targetUrl, host, input.crashed, isCustomHomepage);
    const detailParts: string[] = [];
    if (input.runtimeDegradedMessage.trim().length > 0) {
      detailParts.push(input.runtimeDegradedMessage.trim());
    }

    return {
      title: title,
      summary: summary,
      host: host.length > 0 ? host : resolveAppResourceText($r('app.string.web_runtime_current_page')),
      primaryActionLabel: resolveAppResourceText($r('app.string.browser_ui_browser_web_error_surface_001')),
      secondaryActionLabel: isCustomHomepage
        ? resolveAppResourceText($r('app.string.web_error_edit_homepage'))
        : resolveAppResourceText($r('app.string.browser_ui_browser_web_error_surface_002')),
      tertiaryActionLabel: isCustomHomepage
        ? ''
        : resolveAppResourceText($r('app.string.settings_sync_advanced_copy_details')),
      detailLabel: resolveAppResourceText($r('app.string.browser_ui_browser_web_error_surface_003')),
      detailText: detailParts.join('\n'),
      hints: this.resolveHints(normalizedError, input.crashed, isCustomHomepage)
    };
  }

  private resolveTitle(errorMessage: string, isCustomHomepage: boolean): string {
    if (isCustomHomepage) {
      return resolveAppResourceText($r('app.string.web_error_homepage_title'));
    }
    const normalized = errorMessage.toLowerCase();
    if (normalized.indexOf('ssl') >= 0 || normalized.indexOf('certificate') >= 0 || normalized.indexOf('证书') >= 0) {
      return resolveAppResourceText($r('app.string.web_error_certificate_title'));
    }
    if (normalized.indexOf('dns') >= 0 || normalized.indexOf('name_not_resolved') >= 0) {
      return resolveAppResourceText($r('app.string.web_error_site_not_found'));
    }
    return resolveAppResourceText($r('app.string.web_error_site_unavailable'));
  }

  private resolveSummary(targetUrl: string, host: string, crashed: boolean, isCustomHomepage: boolean): string {
    if (crashed) {
      return resolveAppResourceText($r('app.string.web_error_tab_crashed'));
    }
    if (isCustomHomepage) {
      return host.length > 0 ? host : resolveAppResourceText($r('app.string.web_error_homepage_unavailable'));
    }
    const normalizedTargetUrl = targetUrl.trim();
    if (normalizedTargetUrl.length > 0) {
      return normalizedTargetUrl;
    }
    return host.length > 0 ? host : resolveAppResourceText($r('app.string.web_runtime_current_page'));
  }

  private resolveHints(errorMessage: string, crashed: boolean, isCustomHomepage: boolean): string[] {
    if (crashed) {
      return [
        resolveAppResourceText($r('app.string.web_error_hint_reload')),
        resolveAppResourceText($r('app.string.web_error_hint_home_retry')),
        resolveAppResourceText($r('app.string.web_error_hint_copy'))
      ];
    }
    if (isCustomHomepage) {
      return [];
    }
    const normalized = errorMessage.toLowerCase();
    if (normalized.indexOf('ssl') >= 0 || normalized.indexOf('certificate') >= 0 || normalized.indexOf('证书') >= 0) {
      return [
        resolveAppResourceText($r('app.string.web_error_hint_time')),
        resolveAppResourceText($r('app.string.web_error_hint_cert')),
        resolveAppResourceText($r('app.string.web_error_hint_copy'))
      ];
    }
    return [
      resolveAppResourceText($r('app.string.web_error_hint_network')),
      resolveAppResourceText($r('app.string.web_error_hint_url')),
      resolveAppResourceText($r('app.string.web_error_hint_proxy'))
    ];
  }

  private resolveTargetUrl(url: string, pendingUrl: string): string {
    const normalizedPendingUrl = pendingUrl.trim();
    if (normalizedPendingUrl.length > 0) {
      return normalizedPendingUrl;
    }
    return url.trim();
  }

  private normalizeErrorMessage(errorMessage: string): string {
    return errorMessage.trim();
  }

  private extractHost(url: string): string {
    const trimmed = url.trim();
    if (trimmed.length === 0) {
      return '';
    }
    const withoutScheme = trimmed.replace(/^[a-z][a-z0-9+.-]*:\/\//i, '');
    const slashIndex = withoutScheme.indexOf('/');
    const hostWithPort = slashIndex >= 0 ? withoutScheme.substring(0, slashIndex) : withoutScheme;
    const atIndex = hostWithPort.lastIndexOf('@');
    return (atIndex >= 0 ? hostWithPort.substring(atIndex + 1) : hostWithPort).trim();
  }
}
