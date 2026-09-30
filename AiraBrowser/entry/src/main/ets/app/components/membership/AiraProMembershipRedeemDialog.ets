import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_CONTROL_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_DIVIDER_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import {
  AIRA_MEMBERSHIP_REDEEM_CODE_GROUP_LENGTH,
  AIRA_MEMBERSHIP_REDEEM_CODE_LENGTH,
  isValidMembershipRedeemCode,
  normalizeMembershipRedeemCode
} from '../../../core/membership/AiraProMembershipRedeemResult';
import { BrowserSheetActionButton } from '../browser/BrowserModalBottomSheet';
import { CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER } from '../common/CenteredDialogSurface';

@CustomDialog
export struct AiraProMembershipRedeemDialog {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_CONTROL_BACKGROUND_KEY) private storedControlBackgroundColor: string = '#F4F6F8';
  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY) private storedDividerColor: string = '#E3E8EF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  controller?: CustomDialogController;
  @Link codeDraft: string;
  @State private codeFocused: boolean = true;
  @State private caretVisible: boolean = true;
  private groupOffsets: number[] = [0, 1, 2, 3];
  private caretTimer: number = -1;
  onRedeem: (code: string) => void = (_code: string) => {};

  aboutToAppear(): void {
    this.caretTimer = setInterval((): void => {
      this.caretVisible = !this.caretVisible;
    }, 530);
  }

  aboutToDisappear(): void {
    if (this.caretTimer >= 0) {
      clearInterval(this.caretTimer);
      this.caretTimer = -1;
    }
  }

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.settings_pro_redeem'))
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.storedPrimaryTextColor)
        .textAlign(TextAlign.Center)

      Stack() {
        Row() {
          this.buildCellGroup(0)
          Text('-')
            .width(14)
            .fontSize(16)
            .fontColor(this.storedSecondaryTextColor)
            .textAlign(TextAlign.Center)
          this.buildCellGroup(AIRA_MEMBERSHIP_REDEEM_CODE_GROUP_LENGTH)
        }
        .width('100%')
        .height(44)
        .alignItems(VerticalAlign.Center)
        .hitTestBehavior(HitTestMode.None)

        TextInput({ text: this.codeDraft })
          .width('100%')
          .height(44)
          .opacity(0)
          .defaultFocus(true)
          .maxLength(20)
          .onChange((value: string) => {
            this.codeDraft = normalizeMembershipRedeemCode(value);
          })
          .onEditChange((isEditing: boolean) => {
            this.codeFocused = isEditing;
          })
          .onSubmit(() => {
            this.submit();
          })
      }
      .width('100%')
      .height(44)

      Column({ space: 8 }) {
        BrowserSheetActionButton({
          label: $r('app.string.settings_pro_redeem_action'),
          emphasis: 'primary',
          stacked: true,
          actionEnabled: this.canRedeem(),
          accentColor: this.storedAccentColor,
          buttonHeight: 44,
          fontSize: 15,
          onAction: () => {
            this.submit();
          }
        })

        BrowserSheetActionButton({
          label: $r('app.string.settings_account_cancel'),
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

  @Builder
  private buildCellGroup(start: number) {
    Row({ space: 6 }) {
      ForEach(this.groupOffsets, (offset: number) => {
        this.buildCell(start + offset)
      }, (offset: number) => `${start}-${offset}`)
    }
    .layoutWeight(1)
    .height(44)
  }

  @Builder
  private buildCell(index: number) {
    Column() {
      Row() {
        if (this.cellText(index).length > 0) {
          Text(this.cellText(index))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.storedPrimaryTextColor)
        }
        if (this.isActiveCell(index) && this.caretVisible) {
          Column()
            .width(1.5)
            .height(18)
            .borderRadius(1)
            .backgroundColor(this.storedAccentColor)
            .margin({ left: this.cellText(index).length > 0 ? 1 : 0 })
        }
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .layoutWeight(1)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .borderRadius(8)
    .backgroundColor(this.storedControlBackgroundColor)
    .border({
      width: this.isActiveCell(index) ? 1.5 : 1,
      color: this.isActiveCell(index) ? this.storedAccentColor : this.storedDividerColor
    })
  }

  private cellText(index: number): string {
    const code = normalizeMembershipRedeemCode(this.codeDraft);
    if (index < 0 || index >= code.length) {
      return '';
    }
    return code.charAt(index);
  }

  private isActiveCell(index: number): boolean {
    if (!this.codeFocused) {
      return false;
    }
    const length = normalizeMembershipRedeemCode(this.codeDraft).length;
    if (length >= AIRA_MEMBERSHIP_REDEEM_CODE_LENGTH) {
      return index === AIRA_MEMBERSHIP_REDEEM_CODE_LENGTH - 1;
    }
    return index === length;
  }

  private canRedeem(): boolean {
    return isValidMembershipRedeemCode(this.codeDraft);
  }

  private submit(): void {
    const code = this.codeDraft.trim();
    if (code.length <= 0) {
      return;
    }
    this.onRedeem(code);
  }
}
