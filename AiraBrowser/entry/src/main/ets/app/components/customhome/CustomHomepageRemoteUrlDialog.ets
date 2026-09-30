import { SettingsTextField } from '../settings/SettingsRows';
import { BrowserSheetActionButton } from '../browser/BrowserModalBottomSheet';
import { CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER } from '../common/CenteredDialogSurface';

@CustomDialog
export struct CustomHomepageRemoteUrlDialog {
  @Prop accentColor: ResourceColor = '';
  @Prop controlBackgroundColor: ResourceColor = '';
  @Prop primaryTextColor: ResourceColor = '';
  @Prop secondaryTextColor: ResourceColor = '';
  controller?: CustomDialogController;
  @Link urlDraft: string;
  @Link errorText: string;
  confirm: () => boolean = (): boolean => true;

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.settings_custom_home_add_url'))
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryTextColor)
        .textAlign(TextAlign.Center)

      SettingsTextField({
        text: this.urlDraft,
        placeholder: 'https://example.com',
        helperText: $r('app.string.settings_custom_home_url_helper'),
        errorText: this.errorText,
        underlineStyle: true,
        controlBackgroundColor: this.controlBackgroundColor,
        primaryTextColor: this.primaryTextColor,
        secondaryTextColor: this.secondaryTextColor,
        onChange: (value: string) => {
          this.urlDraft = value;
          this.errorText = '';
        }
      })

      Column({ space: 8 }) {
        BrowserSheetActionButton({
          label: $r('app.string.settings_custom_home_add'),
          emphasis: 'primary',
          stacked: true,
          accentColor: this.accentColor,
          buttonHeight: 44,
          fontSize: 15,
          onAction: () => {
            if (this.confirm()) {
              this.controller?.close();
            }
          }
        })

        BrowserSheetActionButton({
          label: $r('app.string.settings_custom_home_cancel'),
          emphasis: 'ghost',
          stacked: true,
          buttonHeight: 44,
          fontSize: 15,
          onAction: () => {
            this.controller?.close();
          }
        })
      }
      .width('100%')
    }
    .attributeModifier(CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER)
  }
}

