import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import {
  CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER
} from '../common/CenteredDialogSurface';

@CustomDialog
export struct SyncOperationProgressDialog {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  controller?: CustomDialogController;
  @Link inProgress: boolean;
  @Link title: ResourceStr;
  @Link subtitle: ResourceStr;
  @Link progress: number;
  @Link details: ResourceStr;
  @Link detailOpacity: number;

  build() {
    Column({ space: 16 }) {
      if (this.inProgress) {
        LoadingProgress()
          .width(72)
          .height(72)
          .color(this.storedAccentColor)
      } else {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(72)
          .fontColor([this.storedAccentColor])
      }

      Row() {
        Text(this.resolveTitle())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.storedPrimaryTextColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '78%' })
        Text(`${this.resolveProgress()}%`)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.storedPrimaryTextColor)
          .margin({ left: 4 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Text(this.resolveDetails())
        .width('100%')
        .fontSize(14)
        .lineHeight(20)
        .fontColor(this.storedSecondaryTextColor)
        .textAlign(TextAlign.Center)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .opacity(this.detailOpacity)
        .animation({ duration: 240, curve: Curve.EaseInOut })
    }
    // The shared surface already applies the centered-dialog padding and the
    // 420vp width cap. A second inset here made this alert looser than the others.
    .attributeModifier(CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER)
  }

  private resolveProgress(): number {
    return Math.max(0, Math.min(100, Math.round(this.progress)));
  }

  private resolveTitle(): ResourceStr {
    return this.hasVisibleText(this.title) ? this.title : $r('app.string.settings_sync_processing');
  }

  private resolveDetails(): ResourceStr {
    if (this.hasVisibleText(this.details)) {
      return this.details;
    }
    return this.hasVisibleText(this.subtitle) ? this.subtitle : $r('app.string.settings_sync_please_wait');
  }

  private hasVisibleText(value: ResourceStr): boolean {
    return typeof value !== 'string' || value.length > 0;
  }
}
