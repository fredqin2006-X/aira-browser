import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { CENTERED_DIALOG_SYSTEM_COMPACT_SURFACE_MODIFIER } from '../common/CenteredDialogSurface';

@CustomDialog
export struct HuaweiPaymentLaunchDialog {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  controller?: CustomDialogController;

  build() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(32)
        .height(32)
        .color(this.storedAccentColor)
      Text($r('app.string.membership_iap_launching'))
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.storedPrimaryTextColor)
        .textAlign(TextAlign.Center)
        .maxLines(2)
    }
    .attributeModifier(CENTERED_DIALOG_SYSTEM_COMPACT_SURFACE_MODIFIER)
  }
}
