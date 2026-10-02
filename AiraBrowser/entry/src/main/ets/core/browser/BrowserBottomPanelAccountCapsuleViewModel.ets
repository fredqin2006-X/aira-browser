import { AiraMembershipBadgeKind, AiraMembershipState } from '../../common/models/MembershipModels';
import { AiraSyncSettings, resolveAiraHuaweiAccountIdentity } from '../../common/models/AiraSyncModels';
import { AIRA_DISTRIBUTION_CAPABILITY_OWNER } from '../../common/config/AiraDistributionCapabilityOwner';
import { MembershipPresentationService } from '../../services/membership/MembershipPresentationService';
import { resolveAppResourceText } from '../resources/AppResourceText';
import {
  BrowserBottomPanelAccountCapsulePresentation
} from './BrowserBottomPanelPresentationChannel';

/**
 * Builds the toolbar sheet's Home account capsule from account and membership state.
 *
 * The capsule is one line: avatar, name, optional membership badge, chevron. Identity comes from the
 * same Huawei identity the settings account card reads, so the two never disagree about who is signed
 * in. Community has no account system and no membership tier, so it always renders the neutral
 * placeholder avatar and the Community wording instead of a signed-out prompt.
 */
export class BrowserBottomPanelAccountCapsuleViewModel {
  private membershipPresentationService: MembershipPresentationService = new MembershipPresentationService();

  buildState(
    settings: AiraSyncSettings,
    membership: AiraMembershipState,
    localAvatarUri: string = ''
  ): BrowserBottomPanelAccountCapsulePresentation {
    if (AIRA_DISTRIBUTION_CAPABILITY_OWNER.isCommunity()) {
      return {
        visible: true,
        label: resolveAppResourceText($r('app.string.bottom_panel_account_community')),
        avatarUri: '',
        signedIn: false,
        membershipBadge: 'none'
      };
    }
    const identity = resolveAiraHuaweiAccountIdentity(settings.huaweiCloud, settings.huaweiSpace);
    const signedIn = identity.uid.trim().length > 0;
    if (!signedIn) {
      return {
        visible: true,
        label: resolveAppResourceText($r('app.string.bottom_panel_account_signed_out')),
        avatarUri: '',
        signedIn: false,
        membershipBadge: 'none'
      };
    }
    return {
      visible: true,
      label: this.resolveDisplayName(identity.displayName, identity.uid),
      avatarUri: this.resolveAvatarUri(identity.photoUrl, localAvatarUri),
      signedIn: true,
      membershipBadge: this.resolveMembershipBadge(membership)
    };
  }

  /**
   * Nickname when Huawei provides one, otherwise the trailing uid digits.
   *
   * Huawei stores a Chinese fallback name when it has no nickname, and showing `华为账号` in the
   * capsule would read as a label rather than a name, so that value falls back to the uid suffix too.
   */
  private resolveDisplayName(displayName: string, uid: string): string {
    const trimmedName = displayName.trim();
    const suffix = uid.length > 6 ? uid.slice(uid.length - 6) : uid;
    if (trimmedName.length > 0 && !this.isFallbackDisplayName(trimmedName, suffix)) {
      return trimmedName;
    }
    return suffix.length > 0 ? suffix :
      resolveAppResourceText($r('app.string.bottom_panel_account_signed_out'));
  }

  private isFallbackDisplayName(displayName: string, suffix: string): boolean {
    return displayName === '华为账号' || (suffix.length > 0 && displayName === `华为账号 ${suffix}`);
  }

  private resolveAvatarUri(huaweiPhotoUrl: string, localAvatarUri: string): string {
    const photoUrl = huaweiPhotoUrl.trim();
    return photoUrl.length > 0 ? photoUrl : localAvatarUri.trim();
  }

  /**
   * The tier badge comes from the shared membership presentation so the capsule and the settings
   * account card can never disagree about whether a member is Club, Pro, or a lifetime member.
   */
  private resolveMembershipBadge(membership: AiraMembershipState): AiraMembershipBadgeKind {
    return this.membershipPresentationService.resolveBadgeKind(membership);
  }
}
