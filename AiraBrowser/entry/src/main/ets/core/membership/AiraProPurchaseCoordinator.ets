import { common } from '@kit.AbilityKit';
import { AIRA_ENABLE_DEVELOPMENT_DIAGNOSTICS } from '../../common/config/BuildVariantFlags';
import {
  HuaweiIapProductView,
  HuaweiIapOperationResult,
  HuaweiIapPurchaseService
} from '../../services/membership/HuaweiIapPurchaseService';
import {
  HuaweiIapVerificationFunctionService,
  HuaweiIapVerificationResponseBody
} from '../../services/membership/HuaweiIapVerificationFunctionService';
import {
  isAiraProLifetimeProductId,
  isAiraProIapPlanId,
  isAiraProSellablePlanId
} from '../../services/membership/HuaweiIapProductCatalog';
import {
  AiraProPlanPurchaseAction,
  AiraProPurchasePolicyService
} from '../../services/membership/AiraProPurchasePolicyService';
import { MembershipFeature } from '../../features/membership/MembershipFeature';
import { BrowserDataBoundaryInput } from '../../common/models/BrowserModels';
import { BrowserProfileBoundaryService } from '../browser/BrowserProfileBoundaryService';
import {
  BrowserPrivacyEffectIntent,
  BrowserPrivacyEffectPolicyService
} from '../../services/privacy/BrowserPrivacyEffectPolicyService';

const HUAWEI_IAP_ALREADY_OWNS_PRODUCT_ERROR_CODE: number = 1001860051;
const AIRA_IAP_SUBSCRIPTION_EXPIRED_CODE: string = 'subscription_expired';
const AIRA_PRO_ONE_TIME_PLAN_ID: string = 'one_time';
const LIFETIME_UPGRADE_REFRESH_DELAYS_MS: number[] = [0, 800, 1600];

export interface AiraProPurchaseFlowHost {
  onMembershipStateChanged(): void;
  onLoginRequired(): void;
  showMessage(message: ResourceStr): void;
}

export class AiraProPurchaseFlowHostAdapter implements AiraProPurchaseFlowHost {
  private membershipStateChangedHandler: () => void;
  private loginRequiredHandler: () => void;
  private messageHandler: (message: ResourceStr) => void;

  constructor(
    membershipStateChangedHandler: () => void,
    loginRequiredHandler: () => void,
    messageHandler: (message: ResourceStr) => void
  ) {
    this.membershipStateChangedHandler = membershipStateChangedHandler;
    this.loginRequiredHandler = loginRequiredHandler;
    this.messageHandler = messageHandler;
  }

  onMembershipStateChanged(): void {
    this.membershipStateChangedHandler();
  }

  onLoginRequired(): void {
    this.loginRequiredHandler();
  }

  showMessage(message: ResourceStr): void {
    this.messageHandler(message);
  }
}

export interface AiraProPurchaseIapAdapter {
  startProPurchase(context: common.UIAbilityContext, period?: string, uid?: string): Promise<HuaweiIapOperationResult>;
  queryProProducts(context: common.UIAbilityContext): Promise<HuaweiIapProductView[]>;
  restorePurchases(context: common.UIAbilityContext): Promise<HuaweiIapOperationResult>;
  finishPurchase(
    context: common.UIAbilityContext,
    purchaseData: string,
    verifiedProductType?: string
  ): Promise<void>;
  openSubscriptionManagement(context: common.UIAbilityContext): Promise<HuaweiIapOperationResult>;
}

interface VerifiedPurchaseSubmission {
  verification: HuaweiIapVerificationResponseBody;
  purchaseData: string;
}

export class AiraProPurchaseCoordinator {
  private membershipFeature?: MembershipFeature;
  private iapService: AiraProPurchaseIapAdapter;
  private verificationService: HuaweiIapVerificationFunctionService;
  private showDiagnosticMessages: boolean;
  private purchasePolicyService: AiraProPurchasePolicyService;
  private privacyEffectPolicy: BrowserPrivacyEffectPolicyService;
  private profileBoundaryService: BrowserProfileBoundaryService;
  private awaitingSubscriptionManagementReturn: boolean = false;
  private subscriptionManagementRefreshPromise?: Promise<void>;

  constructor(
    membershipFeature?: MembershipFeature,
    iapService: AiraProPurchaseIapAdapter = new HuaweiIapPurchaseService(),
    verificationService: HuaweiIapVerificationFunctionService = new HuaweiIapVerificationFunctionService(),
    showDiagnosticMessages: boolean = AIRA_ENABLE_DEVELOPMENT_DIAGNOSTICS,
    purchasePolicyService: AiraProPurchasePolicyService = new AiraProPurchasePolicyService(),
    privacyEffectPolicy: BrowserPrivacyEffectPolicyService = new BrowserPrivacyEffectPolicyService(),
    profileBoundaryService: BrowserProfileBoundaryService = new BrowserProfileBoundaryService()
  ) {
    this.membershipFeature = membershipFeature;
    this.iapService = iapService;
    this.verificationService = verificationService;
    this.showDiagnosticMessages = showDiagnosticMessages;
    this.purchasePolicyService = purchasePolicyService;
    this.privacyEffectPolicy = privacyEffectPolicy;
    this.profileBoundaryService = profileBoundaryService;
  }

  async startPurchaseFlow(
    context: common.UIAbilityContext,
    period: string,
    uid: string,
    host: AiraProPurchaseFlowHost,
    boundaryInput: BrowserDataBoundaryInput
  ): Promise<void> {
    try {
      if (!this.isEffectAllowed('membership_purchase', boundaryInput)) {
        host.showMessage($r('app.string.settings_pro_purchase_private'));
        return;
      }
      if (!await this.canStartPlanPurchase(period, host)) {
        return;
      }
      const result = await this.startProPurchase(context, period, uid);
      if (result.verificationCode === 'login_required') {
        host.onLoginRequired();
        return;
      }
      this.showOperationResult(host, result);
      if (result.ok) {
        await this.refreshMembershipAfterPurchaseResult(
          result.verifiedProductId,
          result.verifiedExpiresAt,
          host
        );
      }
    } catch (_error) {
      host.showMessage($r('app.string.settings_pro_purchase_unavailable'));
    }
  }

  async restorePurchaseFlow(
    context: common.UIAbilityContext,
    uid: string,
    period: string,
    host: AiraProPurchaseFlowHost,
    boundaryInput: BrowserDataBoundaryInput
  ): Promise<void> {
    try {
      if (!this.isEffectAllowed('membership_restore_purchase', boundaryInput)) {
        host.showMessage($r('app.string.settings_pro_restore_private'));
        return;
      }
      const result = await this.restorePurchase(context, uid, period);
      if (result.verificationCode === 'login_required') {
        host.onLoginRequired();
        return;
      }
      this.showOperationResult(host, result);
      if (result.ok) {
        await this.refreshMembershipAfterPurchaseResult(
          result.verifiedProductId,
          result.verifiedExpiresAt,
          host
        );
      }
    } catch (_error) {
      host.showMessage($r('app.string.settings_pro_restore_unavailable'));
    }
  }

  async openLifetimeUpgradeSubscriptionManagement(
    context: common.UIAbilityContext,
    host: AiraProPurchaseFlowHost,
    boundaryInput: BrowserDataBoundaryInput
  ): Promise<void> {
    if (!this.isEffectAllowed('membership_subscription_management', boundaryInput)) {
      host.showMessage($r('app.string.settings_pro_manage_private'));
      return;
    }
    this.awaitingSubscriptionManagementReturn = true;
    host.showMessage($r('app.string.settings_pro_manage_hint'));
    try {
      const result = await this.manageSubscription(context);
      if (!result.ok) {
        this.awaitingSubscriptionManagementReturn = false;
        this.showOperationResult(host, result);
        return;
      }
      if (this.awaitingSubscriptionManagementReturn) {
        await this.refreshAfterSubscriptionManagement(host);
      }
    } catch (_error) {
      this.awaitingSubscriptionManagementReturn = false;
      host.showMessage($r('app.string.settings_pro_manage_unavailable'));
    }
  }

  handlePageShow(
    host: AiraProPurchaseFlowHost,
    boundaryInput: BrowserDataBoundaryInput
  ): void {
    if (!this.awaitingSubscriptionManagementReturn) {
      return;
    }
    if (!this.isEffectAllowed('membership_subscription_management', boundaryInput)) {
      this.awaitingSubscriptionManagementReturn = false;
      host.showMessage($r('app.string.settings_pro_manage_private'));
      return;
    }
    this.refreshAfterSubscriptionManagement(host).catch((_error: Error) => {
      host.showMessage($r('app.string.settings_pro_subscription_check_failed'));
    });
  }

  private async startProPurchase(
    context: common.UIAbilityContext,
    period: string = 'monthly',
    uid: string = ''
  ): Promise<HuaweiIapOperationResult> {
    // Monthly, yearly, and the long-term plan are all sold from the renewal
    // sheet. Permanent membership is the non-consumable aira_pro_lifetime purchase.
    if (!isAiraProSellablePlanId(period) && period.trim().toLowerCase() !== 'one_time') {
      return this.buildUnsupportedPlanResult(period, 'purchase_pro_monthly');
    }
    if (uid.trim().length <= 0) {
      return this.buildLoginRequiredResult(
        period.trim().toLowerCase() === 'one_time' ? 'purchase_pro_one_time' : 'purchase_pro_monthly'
      );
    }
    const result = await this.iapService.startProPurchase(context, period, uid);
    if (!result.ok && result.errorCode === HUAWEI_IAP_ALREADY_OWNS_PRODUCT_ERROR_CODE) {
      const restoreResult = await this.iapService.restorePurchases(context);
      const restoredResult = await this.submitPurchaseDataIfNeeded(context, restoreResult, uid, 'restore');
      if (!restoredResult.ok && restoredResult.verificationCode === AIRA_IAP_SUBSCRIPTION_EXPIRED_CODE) {
        return this.buildAlreadyOwnsExpiredRestoreResult(result, restoredResult);
      }
      return restoredResult;
    }
    return this.submitPurchaseDataIfNeeded(context, result, uid, 'purchase');
  }

  queryProProducts(context: common.UIAbilityContext): Promise<HuaweiIapProductView[]> {
    return this.iapService.queryProProducts(context);
  }

  private async restorePurchase(
    context: common.UIAbilityContext,
    uid: string = '',
    period: string = 'monthly'
  ): Promise<HuaweiIapOperationResult> {
    if (!isAiraProIapPlanId(period)) {
      return this.buildUnsupportedPlanResult(period, 'restore_purchase');
    }
    if (uid.trim().length <= 0) {
      return this.buildLoginRequiredResult('restore_purchase');
    }
    const result = await this.iapService.restorePurchases(context);
    return this.submitPurchaseDataIfNeeded(context, result, uid, 'restore');
  }

  private manageSubscription(context: common.UIAbilityContext): Promise<HuaweiIapOperationResult> {
    return this.iapService.openSubscriptionManagement(context);
  }

  private isEffectAllowed(
    intent: BrowserPrivacyEffectIntent,
    boundaryInput: BrowserDataBoundaryInput
  ): boolean {
    const requestingBoundary = this.profileBoundaryService.buildBoundary(boundaryInput);
    return this.privacyEffectPolicy.decide({
      intent: intent,
      requestingBoundary: requestingBoundary,
      targetScope: 'remote_account_sync_state',
      targetIsClear: true
    }).outcome === 'allow';
  }

  private async canStartPlanPurchase(period: string, host: AiraProPurchaseFlowHost): Promise<boolean> {
    if (this.membershipFeature === undefined) {
      host.showMessage($r('app.string.settings_pro_status_check_failed'));
      return false;
    }
    const state = await this.membershipFeature.refreshState({ force: true });
    host.onMembershipStateChanged();
    const oneTimeSelected = period.trim().toLowerCase() === AIRA_PRO_ONE_TIME_PLAN_ID;
    const action = oneTimeSelected
      ? this.purchasePolicyService.resolveOneTimePlanAction(state)
      : this.purchasePolicyService.resolveSubscriptionPlanAction(state);
    if (action === 'purchase') {
      return true;
    }
    if (action === 'manage_subscription') {
      host.showMessage($r('app.string.settings_pro_renewal_still_on'));
      return false;
    }
    host.showMessage(this.purchasePolicyService.isLongTermMember(state)
      ? $r('app.string.settings_pro_already_lifetime')
      : $r('app.string.settings_pro_already_subscribed'));
    return false;
  }

  private async refreshAfterSubscriptionManagement(host: AiraProPurchaseFlowHost): Promise<void> {
    if (this.subscriptionManagementRefreshPromise !== undefined) {
      return this.subscriptionManagementRefreshPromise;
    }
    this.awaitingSubscriptionManagementReturn = false;
    const refreshPromise = this.pollLifetimeUpgradeAvailability(host)
      .finally(() => {
        if (this.subscriptionManagementRefreshPromise === refreshPromise) {
          this.subscriptionManagementRefreshPromise = undefined;
        }
      });
    this.subscriptionManagementRefreshPromise = refreshPromise;
    return refreshPromise;
  }

  private async pollLifetimeUpgradeAvailability(host: AiraProPurchaseFlowHost): Promise<void> {
    if (this.membershipFeature === undefined) {
      host.showMessage($r('app.string.settings_pro_status_check_failed'));
      return;
    }
    let action: AiraProPlanPurchaseAction = 'manage_subscription';
    for (const delayMs of LIFETIME_UPGRADE_REFRESH_DELAYS_MS) {
      if (delayMs > 0) {
        await this.delay(delayMs);
      }
      const state = await this.membershipFeature.refreshState({ force: true });
      host.onMembershipStateChanged();
      action = this.purchasePolicyService.resolveOneTimePlanAction(state);
      if (action !== 'manage_subscription') {
        break;
      }
    }
    if (action === 'purchase') {
      host.showMessage($r('app.string.settings_pro_renewal_off_ready'));
      return;
    }
    if (action === 'unavailable') {
      host.showMessage($r('app.string.settings_pro_already_lifetime_short'));
      return;
    }
    host.showMessage($r('app.string.settings_pro_renewal_syncing'));
  }

  private delay(delayMs: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, delayMs);
    });
  }

  private showOperationResult(host: AiraProPurchaseFlowHost, result: HuaweiIapOperationResult): void {
    if (result.silent === true || !this.hasVisibleMessage(result.message)) {
      return;
    }
    host.showMessage(result.message);
  }

  private async refreshMembershipAfterPurchaseResult(
    productId: string | undefined,
    expiresAt: number | undefined,
    host: AiraProPurchaseFlowHost
  ): Promise<void> {
    if (this.membershipFeature === undefined) {
      return;
    }
    if (productId !== undefined && productId.trim().length > 0 && expiresAt !== undefined && expiresAt >= 0) {
      await this.membershipFeature.applyVerifiedIapGrant(productId, expiresAt);
    }
    await this.membershipFeature.refreshState({ force: true });
    host.onMembershipStateChanged();
  }

  private async submitPurchaseDataIfNeeded(
    context: common.UIAbilityContext,
    result: HuaweiIapOperationResult,
    uid: string,
    source: string
  ): Promise<HuaweiIapOperationResult> {
    const purchaseDataList = this.resolvePurchaseDataList(result);
    if (!result.ok || purchaseDataList.length <= 0) {
      return result;
    }
    const submission = await this.submitFirstVerifiablePurchaseData(uid, purchaseDataList, source);
    const verification = submission.verification;
    const finishPurchaseMessage = verification.ok === true
      ? await this.finishVerifiedPurchaseData(context, result, submission.purchaseData, verification)
      : '';
    return {
      ok: result.ok && verification.ok === true,
      title: verification.ok === true ? this.buildSuccessTitle(verification) : result.title,
      message: this.buildVerificationMessage(result, verification, finishPurchaseMessage),
      action: result.action,
      purchaseData: result.purchaseData,
      purchaseDataList: result.purchaseDataList,
      purchaseCount: result.purchaseCount,
      verifiedProductId: verification.ok === true ? verification.productId : undefined,
      verifiedExpiresAt: verification.ok === true ? verification.expiresAt : undefined,
      verificationCode: verification.ok === true ? undefined : verification.code,
      errorCode: result.errorCode
    };
  }

  private resolvePurchaseDataList(result: HuaweiIapOperationResult): string[] {
    const purchaseDataList = result.purchaseDataList ?? [result.purchaseData ?? ''];
    return purchaseDataList
      .map((item: string) => item.trim())
      .filter((item: string) => item.length > 0);
  }

  private async submitFirstVerifiablePurchaseData(
    uid: string,
    purchaseDataList: string[],
    source: string
  ): Promise<VerifiedPurchaseSubmission> {
    let lastVerification: HuaweiIapVerificationResponseBody = {
      ok: false,
      code: 'missing_purchase_data',
      message: ''
    };
    let lastPurchaseData = '';
    for (const purchaseData of purchaseDataList) {
      lastPurchaseData = purchaseData;
      lastVerification = await this.verificationService.submitPurchaseData(uid, purchaseData, source);
      if (lastVerification.ok === true) {
        return {
          verification: lastVerification,
          purchaseData
        };
      }
    }
    return {
      verification: lastVerification,
      purchaseData: lastPurchaseData
    };
  }

  private buildVerificationMessage(
    result: HuaweiIapOperationResult,
    verification: HuaweiIapVerificationResponseBody,
    finishPurchaseMessage: ResourceStr = ''
  ): ResourceStr {
    if (verification.ok === true) {
      if (this.hasVisibleMessage(finishPurchaseMessage)) {
        return finishPurchaseMessage;
      }
      if (this.showDiagnosticMessages) {
        return this.buildDiagnosticVerificationMessage(verification);
      }
      return this.buildUserVerificationMessage(result, verification);
    }
    if (verification.code === 'missing_purchase_data') {
      return $r('app.string.settings_pro_iap_missing_purchase');
    }
    const verificationMessage = verification.message ?? '';
    return verificationMessage.length > 0 ? verificationMessage : result.message;
  }

  private hasVisibleMessage(message: ResourceStr): boolean {
    return typeof message !== 'string' || message.trim().length > 0;
  }

  private buildDiagnosticVerificationMessage(verification: HuaweiIapVerificationResponseBody): string {
    const productText = verification.productId === undefined || verification.productId.length <= 0
      ? ''
      : `商品 ${verification.productId}，`;
    const expiresText = this.buildExpiresText(verification.expiresAt);
    const membershipName = this.resolveMembershipName(verification);
    return `${membershipName}已开通，${productText}${expiresText}会员权益已写入云端。`;
  }

  private buildUserVerificationMessage(
    result: HuaweiIapOperationResult,
    verification: HuaweiIapVerificationResponseBody
  ): ResourceStr {
    const restored = result.action === 'restore_purchase';
    const until = this.formatExpiresDate(verification.expiresAt);
    if (this.isLongTermPurchase(verification)) {
      return restored
        ? $r('app.string.settings_pro_restored_lifetime')
        : $r('app.string.settings_pro_opened_lifetime_done');
    }
    if (until.length > 0) {
      return restored
        ? $r('app.string.settings_pro_restored_until', until)
        : $r('app.string.settings_pro_opened_until', until);
    }
    return restored
      ? $r('app.string.settings_pro_restored')
      : $r('app.string.settings_pro_opened');
  }

  private buildExpiresText(expiresAt?: number): string {
    if (expiresAt === undefined || expiresAt <= 0) {
      return '';
    }
    return `有效期至 ${this.formatDate(expiresAt)}，`;
  }

  private buildSuccessTitle(verification: HuaweiIapVerificationResponseBody): string {
    return this.isLongTermPurchase(verification) ? '长期会员已开通' : '订阅已开通';
  }

  private resolveMembershipName(verification: HuaweiIapVerificationResponseBody): string {
    return this.isLongTermPurchase(verification) ? 'Aira 长期会员' : 'Aira Pro ';
  }

  private isLongTermPurchase(verification: HuaweiIapVerificationResponseBody): boolean {
    return isAiraProLifetimeProductId(verification.productId ?? '');
  }

  private formatExpiresDate(expiresAt?: number): string {
    if (expiresAt === undefined || expiresAt <= 0) {
      return '';
    }
    return this.formatDate(expiresAt);
  }

  private formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    return `${date.getFullYear()}.${this.pad2(date.getMonth() + 1)}.${this.pad2(date.getDate())}`;
  }

  private pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private async finishVerifiedPurchaseData(
    context: common.UIAbilityContext,
    result: HuaweiIapOperationResult,
    purchaseData: string,
    verification: HuaweiIapVerificationResponseBody
  ): Promise<ResourceStr> {
    try {
      await this.iapService.finishPurchase(context, purchaseData, verification.productType);
      return '';
    } catch (_error) {
      const restored = result.action === 'restore_purchase';
      if (this.isLongTermPurchase(verification)) {
        return restored
          ? $r('app.string.settings_pro_finish_failed_lifetime_restore')
          : $r('app.string.settings_pro_finish_failed_lifetime_open');
      }
      return restored
        ? $r('app.string.settings_pro_finish_failed_restore')
        : $r('app.string.settings_pro_finish_failed_open');
    }
  }

  private buildAlreadyOwnsExpiredRestoreResult(
    purchaseResult: HuaweiIapOperationResult,
    restoreResult: HuaweiIapOperationResult
  ): HuaweiIapOperationResult {
    const diagnosticText = this.showDiagnosticMessages
      ? ` ${purchaseResult.message} ${restoreResult.message}`
      : '';
    return {
      ok: false,
      title: $r('app.string.settings_pro_purchase_unavailable'),
      message: this.showDiagnosticMessages
        ? `华为当前没有拉起新的支付页面，只返回了已过期的旧订阅记录。请先确认华为订阅管理里没有未清理的沙盒订阅，或清除沙盒购买记录后稍等几分钟再购买。${diagnosticText}`
        : $r('app.string.settings_pro_purchase_blocked'),
      action: purchaseResult.action,
      purchaseData: restoreResult.purchaseData,
      purchaseDataList: restoreResult.purchaseDataList,
      purchaseCount: restoreResult.purchaseCount,
      verificationCode: restoreResult.verificationCode,
      errorCode: purchaseResult.errorCode
    };
  }

  private buildLoginRequiredResult(
    action: 'purchase_pro_monthly' | 'purchase_pro_one_time' | 'restore_purchase'
  ): HuaweiIapOperationResult {
    return {
      ok: false,
      title: $r('app.string.settings_pro_sign_in_title'),
      message: $r('app.string.settings_pro_login_required'),
      action: action,
      verificationCode: 'login_required'
    };
  }

  private buildUnsupportedPlanResult(
    period: string,
    action: 'purchase_pro_monthly' | 'restore_purchase'
  ): HuaweiIapOperationResult {
    return {
      ok: false,
      title: $r('app.string.settings_pro_plan_unavailable'),
      message: $r('app.string.settings_pro_plan_unavailable'),
      action: action,
      verificationCode: 'unsupported_plan'
    };
  }
}
