import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { BrowserSheetActionButton } from '../browser/BrowserModalBottomSheet';
import { CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER } from '../common/CenteredDialogSurface';

@CustomDialog
export struct SyncExperienceLinesDialog {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  controller?: CustomDialogController;
  @Link title: ResourceStr;
  @Link lines: ResourceStr[];
  @Link actionKind: string;
  onRetry: () => void = () => {};
  onChangeMethod: () => void = () => {};
  onDismiss: () => void = () => {};

  build() {
    Column({ space: 0 }) {
      Text(this.resolveTitle())
        .width('100%')
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.storedPrimaryTextColor)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ bottom: 18 })

      Scroll() {
        Column({ space: 10 }) {
          ForEach(this.lineIndexes(), (index: number) => {
            Text(this.lines[index])
              .width('100%')
              .fontSize(14)
              .lineHeight(21)
              .fontColor(this.storedPrimaryTextColor)
              .textAlign(TextAlign.Start)
          }, (index: number) => `${index}`)
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: 340 })
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)

      Column({ space: 8 }) {
        if (this.actionKind === 'retry' || this.actionKind === 'retry_change') {
          BrowserSheetActionButton({
            stacked: true,
            label: $r('app.string.settings_sync_retry_sync'),
            emphasis: 'primary',
            accentColor: this.storedAccentColor,
            fillAvailableWidth: false,
            buttonWidth: '100%',
            buttonHeight: 44,
            fontSize: 15,
            onAction: () => {
              this.onRetry();
            }
          })
        }
        if (this.actionKind === 'change' || this.actionKind === 'retry_change') {
          BrowserSheetActionButton({
            stacked: true,
            label: $r('app.string.settings_sync_change_method'),
            emphasis: this.actionKind === 'change' ? 'primary' : 'ghost',
            accentColor: this.storedAccentColor,
            fillAvailableWidth: false,
            buttonWidth: '100%',
            buttonHeight: 44,
            fontSize: 15,
            onAction: () => {
              this.onChangeMethod();
            }
          })
        }
        BrowserSheetActionButton({
          stacked: true,
          label: $r('app.string.settings_pro_got_it'),
          emphasis: this.actionKind === 'confirm' ? 'primary' : 'ghost',
          accentColor: this.storedAccentColor,
          fillAvailableWidth: false,
          buttonWidth: '100%',
          buttonHeight: 44,
          fontSize: 15,
          onAction: () => {
            this.onDismiss();
          }
        })
      }
      .width('100%')
      .margin({ top: 20 })
    }
    .attributeModifier(CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER)
  }

  private resolveTitle(): ResourceStr {
    if (typeof this.title === 'string' && this.title.length === 0) {
      return $r('app.string.settings_sync_result_fallback');
    }
    return this.title;
  }

  private lineIndexes(): number[] {
    const indexes: number[] = [];
    for (let index = 0; index < this.lines.length; index += 1) {
      indexes.push(index);
    }
    return indexes;
  }
}
