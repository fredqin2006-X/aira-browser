import { webview } from '@kit.ArkWeb';
import { resolveAppResourceText } from '../resources/AppResourceText';
import { AIRA_DISTRIBUTION_CAPABILITY_OWNER } from '../../common/config/AiraDistributionCapabilityOwner';
import { AIRA_FEATURE_PHONE_PAGE_PUSH } from '../../common/constants/MembershipFeatureKeys';
import {
  AiraPersonalServerConfig,
  AiraSyncSettings,
  resolveAiraHuaweiAccountIdentity
} from '../../common/models/AiraSyncModels';
import { EntitlementContext } from '../../services/membership/EntitlementService';
import {
  AiraPhonePagePushFunctionService,
  AiraPhonePagePushResponseBody
} from '../../services/push/AiraPhonePagePushFunctionService';
import { AiraSyncConfigStore } from '../../services/sync/AiraSyncConfigStore';
import { HuaweiAccountSyncAuthService } from '../../services/sync/HuaweiAccountSyncAuthService';
import { AIRA_PERSONAL_SERVER_INSTANCE_SERVICE } from '../../services/sync/AiraPersonalServerInstanceService';
import { FeatureGateCoordinator } from '../membership/FeatureGateCoordinator';

interface BrowserPhonePageCanonicalProbePayload {
  matchesOriginal?: boolean;
  canonicalUrl?: string;
}

export interface BrowserPhonePagePushRequest {
  uid: string;
  url: string;
  desktopUrl: string;
  title: string;
}

export interface BrowserPhonePagePushSnapshot {
  entitlementContext: EntitlementContext;
  uid: string;
  url: string;
  title: string;
  controller: webview.WebviewController | undefined;
}

export interface BrowserPhonePagePushHost {
  resolveSnapshot: () => BrowserPhonePagePushSnapshot;
  showToast: (message: string) => void;
}

export class BrowserPhonePagePushCoordinator {
  private readonly featureGateCoordinator: FeatureGateCoordinator;
  private readonly syncConfigStore: AiraSyncConfigStore;
  private service: AiraPhonePagePushFunctionService;
  private authService: HuaweiAccountSyncAuthService;

  constructor(
    featureGateCoordinator: FeatureGateCoordinator,
    syncConfigStore: AiraSyncConfigStore,
    service: AiraPhonePagePushFunctionService = new AiraPhonePagePushFunctionService(),
    authService: HuaweiAccountSyncAuthService = new HuaweiAccountSyncAuthService()
  ) {
    this.featureGateCoordinator = featureGateCoordinator;
    this.syncConfigStore = syncConfigStore;
    this.service = service;
    this.authService = authService;
  }

  async sendCurrentPageFromHost(host: BrowserPhonePagePushHost): Promise<void> {
    const settings = await this.syncConfigStore.initialize();
    if (settings.remoteKind === 'self_hosted') {
      try {
        const config = AIRA_PERSONAL_SERVER_INSTANCE_SERVICE.requireConfigured(settings);
        const snapshot = host.resolveSnapshot();
        const url = snapshot.url.trim();
        const desktopUrl = await this.resolveDesktopUrl(snapshot.controller, url);
        await this.enqueueCurrentPage({
          uid: '',
          url: url,
          desktopUrl: desktopUrl,
          title: this.resolveTitle(snapshot.title, url)
        }, host, config);
      } catch (error) {
        host.showToast(this.resolveErrorMessage(error as Error, resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_010'))));
      }
      return;
    }
    if (!AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('aira_cloud')) {
      host.showToast(AIRA_DISTRIBUTION_CAPABILITY_OWNER.resolveUnavailableReason('aira_cloud'));
      return;
    }
    const accessSnapshot = host.resolveSnapshot();
    const uid = await this.resolveAccountUid(settings, accessSnapshot.uid);
    if (uid.length === 0) {
      host.showToast(resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_009')));
      return;
    }
    if (!await this.featureGateCoordinator.ensureAccess(
      AIRA_FEATURE_PHONE_PAGE_PUSH,
      accessSnapshot.entitlementContext
    )) {
      return;
    }
    const url = accessSnapshot.url.trim();
    const desktopUrl = await this.resolveDesktopUrl(accessSnapshot.controller, url);
    const request: BrowserPhonePagePushRequest = {
      uid: uid,
      url: url,
      desktopUrl: desktopUrl,
      title: this.resolveTitle(accessSnapshot.title, url)
    };
    await this.enqueueCurrentPage(request, host);
  }

  /**
   * Page push follows the signed-in account, not the active sync provider. Settings win,
   * then the live Huawei session, then whatever the shell already resolved.
   */
  private async resolveAccountUid(settings: AiraSyncSettings, snapshotUid: string): Promise<string> {
    const storedUid = resolveAiraHuaweiAccountIdentity(settings.huaweiCloud, settings.huaweiSpace).uid.trim();
    if (storedUid.length > 0) {
      return storedUid;
    }
    try {
      const identity = await this.authService.getCurrentIdentity();
      const liveUid = identity === undefined ? '' : identity.uid.trim();
      if (liveUid.length > 0) {
        return liveUid;
      }
    } catch (_error) {
      // A missing session is the same as not being signed in.
    }
    return snapshotUid.trim();
  }

  private async enqueueCurrentPage(
    request: BrowserPhonePagePushRequest,
    host: BrowserPhonePagePushHost,
    personalServerConfig?: AiraPersonalServerConfig
  ): Promise<void> {
    const url = request.url.trim();
    if (url.length <= 0) {
      host.showToast(resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_002')));
      return;
    }
    host.showToast(resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_007')));
    try {
      const result = personalServerConfig === undefined
        ? await this.service.enqueue(
          request.uid.trim(),
          url,
          request.title.trim(),
          request.desktopUrl.trim()
        )
        : await this.service.enqueuePersonalServer(
          personalServerConfig.baseUrl,
          personalServerConfig.deviceToken,
          url,
          request.title.trim(),
          request.desktopUrl.trim()
        );
      if (result.ok === true) {
        host.showToast(this.resolveSuccessMessage(result));
        return;
      }
      host.showToast(this.resolveFailureMessage(result, personalServerConfig !== undefined));
    } catch (_error) {
      host.showToast(resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_006')));
    }
  }

  private async resolveDesktopUrl(
    controller: webview.WebviewController | undefined,
    originalUrl: string
  ): Promise<string> {
    const normalizedOriginalUrl = originalUrl.trim();
    if (controller === undefined || !this.isHttpUrl(normalizedOriginalUrl)) {
      return '';
    }
    try {
      const raw = await controller.runJavaScript(this.buildCanonicalUrlProbeScript(normalizedOriginalUrl));
      const probe = this.parseCanonicalProbe(raw ?? '');
      if (probe === undefined || probe.matchesOriginal !== true) {
        return '';
      }
      const candidate = probe.canonicalUrl?.trim() ?? '';
      if (!this.isHttpUrl(candidate) || candidate === normalizedOriginalUrl) {
        return '';
      }
      return candidate;
    } catch (_error) {
      return '';
    }
  }

  private buildCanonicalUrlProbeScript(originalUrl: string): string {
    const encodedOriginalUrl = JSON.stringify(originalUrl);
    return `
(() => {
  var result = { matchesOriginal: false, canonicalUrl: '' };
  try {
    var currentUrl = new URL(window.location.href).href;
    var expectedUrl = new URL(${encodedOriginalUrl}, window.location.href).href;
    if (currentUrl !== expectedUrl) {
      return JSON.stringify(result);
    }
    result.matchesOriginal = true;
    var links = document.querySelectorAll('link[rel][href]');
    var normalizeLeadingSiteHost = function(hostname) {
      var labels = String(hostname || '').trim().toLowerCase().split('.');
      if (labels.length > 0 && ['www', 'm', 'mobile', 'wap', 'touch'].indexOf(labels[0]) >= 0) {
        labels.shift();
      }
      return labels.join('.');
    };
    var hasRegistrableShape = function(hostname) {
      var labels = String(hostname || '').split('.');
      if (labels.length < 2) {
        return false;
      }
      var countrySecondLevel = ['ac', 'co', 'com', 'edu', 'gov', 'net', 'org'];
      var lastLabel = labels[labels.length - 1];
      var previousLabel = labels[labels.length - 2];
      return lastLabel.length !== 2 || countrySecondLevel.indexOf(previousLabel) < 0 || labels.length >= 3;
    };
    var trustedInternalMobilePairs = {
      'item.m.jd.com>item.jd.com': true,
      'item.jd.com>item.m.jd.com': true
    };
    var currentHost = new URL(currentUrl).hostname.toLowerCase();
    for (var index = 0; index < links.length; index += 1) {
      var link = links[index];
      var rel = String(link.getAttribute('rel') || '').toLowerCase().split(/\\s+/);
      if (rel.indexOf('canonical') < 0) {
        continue;
      }
      var href = String(link.getAttribute('href') || '').trim();
      if (!href) {
        continue;
      }
      var candidateUrl = new URL(href, document.baseURI || currentUrl);
      var candidateHost = candidateUrl.hostname.toLowerCase();
      var normalizedCurrentHost = normalizeLeadingSiteHost(currentHost);
      var normalizedCandidateHost = normalizeLeadingSiteHost(candidateHost);
      var sameHost = candidateHost === currentHost;
      var trustedLeadingVariant = normalizedCandidateHost === normalizedCurrentHost &&
        hasRegistrableShape(normalizedCurrentHost);
      var trustedInternalVariant = trustedInternalMobilePairs[currentHost + '>' + candidateHost] === true;
      if (!sameHost && !trustedLeadingVariant && !trustedInternalVariant) {
        continue;
      }
      result.canonicalUrl = candidateUrl.href;
      break;
    }
  } catch (_error) {
  }
  return JSON.stringify(result);
})()
`;
  }

  private parseCanonicalProbe(raw: string): BrowserPhonePageCanonicalProbePayload | undefined {
    const normalized = this.unwrapJavaScriptString(raw).trim();
    if (normalized.length <= 0) {
      return undefined;
    }
    try {
      return JSON.parse(normalized) as BrowserPhonePageCanonicalProbePayload;
    } catch (_error) {
      return undefined;
    }
  }

  private unwrapJavaScriptString(raw: string): string {
    if (raw.length >= 2 && raw.charAt(0) === '"' && raw.charAt(raw.length - 1) === '"') {
      try {
        const decoded = JSON.parse(raw) as string;
        return typeof decoded === 'string' ? decoded : raw;
      } catch (_error) {
      }
    }
    return raw;
  }

  private resolveTitle(title: string, fallbackUrl: string): string {
    const normalizedTitle = title.trim();
    return normalizedTitle.length > 0 ? normalizedTitle : fallbackUrl;
  }

  private isHttpUrl(url: string): boolean {
    const lower = url.trim().toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  private resolveSuccessMessage(result: AiraPhonePagePushResponseBody): string {
    switch (result.code) {
      case 'phone_page_push_duplicate_pending':
        return resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_014'));
      case 'phone_page_push_duplicate_recent':
        return resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_013'));
      default:
        return resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_001'));
    }
  }

  private resolveFailureMessage(result: AiraPhonePagePushResponseBody, personalServer: boolean): string {
    switch (result.code) {
      case 'pro_required':
        return resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_015'));
      case 'phone_page_push_rate_limited':
      case 'page_push_rate_limited':
        return resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_005'));
      case 'phone_page_push_queue_full':
      case 'page_push_queue_full':
        return resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_008'));
      case 'no_online_desktop_device':
        return resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_003'));
      case 'page_push_phone_required':
      case 'personal_server_auth_required':
      case 'invalid_device_credential':
      case 'device_revoked':
        return resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_012'));
      case 'missing_uid':
      case 'auth_token_required':
      case 'auth_token_expired':
        return personalServer
          ? resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_012'))
          : resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_011'));
      case 'invalid_url':
      case 'invalid_page_url':
        return resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_004'));
      case 'distribution_unavailable':
        return result.message?.trim() || AIRA_DISTRIBUTION_CAPABILITY_OWNER.resolveUnavailableReason('aira_cloud');
      default:
        return result.message?.trim() || resolveAppResourceText($r('app.string.browser_browser_phone_page_push_coordinator_006'));
    }
  }

  private resolveErrorMessage(error: Error, fallback: string): string {
    const message = error.message?.trim() ?? '';
    return message.length > 0 ? message : fallback;
  }
}
