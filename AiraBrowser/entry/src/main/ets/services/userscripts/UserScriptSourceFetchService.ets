import { connection, http } from '@kit.NetworkKit';
import { NativeHttpProxyResolutionService } from '../network/NativeHttpProxyResolutionService';
import { UserScriptInstallSourceResolver } from './UserScriptInstallSourceResolver';
import { UserScriptInstallUrlService } from './UserScriptInstallUrlService';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';

export interface UserScriptSourceFetchResult {
  ok: boolean;
  source: string;
  /**
   * The address the returned source actually came from.
   *
   * A resolved install source can differ from the requested URL (a Gitee external link, a GreasyFork
   * mirror page, a ScriptCat preview URL), and the stored `sourceUrl` decides how a relative `@icon`
   * resolves and which address update checks revisit later.
   */
  sourceUrl: string;
  errorMessage: string;
}

export const USER_SCRIPT_SOURCE_OFFLINE_MESSAGE: string =
  resolveAppResourceText($r('app.string.user_script_source_offline'));
export const USER_SCRIPT_SOURCE_UNREACHABLE_MESSAGE: string =
  resolveAppResourceText($r('app.string.user_script_source_unreachable'));
export const USER_SCRIPT_SOURCE_DOWNLOAD_FAILED_MESSAGE: string =
  resolveAppResourceText($r('app.string.user_script_source_download_failed'));

const USER_SCRIPT_HTTP_ERROR_BASE: number = 2300000;
const USER_SCRIPT_UNREACHABLE_CURL_CODES: number[] = [5, 6, 7, 28, 35, 52, 55, 56];

export interface UserScriptHttpErrorShape {
  code?: number | string;
  message?: string;
}

export function readUserScriptHttpErrorCode(error: Object): number {
  const shaped = error as UserScriptHttpErrorShape;
  if (typeof shaped.code === 'number' && Number.isFinite(shaped.code)) {
    return shaped.code;
  }
  if (typeof shaped.code === 'string') {
    const parsed = Number(shaped.code);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

export function isUserScriptSourceUnreachableErrorCode(code: number): boolean {
  if (!Number.isFinite(code) || code === 0) {
    return false;
  }
  const curlCode = code > USER_SCRIPT_HTTP_ERROR_BASE ? code - USER_SCRIPT_HTTP_ERROR_BASE : code;
  return USER_SCRIPT_UNREACHABLE_CURL_CODES.indexOf(curlCode) >= 0;
}

export function describeUserScriptSourceTransportFailure(error: UserScriptHttpErrorShape): string {
  if (isUserScriptSourceUnreachableErrorCode(readUserScriptHttpErrorCode(error))) {
    return USER_SCRIPT_SOURCE_UNREACHABLE_MESSAGE;
  }
  const shaped = error as UserScriptHttpErrorShape;
  const message = typeof shaped.message === 'string' ? shaped.message : '';
  if (isUserScriptUnreachableTransportText(message)) {
    return USER_SCRIPT_SOURCE_UNREACHABLE_MESSAGE;
  }
  return USER_SCRIPT_SOURCE_DOWNLOAD_FAILED_MESSAGE;
}

function isUserScriptUnreachableTransportText(message: string): boolean {
  const normalized = message.trim().toLowerCase();
  if (normalized.length === 0) {
    return false;
  }
  return normalized.indexOf('couldn\'t resolve host') >= 0 ||
    normalized.indexOf('could not resolve host') >= 0 ||
    normalized.indexOf('failed to resolve the host') >= 0 ||
    normalized.indexOf('couldn\'t connect') >= 0 ||
    normalized.indexOf('failed to connect') >= 0 ||
    normalized.indexOf('operation timeout') >= 0 ||
    normalized.indexOf('timeout was reached') >= 0 ||
    normalized.indexOf('couldn\'t resolve proxy') >= 0;
}

const USER_SCRIPT_SOURCE_FETCH_TIMEOUT_MS: number = 12000;
// http.request receives at most 5 MB unless maxLimit is set. From API 23 the receive ceiling is 50 MB.
const MAX_USER_SCRIPT_SOURCE_BYTES: number = 50 * 1024 * 1024;
const USER_SCRIPT_SOURCE_TOO_LARGE_MESSAGE: string = resolveAppResourceText($r('app.string.user_script_source_too_large'));
const USER_SCRIPT_METADATA_MARKER: string = '// ==UserScript==';

export class UserScriptSourceFetchService {
  private installUrlService: UserScriptInstallUrlService = new UserScriptInstallUrlService();
  private installSourceResolver: UserScriptInstallSourceResolver = new UserScriptInstallSourceResolver();
  private proxyResolutionService: NativeHttpProxyResolutionService | undefined = undefined;

  constructor(proxyResolutionService?: NativeHttpProxyResolutionService) {
    this.proxyResolutionService = proxyResolutionService;
  }

  async fetchSource(url: string, allowAnyHttpScriptUrl: boolean = false): Promise<UserScriptSourceFetchResult> {
    const trimmedUrl = url.trim();
    if (!this.isHttpUrl(trimmedUrl)) {
      return this.fail(resolveAppResourceText($r('app.string.user_script_source_http_url')));
    }
    if (!allowAnyHttpScriptUrl && !this.installUrlService.canInstallFromUrl(trimmedUrl)) {
      return this.fail(resolveAppResourceText($r('app.string.user_script_source_not_user_js')));
    }
    if (!this.hasDefaultNetwork()) {
      return this.fail(USER_SCRIPT_SOURCE_OFFLINE_MESSAGE);
    }
    const sourceUrls = this.installSourceResolver.resolveSourceUrls(trimmedUrl);
    let failure: UserScriptSourceFetchResult | undefined = undefined;
    let sawNonScript = false;
    for (let index = 0; index < sourceUrls.length; index++) {
      const result = await this.fetchExactSource(sourceUrls[index]);
      if (!result.ok) {
        failure = this.preferSourceFetchFailure(failure, result);
        continue;
      }
      if (!this.looksLikeUserScript(result.source)) {
        sawNonScript = true;
        continue;
      }
      return result;
    }
    if (sawNonScript && (failure === undefined || !this.isReachabilityFailure(failure))) {
      return this.fail(resolveAppResourceText($r('app.string.user_script_source_no_metadata')));
    }
    if (failure === undefined) {
      return this.fail(USER_SCRIPT_SOURCE_DOWNLOAD_FAILED_MESSAGE);
    }
    return failure;
  }

  private async fetchExactSource(url: string): Promise<UserScriptSourceFetchResult> {
    const request = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: USER_SCRIPT_SOURCE_FETCH_TIMEOUT_MS,
        readTimeout: USER_SCRIPT_SOURCE_FETCH_TIMEOUT_MS,
        maxLimit: MAX_USER_SCRIPT_SOURCE_BYTES,
        usingCache: true,
        header: {
          'Accept': 'text/javascript,application/javascript,text/plain,*/*;q=0.8',
          'User-Agent': 'AiraBrowser/1.0'
        }
      };
      this.applyNativeProxy(options);
      const response = await request.request(url, options);
      if (response.responseCode === 0) {
        return this.fail(USER_SCRIPT_SOURCE_UNREACHABLE_MESSAGE);
      }
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return this.fail(this.describeHttpStatusFailure(response.responseCode));
      }
      if (typeof response.result !== 'string') {
        return this.fail(USER_SCRIPT_SOURCE_DOWNLOAD_FAILED_MESSAGE);
      }
      const source = response.result.trim();
      if (source.length === 0) {
        return this.fail(resolveAppResourceText($r('app.string.user_script_source_empty')));
      }
      if (source.length > MAX_USER_SCRIPT_SOURCE_BYTES) {
        return this.fail(USER_SCRIPT_SOURCE_TOO_LARGE_MESSAGE);
      }
      return {
        ok: true,
        source: source,
        sourceUrl: url,
        errorMessage: ''
      };
    } catch (error) {
      return this.fail(describeUserScriptSourceTransportFailure(error as UserScriptHttpErrorShape));
    } finally {
      request.destroy();
    }
  }

  private applyNativeProxy(options: http.HttpRequestOptions): void {
    const service = this.proxyResolutionService;
    if (service === undefined) {
      return;
    }
    const usingProxy = service.resolveFromCurrentPreferences().usingProxy;
    if (usingProxy !== undefined) {
      options.usingProxy = usingProxy;
    }
  }

  private hasDefaultNetwork(): boolean {
    try {
      return connection.hasDefaultNetSync();
    } catch (_error) {
      return true;
    }
  }

  private describeHttpStatusFailure(status: number): string {
    return resolveAppResourceText($r('app.string.user_script_source_http_status'), `${status}`);
  }

  private preferSourceFetchFailure(
    current: UserScriptSourceFetchResult | undefined,
    next: UserScriptSourceFetchResult
  ): UserScriptSourceFetchResult {
    if (current === undefined || this.isGenericDownloadFailure(current)) {
      return next;
    }
    if (this.isReachabilityFailure(next) && !this.isReachabilityFailure(current)) {
      return next;
    }
    return current;
  }

  private isReachabilityFailure(result: UserScriptSourceFetchResult): boolean {
    return result.errorMessage === USER_SCRIPT_SOURCE_UNREACHABLE_MESSAGE ||
      result.errorMessage === USER_SCRIPT_SOURCE_OFFLINE_MESSAGE;
  }

  private isGenericDownloadFailure(result: UserScriptSourceFetchResult): boolean {
    return result.errorMessage === USER_SCRIPT_SOURCE_DOWNLOAD_FAILED_MESSAGE;
  }

  private looksLikeUserScript(source: string): boolean {
    const trimmed = source.trim().toLowerCase();
    if (trimmed.startsWith('<!doctype') || trimmed.startsWith('<html') || trimmed.startsWith('<')) {
      return false;
    }
    return source.indexOf(USER_SCRIPT_METADATA_MARKER) >= 0;
  }

  private isHttpUrl(url: string): boolean {
    const normalized = url.trim().toLowerCase();
    return normalized.startsWith('http://') || normalized.startsWith('https://');
  }

  private fail(message: string): UserScriptSourceFetchResult {
    return {
      ok: false,
      source: '',
      sourceUrl: '',
      errorMessage: message
    };
  }
}
