import { http } from '@kit.NetworkKit';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';
import { HuaweiAccountSyncAuthService } from '../sync/HuaweiAccountSyncAuthService';
import {
  AIRA_DISTRIBUTION_CAPABILITY_OWNER,
  AIRA_HOSTED_API_BASE_URL
} from '../../common/config/AiraDistributionCapabilityOwner';
import { AiraMembershipGrantResponseRecord } from './AiraMembershipStateFunctionService';

const AIRA_MEMBERSHIP_REDEEM_ENDPOINT: string = AIRA_HOSTED_API_BASE_URL + '/membership/redeem';
const AIRA_MEMBERSHIP_REDEEM_TIMEOUT_MS: number = 30000;
const AIRA_MEMBERSHIP_REDEEM_DOH_ENDPOINT: string = 'https://223.5.5.5/dns-query';

export interface AiraMembershipRedeemRequestBody {
  uid: string;
  code: string;
  source: string;
  authToken?: string;
}

export interface AiraMembershipRedeemResponseBody {
  ok?: boolean;
  code?: string;
  message?: string;
  kind?: string;
  uidSuffix?: string;
  membershipGrant?: AiraMembershipGrantResponseRecord | null;
  entitlementProof?: string | null;
}

export interface AiraMembershipRedeemHttpAdapter {
  post(url: string, body: AiraMembershipRedeemRequestBody, timeoutMs: number):
    Promise<Object | string | null | undefined>;
}

class NetworkAiraMembershipRedeemHttpAdapter implements AiraMembershipRedeemHttpAdapter {
  async post(
    url: string,
    body: AiraMembershipRedeemRequestBody,
    timeoutMs: number
  ): Promise<Object | string | null | undefined> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.POST,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: timeoutMs,
        readTimeout: timeoutMs,
        usingCache: false,
        dnsOverHttps: AIRA_MEMBERSHIP_REDEEM_DOH_ENDPOINT,
        header: {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=utf-8',
          'User-Agent': 'AiraBrowser/1.0'
        },
        extraData: JSON.stringify(body)
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        const errorResponse: AiraMembershipRedeemResponseBody = {
          ok: false,
          code: 'http_error',
          message: resolveAppResourceText($r('app.string.membership_service_http_failed',
            resolveAppResourceText($r('app.string.membership_service_redeem')), response.responseCode))
        };
        return errorResponse;
      }
      return response.result as string | Object | null | undefined;
    } finally {
      request.destroy();
    }
  }
}

export class AiraMembershipRedeemFunctionService {
  private adapter: AiraMembershipRedeemHttpAdapter;
  private authService: HuaweiAccountSyncAuthService;

  constructor(adapter?: AiraMembershipRedeemHttpAdapter, authService?: HuaweiAccountSyncAuthService) {
    this.adapter = adapter ?? new NetworkAiraMembershipRedeemHttpAdapter();
    this.authService = authService ?? new HuaweiAccountSyncAuthService();
  }

  /**
   * Asks the hosted service to redeem one code. The service decides whether the
   * code can be consumed and returns the grant to store. The client does not
   * invent a local membership.
   */
  async redeem(uid: string, code: string): Promise<AiraMembershipRedeemResponseBody> {
    if (!AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('aira_cloud')) {
      return {
        ok: false,
        code: 'distribution_unavailable',
        message: AIRA_DISTRIBUTION_CAPABILITY_OWNER.resolveUnavailableReason('aira_cloud')
      };
    }
    const normalizedUid = uid.trim();
    if (normalizedUid.length <= 0) {
      return {
        ok: false,
        code: 'missing_uid',
        message: resolveAppResourceText($r('app.string.membership_login_required'))
      };
    }
    const body: AiraMembershipRedeemRequestBody = {
      uid: normalizedUid,
      code: code.trim(),
      source: 'app'
    };
    try {
      const token = await this.authService.getCurrentAccessTokenForUid(normalizedUid, false);
      if (token.length > 0) {
        body.authToken = token;
      }
    } catch (_error) {
      body.authToken = undefined;
    }
    const value = await this.adapter.post(
      AIRA_MEMBERSHIP_REDEEM_ENDPOINT,
      body,
      AIRA_MEMBERSHIP_REDEEM_TIMEOUT_MS
    );
    return this.parseFunctionValue(value);
  }

  private parseFunctionValue(value: Object | string | null | undefined): AiraMembershipRedeemResponseBody {
    if (value === undefined || value === null) {
      return {
        ok: false,
        code: 'empty_response',
        message: resolveAppResourceText($r('app.string.membership_service_empty',
          resolveAppResourceText($r('app.string.membership_service_redeem'))))
      };
    }
    if (typeof value === 'string') {
      try {
        return this.parseFunctionObject(JSON.parse(value) as Object);
      } catch (_error) {
        return {
          ok: false,
          code: 'invalid_response',
          message: resolveAppResourceText($r('app.string.membership_service_invalid_json',
            resolveAppResourceText($r('app.string.membership_service_redeem'))))
        };
      }
    }
    return this.parseFunctionObject(value);
  }

  private parseFunctionObject(value: Object): AiraMembershipRedeemResponseBody {
    const raw = value as Record<string, Object | string | boolean | number | Object[] | undefined | null>;
    const body = raw.body;
    if (typeof body === 'string') {
      try {
        return JSON.parse(body) as AiraMembershipRedeemResponseBody;
      } catch (_error) {
        return {
          ok: false,
          code: 'invalid_response_body',
          message: resolveAppResourceText($r('app.string.membership_service_invalid_body',
            resolveAppResourceText($r('app.string.membership_service_redeem'))))
        };
      }
    }
    if (body !== undefined && body !== null && typeof body === 'object') {
      return body as AiraMembershipRedeemResponseBody;
    }
    return raw as AiraMembershipRedeemResponseBody;
  }
}
