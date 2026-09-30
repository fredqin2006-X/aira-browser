import { common } from '@kit.AbilityKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { pasteboard } from '@kit.BasicServicesKit';
import { systemShare } from '@kit.ShareKit';
import { BrowserProfileBoundaryService } from '../../core/browser/BrowserProfileBoundaryService';
import { BrowserPrivacyEffectPolicyService } from '../privacy/BrowserPrivacyEffectPolicyService';

export interface OfflinePageLinkActionResult {
  ok: boolean;
  message: ResourceStr;
}

export class OfflinePageLinkActionService {
  private privacyEffectPolicy: BrowserPrivacyEffectPolicyService = new BrowserPrivacyEffectPolicyService();
  private profileBoundaryService: BrowserProfileBoundaryService = new BrowserProfileBoundaryService();

  async copyOriginalUrl(
    url: string,
    dataScope: string,
    privacyMode: string
  ): Promise<OfflinePageLinkActionResult> {
    if (!this.isManagementShareAllowed(dataScope, privacyMode)) {
      return {
        ok: false,
        message: $r('app.string.offline_copy_blocked')
      };
    }
    const normalizedUrl = url.trim();
    if (normalizedUrl.length === 0) {
      return {
        ok: false,
        message: $r('app.string.offline_original_link_unavailable')
      };
    }

    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, normalizedUrl);
      await pasteboard.getSystemPasteboard().setData(data);
      return {
        ok: true,
        message: $r('app.string.offline_copy_done')
      };
    } catch (_error) {
      return {
        ok: false,
        message: $r('app.string.offline_copy_failed')
      };
    }
  }

  async shareOriginalUrl(
    context: common.UIAbilityContext,
    title: string,
    url: string,
    dataScope: string,
    privacyMode: string
  ): Promise<OfflinePageLinkActionResult> {
    if (!this.isManagementShareAllowed(dataScope, privacyMode)) {
      return {
        ok: false,
        message: $r('app.string.offline_share_blocked')
      };
    }
    const normalizedUrl = url.trim();
    if (normalizedUrl.length === 0) {
      return {
        ok: false,
        message: $r('app.string.offline_original_link_unavailable')
      };
    }

    const normalizedTitle = title.trim().length > 0 ? title.trim() : normalizedUrl;
    try {
      await this.showSharePanel(context, normalizedTitle, normalizedUrl);
      return {
        ok: true,
        message: $r('app.string.offline_share_opened')
      };
    } catch (_error) {
      const copyResult = await this.copyOriginalUrl(normalizedUrl, dataScope, privacyMode);
      if (copyResult.ok) {
        return {
          ok: true,
          message: $r('app.string.offline_share_copied')
        };
      }
      return {
        ok: false,
        message: $r('app.string.offline_share_failed')
      };
    }
  }

  private async showSharePanel(
    context: common.UIAbilityContext,
    title: string,
    url: string
  ): Promise<void> {
    const sharedData = new systemShare.SharedData({
      utd: uniformTypeDescriptor.UniformDataType.HYPERLINK,
      content: url,
      title: title,
      description: url
    });
    const controller = new systemShare.ShareController(sharedData);
    await controller.show(context, {
      selectionMode: systemShare.SelectionMode.SINGLE,
      previewMode: systemShare.SharePreviewMode.DEFAULT
    });
  }

  private isManagementShareAllowed(dataScope: string, privacyMode: string): boolean {
    return this.privacyEffectPolicy.decide({
      intent: 'regular_profile_management_share',
      requestingBoundary: this.profileBoundaryService.buildBoundary({
        dataScope: dataScope,
        privacyMode: privacyMode
      }),
      targetScope: 'regular_profile_data',
      targetIsClear: true
    }).outcome === 'allow';
  }
}
