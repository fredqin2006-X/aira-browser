import {
  AiraAccountRecognitionBadgeKind,
  AiraMembershipBadgeKind,
  AiraMembershipState
} from '../../common/models/MembershipModels';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';

export class MembershipPresentationService {
  hasInsiderRecognition(membership: AiraMembershipState): boolean {
    return membership.accountRecognition === 'aira_insider';
  }

  resolveRecognitionBadgeKind(membership: AiraMembershipState): AiraAccountRecognitionBadgeKind {
    return this.hasInsiderRecognition(membership) ? 'insider' : 'none';
  }

  resolveRecognitionSubtitle(membership: AiraMembershipState): string {
    return this.hasInsiderRecognition(membership)
      ? resolveAppResourceText($r('app.string.settings_account_insider_subtitle'))
      : '';
  }

  resolveRecognitionInfoText(membership: AiraMembershipState): string {
    if (!this.hasInsiderRecognition(membership)) {
      return '';
    }
    return resolveAppResourceText($r('app.string.settings_account_insider_info'));
  }

  isLongTermMember(membership: AiraMembershipState): boolean {
    return membership.plan === 'pro' &&
      membership.planExpiresAt === 0;
  }

  resolveVersionLabel(membership: AiraMembershipState): string {
    if (this.isLongTermMember(membership)) {
      return resolveAppResourceText($r('app.string.settings_account_long_term_member'));
    }
    if (membership.plan === 'pro') {
      return 'Aira Pro';
    }
    return 'Aira Club';
  }

  resolveBadgeKind(membership: AiraMembershipState): AiraMembershipBadgeKind {
    if (this.isLongTermMember(membership)) {
      return 'long_term';
    }
    if (membership.plan === 'pro') {
      return 'pro';
    }
    if (membership.plan === 'club') {
      return 'club';
    }
    return 'none';
  }

  resolveAccountSubtitle(membership: AiraMembershipState): string {
    if (this.isLongTermMember(membership)) {
      return resolveAppResourceText($r('app.string.settings_pro_value_lifetime'));
    }
    if (membership.plan === 'pro') {
      return resolveAppResourceText($r('app.string.membership_pro_active'));
    }
    return resolveAppResourceText($r('app.string.settings_account_card_05'));
  }
}
