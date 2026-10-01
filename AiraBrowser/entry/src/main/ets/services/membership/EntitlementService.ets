import { AiraFeatureKey } from '../../common/constants/MembershipFeatureKeys';
import {
  AiraFeatureQuota,
  AiraLapsedProView,
  AiraMembershipState,
  AiraPlan,
  EntitlementDenyReason,
  EntitlementDecision,
  EntitlementPrimaryAction,
  buildEmptyLapsedProView
} from '../../common/models/MembershipModels';
import {
  FeaturePolicy,
  MembershipPlanPolicyService
} from './MembershipPlanPolicyService';
import { MembershipQuotaService } from './MembershipQuotaService';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';

export interface EntitlementContext {
  dataScope: string;
  privacyMode: string;
  loggedIn?: boolean;
  currentUsage?: number;
}

export class EntitlementService {
  private policyService: MembershipPlanPolicyService;
  private quotaService: MembershipQuotaService;

  constructor(
    policyService: MembershipPlanPolicyService = new MembershipPlanPolicyService(),
    quotaService: MembershipQuotaService = new MembershipQuotaService()
  ) {
    this.policyService = policyService;
    this.quotaService = quotaService;
  }

  canUse(
    featureKey: AiraFeatureKey,
    state: AiraMembershipState,
    quotas: AiraFeatureQuota[],
    context: EntitlementContext,
    lapsedPro: AiraLapsedProView = buildEmptyLapsedProView()
  ): EntitlementDecision {
    const policy = this.policyService.getPolicy(featureKey);
    if (policy === undefined) {
      return {
        featureKey: featureKey,
        allowed: true,
        reason: 'allowed',
        title: '',
        message: '',
        primaryAction: 'none'
      };
    }

    const entitlementPlan = this.policyService.resolveEntitlementPlan(state.plan);

    if (policy.requiresPro && entitlementPlan !== 'pro') {
      // An account whose Pro period already ended gets told that it lapsed, not
      // that the feature needs Pro: the same renewal offer, framed as a
      // restoration of something they had rather than a first-time upsell.
      if (lapsedPro.expiredAt > 0) {
        return this.buildDeniedDecision(
          featureKey,
          policy,
          'pro_expired',
          resolveAppResourceText($r('app.string.membership_gate_expired_title')),
          resolveAppResourceText($r('app.string.membership_gate_paused', this.featureTitle(policy))),
          'open_pro'
        );
      }
      return this.buildDeniedDecision(
        featureKey,
        policy,
        'pro_required',
        resolveAppResourceText($r('app.string.membership_gate_upgrade_continue')),
        resolveAppResourceText($r('app.string.membership_gate_pro_feature', this.featureTitle(policy))),
        'open_pro'
      );
    }

    if (policy.requiresClub && !this.policyService.hasClubEntitlement(state.plan)) {
      return this.buildDeniedDecision(
        featureKey,
        policy,
        'club_required',
        resolveAppResourceText($r('app.string.membership_gate_unavailable_title')),
        resolveAppResourceText($r('app.string.membership_gate_unavailable_now', this.featureTitle(policy))),
        'none'
      );
    }

    if (policy.requiresLogin && !context.loggedIn) {
      return this.buildDeniedDecision(
        featureKey,
        policy,
        'login_required',
        resolveAppResourceText($r('app.string.membership_gate_login_title')),
        resolveAppResourceText($r('app.string.membership_gate_login_required', this.featureTitle(policy))),
        'login'
      );
    }

    const limit = this.policyService.getLimit(policy, entitlementPlan);
    const currentQuota = this.quotaService.findQuota(quotas, featureKey);
    const currentUsage = this.resolveCurrentUsage(context, currentQuota.used);
    const quota: AiraFeatureQuota = {
      featureKey: featureKey,
      used: currentUsage,
      limit: limit,
      resetAt: currentQuota.resetAt
    };
    if (limit < 0) {
      return {
        featureKey: featureKey,
        allowed: true,
        reason: 'allowed',
        title: '',
        message: '',
        primaryAction: 'none',
        quota: quota
      };
    }
    if (limit <= 0) {
      return this.buildDeniedDecision(
        featureKey,
        policy,
        'pro_required',
        resolveAppResourceText($r('app.string.membership_gate_upgrade_continue')),
        resolveAppResourceText($r('app.string.membership_gate_needs_pro', this.featureTitle(policy))),
        'open_pro',
        quota
      );
    }

    if (currentUsage >= limit) {
      return this.buildDeniedDecision(
        featureKey,
        policy,
        'quota_exceeded',
        resolveAppResourceText($r('app.string.membership_gate_upgrade_continue')),
        resolveAppResourceText($r('app.string.membership_gate_quota_limited',
          this.resolvePlanLabel(entitlementPlan), this.featureTitle(policy))),
        'open_pro',
        quota
      );
    }

    return {
      featureKey: featureKey,
      allowed: true,
      reason: 'allowed',
      title: '',
      message: '',
      primaryAction: 'none',
      quota: quota
    };
  }

  private buildDeniedDecision(
    featureKey: AiraFeatureKey,
    policy: FeaturePolicy,
    reason: EntitlementDenyReason,
    title: string,
    message: string,
    primaryAction: EntitlementPrimaryAction,
    quota?: AiraFeatureQuota
  ): EntitlementDecision {
    return {
      featureKey: featureKey,
      allowed: false,
      reason: reason,
      title: title,
      message: message.length > 0 ? message :
        resolveAppResourceText($r('app.string.membership_gate_unavailable_feature', this.featureTitle(policy))),
      primaryAction: primaryAction,
      quota: quota
    };
  }

  private resolveCurrentUsage(context: EntitlementContext, fallback: number): number {
    if (typeof context.currentUsage !== 'number' || !Number.isFinite(context.currentUsage)) {
      return fallback;
    }
    return Math.max(0, Math.floor(context.currentUsage));
  }

  private resolvePlanLabel(plan: AiraPlan): string {
    return this.policyService.resolveEntitlementPlanLabel(plan);
  }

  private featureTitle(policy: FeaturePolicy): string {
    const featureKey = policy.featureKey;
    if (featureKey === 'offline_page_save') {
      return resolveAppResourceText($r('app.string.membership_feature_offline_pages'));
    }
    if (featureKey === 'userscript_install') {
      return resolveAppResourceText($r('app.string.membership_feature_user_scripts'));
    }
    if (featureKey === 'manual_element_hide') {
      return resolveAppResourceText($r('app.string.membership_feature_hide_rules'));
    }
    if (featureKey === 'cloud_translation') {
      return resolveAppResourceText($r('app.string.membership_feature_translation'));
    }
    if (featureKey === 'cloud_sync') {
      return resolveAppResourceText($r('app.string.membership_feature_bookmark_sync'));
    }
    if (featureKey === 'webdav_sync') {
      return resolveAppResourceText($r('app.string.membership_feature_webdav'));
    }
    if (featureKey === 'bookmark_auto_sync') {
      return resolveAppResourceText($r('app.string.membership_feature_bookmark_auto_sync'));
    }
    if (featureKey === 'phone_page_push') {
      return resolveAppResourceText($r('app.string.membership_feature_page_push'));
    }
    if (featureKey === 'cross_device_tabs') {
      return resolveAppResourceText($r('app.string.membership_feature_device_tabs'));
    }
    if (featureKey === 'labs_feature') {
      return resolveAppResourceText($r('app.string.membership_feature_labs'));
    }
    return policy.title;
  }
}
