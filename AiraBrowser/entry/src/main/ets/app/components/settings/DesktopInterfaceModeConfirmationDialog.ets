import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { BrowserSheetActionButton } from '../browser/BrowserModalBottomSheet';
import { CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER } from '../common/CenteredDialogSurface';
import { localizeSettingsCopy } from '../../../core/settings/SettingsCopy';

@CustomDialog
export struct DesktopInterfaceModeConfirmationDialog {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  controller?: CustomDialogController;
  @Link accepted: boolean;
  onCancel: () => void = () => {};
  onConfirm: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      Column({ space: 8 }) {
        Text($r('app.string.settings_desktop_on_phone_title'))
          .width('100%')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.storedPrimaryTextColor)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text($r('app.string.settings_desktop_on_phone_message'))
          .width('100%')
          .fontSize(14)
          .lineHeight(20)
          .fontColor(this.storedSecondaryTextColor)
          .textAlign(TextAlign.Start)
      }
      .width('100%')

      this.buildAcceptanceRow()

      Column({ space: 8 }) {
        BrowserSheetActionButton({
          label: localizeSettingsCopy('继续切换'),
          emphasis: 'primary',
          stacked: true,
          actionEnabled: this.accepted,
          accentColor: this.storedAccentColor,
          buttonHeight: 44,
          fontSize: 15,
          onAction: () => {
            this.onConfirm();
            this.controller?.close();
          }
        })

        BrowserSheetActionButton({
          label: localizeSettingsCopy('取消'),
          emphasis: 'ghost',
          stacked: true,
          buttonHeight: 44,
          fontSize: 15,
          onAction: () => {
            this.onCancel();
            this.controller?.close();
          }
        })
      }
      .width('100%')
    }
    .attributeModifier(CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER)
  }

  @Builder
  private buildAcceptanceRow() {
    Row({ space: 10 }) {
      Checkbox()
        .select(this.accepted)
        .selectedColor(this.storedAccentColor)
        .width(20)
        .height(20)
        .hitTestBehavior(HitTestMode.None)

      Text($r('app.string.settings_desktop_on_phone_ack'))
        .layoutWeight(1)
        .fontSize(14)
        .lineHeight(20)
        .fontColor(this.storedPrimaryTextColor)
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.accepted = !this.accepted;
    })
  }
}

