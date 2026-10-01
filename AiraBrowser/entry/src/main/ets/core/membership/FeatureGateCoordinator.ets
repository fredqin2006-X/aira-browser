import { AiraFeatureKey } from '../../common/constants/MembershipFeatureKeys';
import { resolveAppResourceText } from '../resources/AppResourceText';
import {
  EntitlementDecision,
  EntitlementPrimaryAction
} from '../../common/models/MembershipModels';
import { MembershipFeature } from '../../features/membership/MembershipFeature';
import { EntitlementContext } from '../../services/membership/EntitlementService';
import {
  AIRA_PRO_ONE_TIME_PLAN,
  AIRA_PRO_SELLABLE_IAP_PLANS,
  HuaweiIapProductPlan
} from '../../services/membership/HuaweiIapProductCatalog';
import { BrowserShellRouteCoordinator } from '../browser/BrowserShellRouteCoordinator';
import { BrowserTransientSurfaceCoordinator } from '../browser/BrowserTransientSurfaceCoordinator';
import { AIRA_DISTRIBUTION_CAPABILITY_OWNER } from '../../common/config/AiraDistributionCapabilityOwner';
import { AiraRenderableIconId } from '../resources/GeneratedAiraIconCatalog';
import { AIRA_PRO_BENEFITS, AiraProBenefitDefinition } from './AiraProBenefitCatalog';
import {
  readCachedAiraProLifetimeStorePrice,
  rememberAiraProLifetimeStorePrice,
  resolveAiraProLifetimePricePresentation
} from '../../services/membership/AiraProStorePricePolicy';

export type FeatureGateAction = EntitlementPrimaryAction | 'dismiss' | 'purchase_plan';

/**
 * One purchasable option inside the renewal sheet. The catalog is the fallback.
 * A live store price replaces the lifetime amount, so a console price change
 * shows up here without another release. The id is the plan the purchase flow expects.
 */
export interface FeatureGateRenewalBenefitState {
  id: string;
  title: ResourceStr;
  iconId: AiraRenderableIconId;
}

export interface FeatureGateRenewalPlanState {
  id: string;
  title: string;
  amountText: string;
  periodText: string;
  discountBadgeText: string;
  originalPriceText: string;
  badgeText: string;
  autoRenews: boolean;
}

/**
 * The renewal payload. Present only for a Pro gate, where the sheet can actually
 * complete a purchase; authentication and entitlement gates keep the plain
 * layout because offering a plan there would not be actionable.
 */
export interface FeatureGateRenewalState {
  benefits: FeatureGateRenewalBenefitState[];
  plans: FeatureGateRenewalPlanState[];
  selectedPlanId: string;
  expiredAt: number;
  agreementText: string;
  restoreLabel: string;
}

export interface FeatureGateSnapshot {
  visible: boolean;
  title: string;
  message: string;
  primaryActionTitle: string;
  secondaryActionTitle: string;
  primaryAction: FeatureGateAction;
  secondaryAction: FeatureGateAction;
  renewal?: FeatureGateRenewalState;
}

export function createHiddenFeatureGateSnapshot(): FeatureGateSnapshot {
  return {
    visible: false,
    title: '',
    message: '',
    primaryActionTitle: '',
    secondaryActionTitle: '',
    primaryAction: 'none',
    secondaryAction: 'none'
  };
}

export class FeatureGateCoordinator {
  private readonly membershipFeature: MembershipFeature;
  private readonly transientSurfaceCoordinator: BrowserTransientSurfaceCoordinator;
  private readonly routeCoordinator: BrowserShellRouteCoordinator;
  private readonly publishSnapshotToShell: (snapshot: FeatureGateSnapshot) => void;
  private readonly revealDelayMs: number;
  private readonly dismissDurationMs: number;
  private snapshot: FeatureGateSnapshot = createHiddenFeatureGateSnapshot();
  private presentationGeneration: number = 0;
  private lifetimeStorePriceText: string = '';
  private requestStorePriceRefresh: () => void = (): void => {
  };

  constructor(
    membershipFeature: MembershipFeature,
    transientSurfaceCoordinator: BrowserTransientSurfaceCoordinator,
    routeCoordinator: BrowserShellRouteCoordinator,
    publishSnapshotToShell: (snapshot: FeatureGateSnapshot) => void,
    revealDelayMs: number,
    dismissDurationMs: number
  ) {
    this.membershipFeature = membershipFeature;
    this.transientSurfaceCoordinator = transientSurfaceCoordinator;
    this.routeCoordinator = routeCoordinator;
    this.publishSnapshotToShell = publishSnapshotToShell;
    this.revealDelayMs = revealDelayMs;
    this.dismissDurationMs = dismissDurationMs;
  }

  getSnapshot(): FeatureGateSnapshot {
    return this.snapshot;
  }

  async ensureAccess(featureKey: AiraFeatureKey, context: EntitlementContext): Promise<boolean> {
    const decision = await this.evaluateAccess(featureKey, context);
    if (decision.allowed) {
      return true;
    }
    this.presentDecision(decision);
    return false;
  }

  async evaluateAccess(featureKey: AiraFeatureKey, context: EntitlementContext): Promise<EntitlementDecision> {
    return this.membershipFeature.canUse(featureKey, context);
  }

  presentDecision(decision: EntitlementDecision): void {
    if (decision.allowed) {
      this.resetPresentation();
      return;
    }
    const generation = this.presentationGeneration + 1;
    this.presentationGeneration = generation;
    this.publishSnapshot(this.buildSnapshot(decision));
    this.requestStorePriceRefresh();
    this.transientSurfaceCoordinator.present({
      id: 'feature_gate',
      revealDelayMs: this.revealDelayMs,
      dismissDurationMs: this.dismissDurationMs,
      shouldReveal: (): boolean => generation === this.presentationGeneration && this.snapshot.visible
    });
  }

  /** The shell binds this so a visible gate can replace the catalog price with the live store price. */
  bindStorePriceRefresh(refresh: () => void): void {
    this.requestStorePriceRefresh = refresh;
  }

  /**
   * Applies the price Huawei currently charges for long-term membership.
   * A matching price is a no-op. A different price rebuilds a visible sheet
   * in place, so the activity price appears and disappears with the store.
   */
  applyLifetimeStorePrice(priceText: string): void {
    const normalized = priceText.trim();
    if (normalized.length === 0) {
      return;
    }
    const current = this.resolveLifetimeStorePriceText();
    rememberAiraProLifetimeStorePrice(normalized);
    this.lifetimeStorePriceText = normalized;
    if (normalized === current) {
      return;
    }
    const renewal = this.snapshot.renewal;
    if (!this.snapshot.visible || renewal === undefined) {
      return;
    }
    const plans = this.buildRenewalPlans();
    if (plans.length === 0) {
      return;
    }
    const selectedStillPresent = plans.some((plan: FeatureGateRenewalPlanState): boolean => {
      return plan.id === renewal.selectedPlanId;
    });
    const selectedPlanId = selectedStillPresent ? renewal.selectedPlanId : plans[0].id;
    this.publishSnapshot({
      visible: this.snapshot.visible,
      title: this.snapshot.title,
      message: this.snapshot.message,
      primaryActionTitle: this.snapshot.primaryActionTitle,
      secondaryActionTitle: this.snapshot.secondaryActionTitle,
      primaryAction: this.snapshot.primaryAction,
      secondaryAction: this.snapshot.secondaryAction,
      renewal: {
        benefits: renewal.benefits,
        plans: plans,
        selectedPlanId: selectedPlanId,
        expiredAt: renewal.expiredAt,
        agreementText: this.resolveAgreementText(selectedPlanId, plans),
        restoreLabel: renewal.restoreLabel
      }
    });
  }

  handleAction(action: FeatureGateAction): void {
    this.transientSurfaceCoordinator.dismiss('feature_gate');
    // `purchase_plan` is completed by the shell, which owns the purchase flow,
    // so this coordinator only has to close the gate for it.
    if (action === 'open_pro' || action === 'restore_purchase' || action === 'login') {
      this.routeCoordinator.openAiraProPage();
    }
  }

  handleSurfaceDismissed(): void {
    this.presentationGeneration += 1;
    this.publishSnapshot(createHiddenFeatureGateSnapshot());
  }

  private resetPresentation(): void {
    this.presentationGeneration += 1;
    this.publishSnapshot(createHiddenFeatureGateSnapshot());
    this.transientSurfaceCoordinator.reset('feature_gate');
  }

  private publishSnapshot(snapshot: FeatureGateSnapshot): void {
    this.snapshot = snapshot;
    this.publishSnapshotToShell(snapshot);
  }

  private buildSnapshot(decision: EntitlementDecision): FeatureGateSnapshot {
    const renewal = this.buildRenewalState(decision);
    // With a renewal payload the sheet can complete the purchase itself, so the
    // primary action buys the selected plan instead of navigating away.
    const primaryAction: FeatureGateAction = renewal === undefined ? decision.primaryAction : 'purchase_plan';
    return {
      visible: true,
      title: decision.title,
      message: decision.message,
      primaryActionTitle: this.resolvePrimaryActionTitle(primaryAction),
      secondaryActionTitle: resolveAppResourceText($r('app.string.settings_sync_later')),
      primaryAction: primaryAction,
      secondaryAction: 'dismiss',
      renewal: renewal
    };
  }

  /**
   * Builds the renewal payload for a Pro gate. Returns undefined for every other
   * denial so the sheet keeps its plain layout; a login or entitlement gate has
   * no plan to sell.
   */
  private buildRenewalState(decision: EntitlementDecision): FeatureGateRenewalState | undefined {
    if (decision.reason !== 'pro_required' && decision.reason !== 'pro_expired') {
      return undefined;
    }
    // Community distributions have no in-app purchase, so there is nothing this
    // sheet could sell; it falls back to navigating to the membership page.
    if (!AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('huawei_iap')) {
      return undefined;
    }
    const plans: FeatureGateRenewalPlanState[] = this.buildRenewalPlans();
    if (plans.length === 0) {
      return undefined;
    }
    const selectedPlanId = AIRA_PRO_ONE_TIME_PLAN.planId;
    return {
      benefits: AIRA_PRO_BENEFITS.map((benefit: AiraProBenefitDefinition): FeatureGateRenewalBenefitState => {
        return {
          id: benefit.id,
          title: benefit.title,
          iconId: benefit.iconId
        };
      }),
      plans: plans,
      selectedPlanId: selectedPlanId,
      expiredAt: decision.reason === 'pro_expired'
        ? this.membershipFeature.getLapsedProState().expiredAt
        : 0,
      agreementText: this.resolveAgreementText(selectedPlanId, plans),
      restoreLabel: resolveAppResourceText($r('app.string.settings_pro_restore'))
    };
  }

  private resolveLifetimeStorePriceText(): string {
    if (this.lifetimeStorePriceText.length > 0) {
      return this.lifetimeStorePriceText;
    }
    return readCachedAiraProLifetimeStorePrice();
  }

  private buildRenewalPlans(): FeatureGateRenewalPlanState[] {
    const price = resolveAiraProLifetimePricePresentation(
      this.resolveLifetimeStorePriceText(),
      AIRA_PRO_ONE_TIME_PLAN.amountText,
      AIRA_PRO_ONE_TIME_PLAN.periodText,
      AIRA_PRO_ONE_TIME_PLAN.displayPrice,
      AIRA_PRO_ONE_TIME_PLAN.originalPriceText,
      Date.now()
    );
    const lifetime: FeatureGateRenewalPlanState = {
      id: AIRA_PRO_ONE_TIME_PLAN.planId,
      title: resolveAppResourceText($r('app.string.settings_pro_status_lifetime')),
      amountText: price.amountText,
      periodText: resolveAppResourceText($r('app.string.settings_pro_period_lifetime')).trim(),
      discountBadgeText: this.resolveDiscountBadge(price.discountBadgeText),
      originalPriceText: this.resolveListPrice(price.originalPriceText),
      badgeText: '',
      autoRenews: false
    };
    const subscriptions: FeatureGateRenewalPlanState[] = AIRA_PRO_SELLABLE_IAP_PLANS.map(
      (plan: HuaweiIapProductPlan): FeatureGateRenewalPlanState => {
        return {
          id: plan.period,
          title: plan.period === 'yearly'
            ? resolveAppResourceText($r('app.string.settings_pro_status_yearly'))
            : resolveAppResourceText($r('app.string.settings_pro_status_monthly')),
          amountText: plan.amountText,
          periodText: plan.period === 'yearly'
            ? resolveAppResourceText($r('app.string.settings_pro_period_year'))
            : resolveAppResourceText($r('app.string.settings_pro_period_month')),
          discountBadgeText: plan.discountBadgeText,
          originalPriceText: '',
          badgeText: plan.badgeText === '推荐'
            ? resolveAppResourceText($r('app.string.membership_plan_recommended'))
            : plan.badgeText,
          autoRenews: true
        };
      }
    );
    return [lifetime].concat(subscriptions);
  }

  private resolveDiscountBadge(text: string): string {
    if (text === '7折') {
      return resolveAppResourceText($r('app.string.settings_pro_discount_national'));
    }
    return text;
  }

  private resolveListPrice(text: string): string {
    if (text.length === 0) {
      return '';
    }
    const amount = text.indexOf('原价') === 0 ? text.substring('原价'.length) : text;
    return resolveAppResourceText($r('app.string.settings_pro_list_price', amount));
  }

  private resolveAgreementText(planId: string, plans: FeatureGateRenewalPlanState[]): string {
    const selected = plans.find((plan: FeatureGateRenewalPlanState): boolean => plan.id === planId);
    if (selected !== undefined && !selected.autoRenews) {
      return resolveAppResourceText($r('app.string.membership_gate_agree_membership'));
    }
    return resolveAppResourceText($r('app.string.membership_gate_agree_renewal'));
  }

  /**
   * Selects a different plan in the renewal sheet. Kept on the coordinator so
   * the selection survives the shell re-rendering the sheet.
   */
  selectRenewalPlan(planId: string): void {
    const renewal = this.snapshot.renewal;
    if (renewal === undefined || !this.snapshot.visible) {
      return;
    }
    if (renewal.selectedPlanId === planId) {
      return;
    }
    const nextSnapshot: FeatureGateSnapshot = {
      visible: this.snapshot.visible,
      title: this.snapshot.title,
      message: this.snapshot.message,
      primaryActionTitle: this.snapshot.primaryActionTitle,
      secondaryActionTitle: this.snapshot.secondaryActionTitle,
      primaryAction: this.snapshot.primaryAction,
      secondaryAction: this.snapshot.secondaryAction,
      renewal: {
        benefits: renewal.benefits,
        plans: renewal.plans,
        selectedPlanId: planId,
        expiredAt: renewal.expiredAt,
        agreementText: this.resolveAgreementText(planId, renewal.plans),
        restoreLabel: renewal.restoreLabel
      }
    };
    this.publishSnapshot(nextSnapshot);
  }

  /** The plan id the renewal sheet would purchase right now. */
  resolveSelectedRenewalPlanId(): string {
    return this.snapshot.renewal?.selectedPlanId ?? '';
  }

  /**
   * Presents the unprompted renewal reminder for an already-lapsed account.
   * Returns false when there is no lapsed period to announce, so the caller can
   * tell a real presentation from a no-op before it starts waiting for a reveal.
   *
   * This reuses the gate surface deliberately: how the user arrived at the
   * renewal sheet should not change what the sheet is.
   */
  presentRenewalReminder(): boolean {
    if (this.snapshot.visible) {
      return false;
    }
    const lapsed = this.membershipFeature.getLapsedProState();
    if (lapsed.expiredAt <= 0) {
      return false;
    }
    const decision: EntitlementDecision = {
      featureKey: 'cloud_sync',
      allowed: false,
      reason: 'pro_expired',
      title: resolveAppResourceText($r('app.string.membership_gate_expired_title')),
      message: resolveAppResourceText($r('app.string.membership_gate_expired_message',
        this.formatExpiryDate(lapsed.expiredAt))),
      primaryAction: 'open_pro'
    };
    const generation = this.presentationGeneration + 1;
    this.presentationGeneration = generation;
    this.publishSnapshot(this.buildSnapshot(decision));
    this.requestStorePriceRefresh();
    this.transientSurfaceCoordinator.present({
      id: 'feature_gate',
      revealDelayMs: this.revealDelayMs,
      dismissDurationMs: this.dismissDurationMs,
      shouldReveal: (): boolean => generation === this.presentationGeneration && this.snapshot.visible
    });
    return true;
  }

  private formatExpiryDate(expiresAt: number): string {
    const date = new Date(expiresAt);
    const month = date.getMonth() + 1;
    const day = date.getDate();
    return resolveAppResourceText($r('app.string.membership_gate_expiry_date',
      date.getFullYear(), month, day));
  }

  private resolvePrimaryActionTitle(action: FeatureGateAction): string {
    if (action === 'purchase_plan') {
      return this.membershipFeature.getLapsedProState().expiredAt > 0
        ? resolveAppResourceText($r('app.string.membership_gate_renew'))
        : resolveAppResourceText($r('app.string.membership_gate_subscribe'));
    }
    if (action === 'open_pro') {
      return resolveAppResourceText($r('app.string.membership_gate_upgrade'));
    }
    if (action === 'restore_purchase') {
      return resolveAppResourceText($r('app.string.settings_pro_restore'));
    }
    if (action === 'login') {
      return resolveAppResourceText($r('app.string.browser_ui_browser_shell_dialogs_002'));
    }
    return resolveAppResourceText($r('app.string.settings_pro_got_it'));
  }
}
