import {
  AiraSyncSettings,
  resolveAiraHuaweiAccountIdentity
} from '../../common/models/AiraSyncModels';
import {
  AiraAccountRecognitionBadgeKind,
  AiraMembershipBadgeKind,
  AiraMembershipState
} from '../../common/models/MembershipModels';
import { MembershipPresentationService } from '../../services/membership/MembershipPresentationService';
import { AIRA_DISTRIBUTION_CAPABILITY_OWNER } from '../../common/config/AiraDistributionCapabilityOwner';

export type SettingsAccountMembershipBadgeKind = AiraMembershipBadgeKind;

export interface SettingsAccountCardState {
  title: ResourceStr;
  subtitle: ResourceStr;
  isLoggedIn: boolean;
  avatarUri: string;
  membershipBadge: SettingsAccountMembershipBadgeKind;
  recognitionBadge: AiraAccountRecognitionBadgeKind;
}

export class SettingsAccountCardViewModel {
  private membershipPresentationService: MembershipPresentationService = new MembershipPresentationService();
  buildState(settings: AiraSyncSettings, avatarUri: string = ''): SettingsAccountCardState {
    const signedIn = this.isHuaweiAccountSignedIn(settings);
    const community = AIRA_DISTRIBUTION_CAPABILITY_OWNER.isCommunity();
    return {
      title: signedIn ? this.resolveHuaweiAccountTitle(settings) : $r('app.string.settings_account_signed_out'),
      subtitle: community ? $r('app.string.settings_account_card_01') : this.resolveSubtitle(settings, signedIn),
      isLoggedIn: signedIn,
      avatarUri: this.resolveAvatarUri(settings, avatarUri),
      membershipBadge: community ? 'none' : (signedIn ? 'club' : 'none'),
      recognitionBadge: 'none'
    };
  }

  buildMembershipState(
    membership: AiraMembershipState,
    dataScope: string = '',
    privacyMode: string = '',
    avatarUri: string = '',
    settings?: AiraSyncSettings
  ): SettingsAccountCardState {
    const isPrivateContext = dataScope === 'session_ephemeral' || privacyMode === 'private';
    const signedIn = this.isHuaweiAccountSignedIn(settings);
    const recognitionBadge: AiraAccountRecognitionBadgeKind = signedIn
      ? this.membershipPresentationService.resolveRecognitionBadgeKind(membership)
      : 'none';
    const community = AIRA_DISTRIBUTION_CAPABILITY_OWNER.isCommunity();
    return {
      title: signedIn ? this.resolveHuaweiAccountTitle(settings) : $r('app.string.settings_account_signed_out'),
      subtitle: community
        ? $r('app.string.settings_account_card_01')
        : this.resolveMembershipSubtitle(membership, isPrivateContext, signedIn),
      isLoggedIn: signedIn,
      avatarUri: this.resolveAvatarUri(settings, avatarUri),
      membershipBadge: !community && signedIn && recognitionBadge === 'none'
        ? this.membershipPresentationService.resolveBadgeKind(membership)
        : 'none',
      recognitionBadge
    };
  }

  private resolveSubtitle(settings: AiraSyncSettings, signedIn: boolean): ResourceStr {
    if (!signedIn) {
      return $r('app.string.settings_account_signed_out_note');
    }
    if (settings.remoteKind === 'huawei_space') {
      return $r('app.string.settings_account_card_02');
    }
    if (settings.remoteKind === 'aira_cloud') {
      return $r('app.string.settings_account_card_03');
    }
    if (settings.remoteKind === 'webdav') {
      return $r('app.string.settings_account_card_04');
    }
    return $r('app.string.settings_account_card_05');
  }

  private resolveMembershipSubtitle(
    membership: AiraMembershipState,
    isPrivateContext: boolean,
    signedIn: boolean
  ): ResourceStr {
    if (isPrivateContext) {
      return $r('app.string.settings_account_private_blocked');
    }
    if (signedIn && membership.plan === 'club') {
      return $r('app.string.settings_account_card_05');
    }
    if (membership.plan === 'pro') {
      return this.membershipPresentationService.resolveAccountSubtitle(membership);
    }
    return '本地浏览功能已全部开启，登录后可使用账号与云服务';
  }

  private isHuaweiAccountSignedIn(settings?: AiraSyncSettings): boolean {
    return settings !== undefined &&
      resolveAiraHuaweiAccountIdentity(settings.huaweiCloud, settings.huaweiSpace).uid.length > 0;
  }

  private resolveHuaweiAccountTitle(settings?: AiraSyncSettings): string {
    if (settings === undefined) {
      return '华为账号';
    }
    const identity = resolveAiraHuaweiAccountIdentity(settings.huaweiCloud, settings.huaweiSpace);
    const displayName = identity.displayName;
    if (displayName.length > 0) {
      return displayName;
    }
    const uid = identity.uid;
    if (uid.length <= 0) {
      return '华为账号';
    }
    const suffix = uid.length > 6 ? uid.slice(uid.length - 6) : uid;
    return `华为账号 ${suffix}`;
  }

  private resolveAvatarUri(settings?: AiraSyncSettings, localAvatarUri: string = ''): string {
    const huaweiPhotoUrl = settings === undefined
      ? ''
      : resolveAiraHuaweiAccountIdentity(settings.huaweiCloud, settings.huaweiSpace).photoUrl;
    if (huaweiPhotoUrl.length > 0) {
      return huaweiPhotoUrl;
    }
    return localAvatarUri.trim();
  }
}
