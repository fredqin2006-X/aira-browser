import { AiraMembershipState } from '../../common/models/MembershipModels';
import {
  AIRA_PRO_ONE_TIME_PLAN,
  isAiraProLifetimeProductId,
  AIRA_PRO_SELLABLE_IAP_PLANS,
  HuaweiIapProductPlan,
  findAiraProIapPlanByProductId
} from '../../services/membership/HuaweiIapProductCatalog';
import { MembershipPresentationService } from '../../services/membership/MembershipPresentationService';
import {
  AiraProPlanPurchaseAction,
  AiraProPurchaseAvailability,
  AiraProPurchasePolicyService
} from '../../services/membership/AiraProPurchasePolicyService';
import { BrowserProfileBoundaryService } from '../browser/BrowserProfileBoundaryService';
import {
  BrowserPrivacyEffectIntent,
  BrowserPrivacyEffectPolicyService
} from '../../services/privacy/BrowserPrivacyEffectPolicyService';
import { AIRA_DISTRIBUTION_CAPABILITY_OWNER } from '../../common/config/AiraDistributionCapabilityOwner';
import { resolveAppResourceText } from '../resources/AppResourceText';
import {
  AIRA_PRO_BENEFITS,
  AIRA_PRO_REACHABLE_DEVICES,
  AiraProBenefitDefinition,
  AiraProReachableDeviceDefinition,
  AiraProReachableDeviceGlyph
} from './AiraProBenefitCatalog';
import { AiraRenderableIconId } from '../resources/GeneratedAiraIconCatalog';
import {
  AIRA_PRO_COMPLIMENTARY_CLAIM_DAYS,
  AiraProComplimentaryClaimAvailability,
  AiraProComplimentaryClaimDecision,
  resolveAiraProComplimentaryClaimDecision
} from './AiraProComplimentaryClaimPolicy';
import { resolveAiraProLifetimePricePresentation } from '../../services/membership/AiraProStorePricePolicy';

export type AiraProOverviewPlanAction = AiraProPlanPurchaseAction;

export interface AiraProOverviewBenefitState {
  id: string;
  title: ResourceStr;
  /**
   * The benefit's own glyph, so the page draws a colourful icon per row instead
   * of a generic check mark. The colour comes from the theme's settings icon
   * background set, keyed by the same id.
   */
  iconId: AiraRenderableIconId;
}

/** One endpoint Aira Pro reaches, rendered as a chip in the header rail. */
export interface AiraProOverviewReachableDeviceState {
  id: string;
  label: ResourceStr;
  glyph: AiraProReachableDeviceGlyph;
}

export interface AiraProOverviewViewState {
  title: ResourceStr;
  subtitle: ResourceStr;
  benefits: AiraProOverviewBenefitState[];
  reachableDevices: AiraProOverviewReachableDeviceState[];
  plans: AiraProOverviewPlanState[];
  /** A current Pro holder sees this instead of, or above, the storefront. */
  showMembershipStatus: boolean;
  membershipStatusTitle: ResourceStr;
  membershipStatusDetail: ResourceStr;
  /**
   * Only a live Huawei subscription has an auto-renewal page to open. The card that
   * carries this action is the one place a subscriber can stop the renewal, so it
   * must stay reachable for every state the subscription can be in.
   */
  showManageSubscription: boolean;
  /** Hidden once there is nothing left to buy, including permanent membership. */
  showPurchaseButton: boolean;
  /** A permanent member cannot use a code, so the entry is not shown. */
  showMembershipRedeem: boolean;
  complimentaryClaim: AiraProComplimentaryClaimState;
  proValue: ResourceStr;
  proActivatedActionText: ResourceStr;
  proLegalPromptText: ResourceStr;
  proLegalAgreementTitle: ResourceStr;
  proLegalRenewalTitle: ResourceStr;
  proActionsEnabled: boolean;
  proSubscribeEnabled: boolean;
  lifetimeUpgradePrompt: AiraProLifetimeUpgradePromptState;
}

export interface AiraProComplimentaryClaimState {
  entryVisible: boolean;
  entryTitle: ResourceStr;
  title: ResourceStr;
  /** The grant length, shown as the dialog's large numeral. */
  days: number;
  message: ResourceStr;
  statusText: ResourceStr;
  actionText: ResourceStr;
  actionEnabled: boolean;
  availability: AiraProComplimentaryClaimAvailability;
}

export interface AiraProOverviewPlanState {
  id: string;
  purchaseKind: 'subscription' | 'one_time';
  title: ResourceStr;
  priceText: string;
  /** Amount only, for the price card's large line: `¥7.89`. */
  amountText: string;
  /** Cadence only, for the price card's small suffix: `/ 年`. */
  periodText: ResourceStr;
  /** Period-end discount badge; empty when the plan has no discount. */
  discountBadgeText: ResourceStr;
  /** Struck-through list price for the card's top-right capsule; empty hides it. */
  originalPriceText: ResourceStr;
  description: ResourceStr;
  badgeText: string;
  actionText: ResourceStr;
  consentActionText: ResourceStr;
  footerText: ResourceStr;
  action: AiraProOverviewPlanAction;
}

interface AiraProMembershipPresentation {
  showMembershipStatus: boolean;
  membershipStatusTitle: ResourceStr;
  membershipStatusDetail: ResourceStr;
  showManageSubscription: boolean;
  showPurchaseButton: boolean;
}

export interface AiraProLifetimeUpgradePromptState {
  title: ResourceStr;
  message: ResourceStr;
  cancelLabel: ResourceStr;
  manageLabel: ResourceStr;
}

export class AiraProOverviewViewModel {
  private membershipPresentationService: MembershipPresentationService = new MembershipPresentationService();
  private purchasePolicyService: AiraProPurchasePolicyService = new AiraProPurchasePolicyService();
  private privacyEffectPolicy: BrowserPrivacyEffectPolicyService = new BrowserPrivacyEffectPolicyService();
  private profileBoundaryService: BrowserProfileBoundaryService = new BrowserProfileBoundaryService();

  buildState(
    membershipState: AiraMembershipState,
    dataScope: string,
    privacyMode: string,
    lifetimeStorePriceText: string = ''
  ): AiraProOverviewViewState {
    if (AIRA_DISTRIBUTION_CAPABILITY_OWNER.isCommunity()) {
      return this.buildCommunityState();
    }
    const purchaseAllowed = this.isEffectAllowed('membership_purchase', dataScope, privacyMode);
    const restoreAllowed = this.isEffectAllowed('membership_restore_purchase', dataScope, privacyMode);
    const subscriptionManagementAllowed = this.isEffectAllowed(
      'membership_subscription_management',
      dataScope,
      privacyMode
    );
    const plans: AiraProOverviewPlanState[] = this.buildVisiblePlans(
      membershipState,
      purchaseAllowed,
      lifetimeStorePriceText
    );
    const presentation = this.resolveMembershipPresentation(membershipState, plans, purchaseAllowed);
    const actionsEnabled = purchaseAllowed && restoreAllowed && subscriptionManagementAllowed;
    return {
      title: this.resolveHeroTitle(membershipState),
      subtitle: this.resolveHeroSubtitle(membershipState),
      benefits: this.buildBenefitStates(),
      reachableDevices: this.buildReachableDeviceStates(),
      plans: plans,
      showMembershipStatus: presentation.showMembershipStatus,
      membershipStatusTitle: presentation.membershipStatusTitle,
      membershipStatusDetail: presentation.membershipStatusDetail,
      showManageSubscription: presentation.showManageSubscription,
      showPurchaseButton: presentation.showPurchaseButton,
      showMembershipRedeem: !this.membershipPresentationService.isLongTermMember(membershipState),
      complimentaryClaim: this.buildComplimentaryClaimState(
        membershipState,
        plans.length > 0 && actionsEnabled
      ),
      proValue: this.resolveProValue(membershipState),
      proActivatedActionText: this.resolveActivatedActionText(membershipState),
      proLegalPromptText: $r('app.string.settings_pro_legal_prompt'),
      proLegalAgreementTitle: $r('app.string.settings_pro_legal_membership'),
      proLegalRenewalTitle: $r('app.string.settings_pro_legal_renewal'),
      proActionsEnabled: actionsEnabled,
      proSubscribeEnabled: plans.some((plan: AiraProOverviewPlanState) => plan.action !== 'unavailable'),
      lifetimeUpgradePrompt: this.buildLifetimeUpgradePrompt(membershipState)
    };
  }

  private buildCommunityState(): AiraProOverviewViewState {
    return {
      title: 'Aira',
      subtitle: $r('app.string.settings_pro_community_subtitle'),
      benefits: [
        {
          id: 'offline_page_save',
          title: $r('app.string.settings_pro_benefit_offline'),
          iconId: 'browser.toolbar.offline'
        },
        {
          id: 'userscript_install',
          title: $r('app.string.settings_pro_benefit_scripts'),
          iconId: 'membership.benefit.userScripts'
        },
        {
          id: 'manual_element_hide',
          title: $r('app.string.settings_pro_benefit_hide'),
          iconId: 'browser.toolbar.manualElementHide'
        },
        {
          id: 'local_theme_and_search',
          title: $r('app.string.settings_pro_benefit_theme'),
          iconId: 'membership.benefit.appearance'
        }
      ],
      plans: [],
      reachableDevices: this.buildReachableDeviceStates(),
      showMembershipStatus: false,
      membershipStatusTitle: '',
      membershipStatusDetail: '',
      showManageSubscription: false,
      showPurchaseButton: false,
      showMembershipRedeem: false,
      complimentaryClaim: this.buildHiddenComplimentaryClaim(),
      proValue: $r('app.string.settings_pro_community_value'),
      proActivatedActionText: $r('app.string.settings_pro_community_action'),
      proLegalPromptText: '',
      proLegalAgreementTitle: '',
      proLegalRenewalTitle: '',
      proActionsEnabled: false,
      proSubscribeEnabled: false,
      lifetimeUpgradePrompt: {
        title: '',
        message: '',
        cancelLabel: '',
        manageLabel: ''
      }
    };
  }

  private resolveHeroTitle(state: AiraMembershipState): ResourceStr {
    if (state.plan !== 'pro') {
      return 'Aira Pro';
    }
    if (this.membershipPresentationService.isLongTermMember(state) &&
      !this.membershipPresentationService.hasInsiderRecognition(state)) {
      return $r('app.string.settings_pro_lifetime_active_title');
    }
    return $r('app.string.settings_pro_active_title');
  }

  private resolveHeroSubtitle(state: AiraMembershipState): ResourceStr {
    if (state.plan !== 'pro') {
      return $r('app.string.settings_pro_subtitle_free');
    }
    if (this.membershipPresentationService.isLongTermMember(state)) {
      if (this.membershipPresentationService.hasInsiderRecognition(state)) {
        return $r('app.string.settings_pro_subtitle_insider');
      }
      return $r('app.string.settings_pro_subtitle_lifetime');
    }
    const until = state.planExpiresAt > 0 ? this.formatDate(state.planExpiresAt) : '';
    if (this.isCurrentSubscriptionMember(state)) {
      if (state.subscriptionStatus === 'cancelled') {
        return until.length > 0
          ? $r('app.string.settings_pro_subtitle_renewal_off_until', until)
          : $r('app.string.settings_pro_subtitle_renewal_off');
      }
      return this.resolveSubscriptionActiveSubtitle(state.subscriptionProductId, until);
    }
    // A timed Pro period that is not a store subscription is the claim or gift
    // kind, and neither of them holds an auto-renewal the user must stop first:
    // the permanent and subscription plans are purchasable right now, so the
    // subtitle must not send the user away to wait for the expiry date.
    return until.length > 0
      ? $r('app.string.settings_pro_subtitle_timed_until', until)
      : $r('app.string.settings_pro_subtitle_timed');
  }

  private resolveSubscriptionActiveSubtitle(productId: string, until: string): ResourceStr {
    const kind = this.resolveProductKind(productId);
    if (until.length > 0) {
      if (kind === 'yearly') {
        return $r('app.string.settings_pro_subtitle_yearly_until', until);
      }
      if (kind === 'monthly') {
        return $r('app.string.settings_pro_subtitle_monthly_until', until);
      }
      return $r('app.string.settings_pro_subtitle_subscription_until', until);
    }
    if (kind === 'yearly') {
      return $r('app.string.settings_pro_subtitle_yearly_active');
    }
    if (kind === 'monthly') {
      return $r('app.string.settings_pro_subtitle_monthly_active');
    }
    return $r('app.string.settings_pro_subtitle_subscription_active');
  }

  private buildVisiblePlans(
    state: AiraMembershipState,
    purchaseAllowed: boolean,
    lifetimeStorePriceText: string
  ): AiraProOverviewPlanState[] {
    if (this.membershipPresentationService.isLongTermMember(state)) {
      return [];
    }
    const lifetimePlan = this.buildOneTimePlanState(state, purchaseAllowed, lifetimeStorePriceText);
    if (this.isCurrentSubscriptionMember(state)) {
      return [lifetimePlan];
    }
    const subscriptionPlans: AiraProOverviewPlanState[] = AIRA_PRO_SELLABLE_IAP_PLANS.map(
      (plan: HuaweiIapProductPlan) => this.buildSubscriptionPlanState(plan, state, purchaseAllowed)
    );
    return [lifetimePlan].concat(subscriptionPlans);
  }

  private resolveMembershipPresentation(
    state: AiraMembershipState,
    plans: AiraProOverviewPlanState[],
    purchaseAllowed: boolean
  ): AiraProMembershipPresentation {
    const permanent = this.membershipPresentationService.isLongTermMember(state);
    const subscription = this.isCurrentSubscriptionMember(state);
    const timed = state.plan === 'pro' && !permanent && !subscription;
    const hasPurchasablePlan = plans.some((plan: AiraProOverviewPlanState) => plan.action === 'purchase');
    return {
      showMembershipStatus: permanent || subscription || timed,
      membershipStatusTitle: this.resolveMembershipStatusTitle(state, permanent, subscription),
      membershipStatusDetail: this.resolveMembershipStatusDetail(state, permanent, subscription, timed),
      showManageSubscription: subscription,
      showPurchaseButton: hasPurchasablePlan || (!purchaseAllowed && plans.length > 0)
    };
  }

  private resolveMembershipStatusTitle(
    state: AiraMembershipState,
    permanent: boolean,
    subscription: boolean
  ): ResourceStr {
    if (permanent && this.membershipPresentationService.hasInsiderRecognition(state)) {
      return $r('app.string.settings_pro_status_insider');
    }
    if (permanent) {
      return $r('app.string.settings_pro_status_lifetime');
    }
    if (subscription) {
      return this.resolveSubscriptionStatusTitle(state.subscriptionProductId);
    }
    return $r('app.string.settings_pro_status_active');
  }

  private resolveSubscriptionStatusTitle(productId: string): ResourceStr {
    const kind = this.resolveProductKind(productId);
    if (kind === 'yearly') {
      return $r('app.string.settings_pro_status_yearly');
    }
    if (kind === 'monthly') {
      return $r('app.string.settings_pro_status_monthly');
    }
    return $r('app.string.settings_pro_status_subscription');
  }

  private resolveMembershipStatusDetail(
    state: AiraMembershipState,
    permanent: boolean,
    subscription: boolean,
    timed: boolean
  ): ResourceStr {
    if (permanent) {
      return $r('app.string.settings_pro_status_detail_lifetime');
    }
    const until = state.planExpiresAt > 0 ? this.formatDate(state.planExpiresAt) : '';
    if (subscription) {
      if (state.subscriptionStatus === 'cancelled') {
        return until.length > 0
          ? $r('app.string.settings_pro_status_detail_renewal_off_until', until)
          : $r('app.string.settings_pro_status_detail_renewal_off');
      }
      return until.length > 0
        ? $r('app.string.settings_pro_status_detail_renewing_until', until)
        : $r('app.string.settings_pro_status_detail_renewing');
    }
    if (timed && until.length > 0) {
      return $r('app.string.settings_pro_status_detail_until', until);
    }
    return '';
  }

  private isCurrentSubscriptionMember(state: AiraMembershipState): boolean {
    if (state.plan !== 'pro' || this.membershipPresentationService.isLongTermMember(state)) {
      return false;
    }
    return state.subscriptionStatus === 'active' ||
      state.subscriptionStatus === 'grace_period' ||
      state.subscriptionStatus === 'cancelled' ||
      state.subscriptionStatus === 'unknown';
  }

  private buildOneTimePlanState(
    state: AiraMembershipState,
    purchaseAllowed: boolean,
    lifetimeStorePriceText: string
  ): AiraProOverviewPlanState {
    const action = this.resolveOneTimePlanAction(state, this.resolvePurchaseAvailability(purchaseAllowed));
    const price = resolveAiraProLifetimePricePresentation(
      lifetimeStorePriceText,
      AIRA_PRO_ONE_TIME_PLAN.amountText,
      AIRA_PRO_ONE_TIME_PLAN.periodText,
      AIRA_PRO_ONE_TIME_PLAN.displayPrice,
      AIRA_PRO_ONE_TIME_PLAN.originalPriceText,
      Date.now()
    );
    return {
      id: AIRA_PRO_ONE_TIME_PLAN.planId,
      purchaseKind: 'one_time',
      title: $r('app.string.settings_pro_status_lifetime'),
      priceText: resolveAppResourceText($r('app.string.membership_plan_lifetime_price', price.amountText)),
      amountText: price.amountText,
      periodText: $r('app.string.settings_pro_period_lifetime'),
      discountBadgeText: this.resolveDiscountBadge(price.discountBadgeText),
      originalPriceText: this.localizeListPrice(price.originalPriceText),
      description: price.descriptionText.length > 0
        ? this.localizePriceDescription(price.descriptionText)
        : this.buildOneTimePlanDescription(state),
      badgeText: '',
      actionText: action === 'manage_subscription'
        ? $r('app.string.settings_pro_manage_renewal')
        : $r('app.string.settings_pro_buy_now', price.amountText),
      consentActionText: action === 'manage_subscription'
        ? $r('app.string.settings_pro_manage_renewal')
        : $r('app.string.settings_pro_buy_consent'),
      footerText: this.buildOneTimePlanFooter(state),
      action: action
    };
  }

  private buildBenefitStates(): AiraProOverviewBenefitState[] {
    return AIRA_PRO_BENEFITS.map((benefit: AiraProBenefitDefinition): AiraProOverviewBenefitState => {
      return {
        id: benefit.id,
        title: benefit.title,
        iconId: benefit.iconId
      };
    });
  }

  private buildReachableDeviceStates(): AiraProOverviewReachableDeviceState[] {
    return AIRA_PRO_REACHABLE_DEVICES.map(
      (device: AiraProReachableDeviceDefinition): AiraProOverviewReachableDeviceState => {
        return {
          id: device.id,
          label: device.label,
          glyph: device.glyph
        };
      });
  }

  private buildSubscriptionPlanState(
    plan: HuaweiIapProductPlan,
    state: AiraMembershipState,
    purchaseAllowed: boolean
  ): AiraProOverviewPlanState {
    const action = this.purchasePolicyService.resolveSubscriptionPlanAction(
      state,
      this.resolvePurchaseAvailability(purchaseAllowed)
    );
    return {
      id: plan.period,
      purchaseKind: 'subscription',
      title: plan.period === 'yearly'
        ? $r('app.string.settings_pro_status_yearly')
        : $r('app.string.settings_pro_status_monthly'),
      priceText: resolveAppResourceText(plan.period === 'yearly'
        ? $r('app.string.membership_plan_yearly_price', plan.amountText)
        : $r('app.string.membership_plan_monthly_price', plan.amountText)),
      amountText: plan.amountText,
      periodText: plan.period === 'yearly'
        ? $r('app.string.settings_pro_period_year')
        : $r('app.string.settings_pro_period_month'),
      discountBadgeText: plan.discountBadgeText,
      originalPriceText: '',
      description: plan.period === 'yearly'
        ? $r('app.string.settings_pro_plan_yearly_desc')
        : $r('app.string.settings_pro_plan_monthly_desc'),
      badgeText: plan.badgeText === '推荐'
        ? resolveAppResourceText($r('app.string.membership_plan_recommended'))
        : plan.badgeText,
      actionText: $r('app.string.settings_pro_subscribe'),
      consentActionText: $r('app.string.settings_pro_subscribe_consent'),
      footerText: $r('app.string.settings_pro_subscribe_footer'),
      action: action
    };
  }

  private resolveOneTimePlanAction(
    state: AiraMembershipState,
    availability: AiraProPurchaseAvailability
  ): AiraProOverviewPlanAction {
    return this.purchasePolicyService.resolveOneTimePlanAction(state, availability);
  }

  private resolvePurchaseAvailability(purchaseAllowed: boolean): AiraProPurchaseAvailability {
    return purchaseAllowed ? 'available' : 'privacy_restricted';
  }

  private isEffectAllowed(intent: BrowserPrivacyEffectIntent, dataScope: string, privacyMode: string): boolean {
    if ((dataScope !== 'profile_persistent' && dataScope !== 'session_ephemeral') ||
      (privacyMode !== 'regular' && privacyMode !== 'private')) {
      return false;
    }
    const requestingBoundary = this.profileBoundaryService.buildBoundary({
      dataScope: dataScope,
      privacyMode: privacyMode
    });
    return this.privacyEffectPolicy.decide({
      intent: intent,
      requestingBoundary: requestingBoundary,
      targetScope: 'remote_account_sync_state',
      targetIsClear: true
    }).outcome === 'allow';
  }

  private buildOneTimePlanDescription(state: AiraMembershipState): ResourceStr {
    const until = state.planExpiresAt > 0 ? this.formatDate(state.planExpiresAt) : '';
    if (this.purchasePolicyService.resolveOneTimePlanAction(state) === 'manage_subscription') {
      return until.length > 0
        ? $r('app.string.settings_pro_lifetime_desc_manage_until', until)
        : $r('app.string.settings_pro_lifetime_desc_manage');
    }
    if (state.plan === 'pro' && state.subscriptionStatus === 'cancelled') {
      return until.length > 0
        ? $r('app.string.settings_pro_lifetime_desc_cancelled_until', until)
        : $r('app.string.settings_pro_lifetime_desc_cancelled');
    }
    return $r('app.string.settings_pro_plan_lifetime_desc');
  }

  private buildOneTimePlanFooter(state: AiraMembershipState): ResourceStr {
    if (this.purchasePolicyService.resolveOneTimePlanAction(state) === 'manage_subscription') {
      return $r('app.string.settings_pro_lifetime_footer_manage');
    }
    if (state.plan === 'pro' && state.subscriptionStatus === 'cancelled') {
      return $r('app.string.settings_pro_lifetime_footer_cancelled');
    }
    return $r('app.string.settings_pro_lifetime_footer');
  }

  private resolveDiscountBadge(text: string): ResourceStr {
    if (text === '7折') {
      return $r('app.string.settings_pro_discount_national');
    }
    return text;
  }

  private localizeListPrice(text: string): ResourceStr {
    if (text.length === 0) {
      return '';
    }
    const amount = text.indexOf('原价') === 0 ? text.substring(2) : text;
    return $r('app.string.settings_pro_list_price', amount);
  }

  private localizePriceDescription(text: string): ResourceStr {
    if (text === '国庆特惠，10月7日前') {
      return $r('app.string.settings_pro_national_desc');
    }
    return $r('app.string.settings_pro_plan_lifetime_desc');
  }

  private buildComplimentaryClaimState(
    membershipState: AiraMembershipState,
    entryVisible: boolean
  ): AiraProComplimentaryClaimState {
    if (!entryVisible) {
      return this.buildHiddenComplimentaryClaim();
    }
    const decision: AiraProComplimentaryClaimDecision =
      resolveAiraProComplimentaryClaimDecision(membershipState, Date.now());
    return {
      entryVisible: true,
      entryTitle: $r('app.string.settings_pro_claim_entry'),
      title: $r('app.string.settings_pro_claim_dialog_title'),
      days: AIRA_PRO_COMPLIMENTARY_CLAIM_DAYS,
      message: '',
      statusText: decision.statusText,
      actionText: decision.actionText,
      actionEnabled: decision.actionEnabled,
      availability: decision.availability
    };
  }

  private buildHiddenComplimentaryClaim(): AiraProComplimentaryClaimState {
    return {
      entryVisible: false,
      entryTitle: '',
      title: '',
      days: AIRA_PRO_COMPLIMENTARY_CLAIM_DAYS,
      message: '',
      statusText: '',
      actionText: '',
      actionEnabled: false,
      availability: 'available'
    };
  }

  private buildLifetimeUpgradePrompt(state: AiraMembershipState): AiraProLifetimeUpgradePromptState {
    const until = state.planExpiresAt > 0 ? this.formatDate(state.planExpiresAt) : '';
    return {
      title: $r('app.string.settings_pro_upgrade_title'),
      message: until.length > 0
        ? $r('app.string.settings_pro_upgrade_message_until', until)
        : $r('app.string.settings_pro_upgrade_message'),
      cancelLabel: $r('app.string.settings_pro_upgrade_cancel'),
      manageLabel: $r('app.string.settings_pro_manage_renewal')
    };
  }

  private resolveProValue(state: AiraMembershipState): ResourceStr {
    if (state.plan !== 'pro') {
      return $r('app.string.settings_pro_value_view');
    }
    if (this.membershipPresentationService.isLongTermMember(state)) {
      return $r('app.string.settings_pro_value_lifetime');
    }
    const until = state.planExpiresAt > 0 ? this.formatDate(state.planExpiresAt) : '';
    const kind = this.resolveProductKind(state.subscriptionProductId);
    if (until.length > 0) {
      if (kind === 'yearly') {
        return $r('app.string.settings_pro_value_yearly_until', until);
      }
      if (kind === 'monthly') {
        return $r('app.string.settings_pro_value_monthly_until', until);
      }
      return $r('app.string.settings_pro_value_until', until);
    }
    if (kind === 'yearly') {
      return $r('app.string.settings_pro_value_yearly_lifetime');
    }
    if (kind === 'monthly') {
      return $r('app.string.settings_pro_value_monthly_lifetime');
    }
    return $r('app.string.settings_pro_value_long_term');
  }

  private resolveActivatedActionText(state: AiraMembershipState): ResourceStr {
    if (state.plan === 'pro' && this.membershipPresentationService.isLongTermMember(state)) {
      return $r('app.string.settings_pro_activated_lifetime');
    }
    return $r('app.string.settings_pro_activated');
  }

  private resolveProductKind(productId: string): 'lifetime' | 'yearly' | 'monthly' | 'unknown' {
    if (isAiraProLifetimeProductId(productId)) {
      return 'lifetime';
    }
    const period = findAiraProIapPlanByProductId(productId)?.period;
    if (period === 'yearly' || period === 'monthly') {
      return period;
    }
    return 'unknown';
  }

  private formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = this.padTwoDigits(date.getMonth() + 1);
    const day = this.padTwoDigits(date.getDate());
    return `${year}.${month}.${day}`;
  }

  private padTwoDigits(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
