import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { SyncFailureDetailItem } from '../../../core/sync/SyncFailurePresentationService';
import { BrowserSheetActionButton } from '../browser/BrowserModalBottomSheet';
import { CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER } from '../common/CenteredDialogSurface';

@CustomDialog
export struct SyncFailureDialog {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  controller?: CustomDialogController;
  @Link title: ResourceStr;
  @Link summary: ResourceStr;
  @Link details: SyncFailureDetailItem[];
  copyDetails: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text(this.resolveTitle())
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.storedPrimaryTextColor)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.summary)
        .width('100%')
        .fontSize(15)
        .lineHeight(22)
        .fontColor(this.storedPrimaryTextColor)
        .textAlign(TextAlign.Start)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Column({ space: 10 }) {
        Text($r('app.string.settings_sync_advanced_technical'))
          .width('100%')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.storedSecondaryTextColor)
          .textAlign(TextAlign.Start)

        ForEach(this.details, (detail: SyncFailureDetailItem) => {
          this.buildDetailRow(detail)
        }, (detail: SyncFailureDetailItem) => detail.label)
      }
      .width('100%')

      Column({ space: 8 }) {
        BrowserSheetActionButton({
          label: $r('app.string.settings_pro_got_it'),
          emphasis: 'primary',
          stacked: true,
          accentColor: this.storedAccentColor,
          buttonHeight: 44,
          fontSize: 15,
          onAction: () => {
            this.controller?.close();
          }
        })

        BrowserSheetActionButton({
          label: $r('app.string.settings_sync_advanced_copy_details'),
          emphasis: 'ghost',
          stacked: true,
          buttonHeight: 44,
          fontSize: 15,
          onAction: () => {
            this.copyDetails();
          }
        })
      }
      .width('100%')
    }
    .attributeModifier(CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER)
  }

  private resolveTitle(): ResourceStr {
    if (typeof this.title !== 'string') {
      return this.title;
    }
    if (this.title.length === 0 || this.title === '同步失败') {
      return $r('app.string.settings_sync_failed');
    }
    return this.title;
  }

  private resolveDetailLabel(label: string): ResourceStr {
    if (label === '同步方式') {
      return $r('app.string.settings_sync_advanced_detail_method');
    }
    if (label === '操作') {
      return $r('app.string.settings_sync_advanced_detail_action');
    }
    if (label === '请求路径') {
      return $r('app.string.settings_sync_advanced_detail_path');
    }
    if (label === 'HTTP 状态码') {
      return $r('app.string.settings_sync_advanced_detail_status');
    }
    if (label === '技术信息') {
      return $r('app.string.settings_sync_advanced_technical');
    }
    if (label === '未提供') {
      return $r('app.string.settings_sync_advanced_detail_missing');
    }
    return label;
  }

  private resolveDetailValue(value: string): ResourceStr {
    if (value === '未提供') {
      return $r('app.string.settings_sync_advanced_detail_missing');
    }
    if (value === '检查远端数据') {
      return $r('app.string.settings_sync_advanced_check_remote');
    }
    if (value === '覆盖书签') {
      return $r('app.string.settings_sync_advanced_overwrite');
    }
    if (value === '立即合并同步') {
      return $r('app.string.settings_sync_advanced_merge');
    }
    if (value === '更改同步方式') {
      return $r('app.string.settings_sync_advanced_change_method');
    }
    if (value === '同步服务') {
      return $r('app.string.settings_sync_advanced_service');
    }
    if (value === '华为云空间同步') {
      return $r('app.string.settings_sync_advanced_huawei_sync');
    }
    if (value === 'Aira 云同步') {
      return $r('app.string.settings_sync_goal_cloud');
    }
    if (value === '私有化部署') {
      return $r('app.string.settings_pro_self_hosting');
    }
    return value;
  }

  @Builder
  private buildDetailRow(detail: SyncFailureDetailItem) {
    Row({ space: 12 }) {
      Text(this.resolveDetailLabel(detail.label))
        .width(78)
        .fontSize(13)
        .fontColor(this.storedSecondaryTextColor)
        .textAlign(TextAlign.Start)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.resolveDetailValue(detail.value))
        .layoutWeight(1)
        .fontSize(13)
        .fontColor(this.storedPrimaryTextColor)
        .textAlign(TextAlign.End)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}

