import { BrowserLargeScreenModalHeader } from '../browser/BrowserLargeScreenModalHeader';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_OUTLINE_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';

const DESKTOP_TAB_PLACEMENT_RADIO_GROUP: string = 'desktop-tab-placement';

@Component
export struct DesktopTabPlacementChoiceDialog {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private accentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private pageBackgroundColor: string = '#F2F3F5';
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private surfaceBackgroundColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private primaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private secondaryTextColor: string = '#5F6368';
  @StorageProp(BROWSER_THEME_STORAGE_OUTLINE_KEY) private previewOutlineColor: string = '#26000000';
  @Prop selectedPlacement: string = 'horizontal';
  @Prop isSaving: boolean = false;
  onSelect: (placement: string) => void = (_placement: string) => {};
  onClose: () => void = () => {};

  build() {
    Column() {
      BrowserLargeScreenModalHeader({
        title: $r('app.string.settings_appearance_tab_style'),
        dialogMode: true,
        onClose: (): void => {
          if (!this.isSaving) {
            this.onClose();
          }
        }
      })
      Row({ space: 8 }) {
        this.buildChoice('horizontal', $r('app.string.settings_appearance_horizontal_tabs'))
        this.buildChoice('vertical', $r('app.string.settings_appearance_vertical_tabs'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .width('100%')
  }

  @Builder
  private buildChoice(placement: string, title: ResourceStr) {
    Column({ space: 10 }) {
      this.buildPreview(placement)

      Text(title)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor)
        .textAlign(TextAlign.Center)
        .maxLines(1)

      Radio({
        value: placement,
        group: DESKTOP_TAB_PLACEMENT_RADIO_GROUP
      })
        .checked(this.isPlacementSelected(placement))
        .enabled(!this.isSaving)
        .hitTestBehavior(HitTestMode.None)
        .radioStyle({ checkedBackgroundColor: this.accentColor })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .opacity(this.isSaving ? 0.48 : 1)
    .onClick((): void => {
      this.choose(placement);
    })
  }

  @Builder
  private buildPreview(placement: string) {
    Column() {
      if (placement === 'vertical') {
        Row({ space: 6 }) {
          Column({ space: 4 }) {
            this.buildChip(true)
            this.buildChip(true)
            this.buildChip(true)
          }
          .width(28)
          .height('100%')
          .justifyContent(FlexAlign.Start)

          Column()
            .layoutWeight(1)
            .height('100%')
            .borderRadius(8)
            .backgroundColor(this.pageBackgroundColor)
        }
        .width('100%')
        .height('100%')
      } else {
        Column({ space: 6 }) {
          Row({ space: 4 }) {
            this.buildChip(false)
            this.buildChip(false)
            this.buildChip(false)
          }
          .width('100%')
          .height(16)

          Column()
            .width('100%')
            .layoutWeight(1)
            .borderRadius(8)
            .backgroundColor(this.pageBackgroundColor)
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height(112)
    .padding(8)
    .borderRadius(12)
    .border({ width: 1, color: this.previewOutlineColor })
    .backgroundColor(this.surfaceBackgroundColor)
    .alignItems(HorizontalAlign.Start)
    .clip(true)
  }

  @Builder
  private buildChip(stacked: boolean) {
    if (stacked) {
      Row()
        .width('100%')
        .height(14)
        .borderRadius(4)
        .backgroundColor(this.secondaryTextColor)
        .opacity(0.28)
    } else {
      Row()
        .layoutWeight(1)
        .height(14)
        .borderRadius(4)
        .backgroundColor(this.secondaryTextColor)
        .opacity(0.28)
    }
  }

  private isPlacementSelected(placement: string): boolean {
    return placement === 'vertical' ?
      this.selectedPlacement === 'vertical' :
      this.selectedPlacement !== 'vertical';
  }

  private choose(placement: string): void {
    if (this.isSaving) {
      return;
    }
    this.onSelect(placement);
  }
}
