import { DEFAULT_THEME_PALETTE } from '../../../features/theme/palettes/DefaultThemePalette';
import { BrowserTabsOverviewLayoutStyle } from '../../../common/models/BrowserModels';
import { localizeAppearanceSettingsCopy } from '../../../core/settings/SettingsAppearanceCopy';
import {
  TabOverviewLayoutOptionState
} from '../../../core/settings/TabOverviewLayoutSettingsCoordinator';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import {
  BROWSER_IMMERSIVE_SHEET_HEADER_CONTENT_TOP_INSET,
  BROWSER_MODAL_BOTTOM_SHEET_ACTION_HEIGHT,
  BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING,
  resolveBrowserSheetHeaderBlurRadius,
  BrowserBottomSheetSurface,
  BrowserFeatureSheetHeader,
  BrowserImmersiveSheetLayout,
  BrowserSheetActionButton,
  browserSheetHeaderBlurModifier
} from '../browser/BrowserModalBottomSheet';
import { BrowserLargeScreenModalHeader } from '../browser/BrowserLargeScreenModalHeader';
import { CenteredDialogSurface } from '../common/CenteredDialogSurface';
import { SettingsGroupCard } from './SettingsLayout';
import { SettingsSwitchRow } from './SettingsRows';

const TAB_OVERVIEW_LAYOUT_SHEET_MAX_WIDTH: number = 620;
const TAB_OVERVIEW_LAYOUT_OPTION_PREVIEW_HEIGHT: number = 120;
const TAB_OVERVIEW_LAYOUT_RADIO_GROUP: string = 'tab-overview-layout-style';
/**
 * The 应用 / 取消 pair floats over the phone sheet. 110 was short of two 44vp buttons, the gap
 * and the footer padding, so the close-button switch came to rest underneath them.
 */
const TAB_OVERVIEW_LAYOUT_FOOTER_CLEARANCE: number =
  BROWSER_MODAL_BOTTOM_SHEET_ACTION_HEIGHT * 2 + 8 + BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING + 20;

@Component
export struct TabOverviewLayoutChoiceSheet {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = DEFAULT_THEME_PALETTE.light.pageBackground;
  @Prop options: TabOverviewLayoutOptionState[] = [];
  @Prop layoutMode: 'phone' | 'large_screen' = 'phone';
  @Prop closeButtonAlwaysVisible: boolean = false;
  @Prop isSaving: boolean = false;
  @Prop errorMessage: string = '';
  onSelect: (style: BrowserTabsOverviewLayoutStyle) => void = (_style: BrowserTabsOverviewLayoutStyle) => {};
  onCloseButtonAlwaysVisibleChange: (alwaysVisible: boolean) => void = (_alwaysVisible: boolean) => {};
  onCancel: () => void = () => {};
  onApply: () => void = () => {};
  @State private sheetHeaderBlurRadius: number = 0;
  @State private sheetScrollOffset: number = 0;

  build() {
    if (this.layoutMode === 'large_screen') {
      CenteredDialogSurface({ fillHeight: true }) {
        Column() {
          this.buildLargeScreenHeader()
          this.buildChoiceScroll(0, BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING)
          this.buildActionFooter()
        }
        .width('100%')
        .height('100%')
      }
    } else {
      BrowserBottomSheetSurface({
        maxWidth: TAB_OVERVIEW_LAYOUT_SHEET_MAX_WIDTH,
        surfaceColor: this.storedPageBackgroundColor,
        fullHeight: true,
        contentJustifyContent: FlexAlign.Start,
        horizontalPadding: 0,
        topPadding: 0,
        bottomPadding: 0
      }) {
        BrowserImmersiveSheetLayout({
          footerVisible: true,
          closeVisible: true,
          closeAccessibilityLabel: $r('app.string.settings_appearance_close_tab_style'),
          onClose: (): void => {
            this.onCancel();
          },
          scrollContent: () => {
            this.buildPhoneScrollContent()
          },
          header: () => {
            this.buildPhoneHeader()
          },
          footer: () => {
            this.buildActionFooter()
          }
        })
      }
    }
  }

  @Builder
  private buildLargeScreenHeader() {
    BrowserLargeScreenModalHeader({
      title: $r('app.string.settings_appearance_tab_style'),
      dialogMode: true,
      onClose: () => {
        this.onCancel();
      }
    })
  }

  @Builder
  private buildPhoneHeader() {
    // Keep this header in a @Builder. API 24 bindSheet crashes with
    // "class constructor cannot called without 'new'" if BrowserFeatureSheetHeader
    // is constructed directly inside a @BuilderParam arrow function.
    BrowserFeatureSheetHeader({
      title: $r('app.string.settings_appearance_tab_style')
    })
  }

  private sheetBlurScroller: Scroller = new Scroller();

  private noteSheetScrollOffset(offset: number): void {
    if (!Number.isFinite(offset)) {
      return;
    }
    const next = Math.max(0, offset);
    if (next === this.sheetScrollOffset) {
      return;
    }
    this.sheetScrollOffset = next;
    this.sheetHeaderBlurRadius = resolveBrowserSheetHeaderBlurRadius(next);
  }

  private resetSheetHeaderBlur(): void {
    this.sheetScrollOffset = 0;
    this.sheetHeaderBlurRadius = 0;
  }

  @Builder
  private buildPhoneScrollContent() {
    this.buildChoiceScroll(
      BROWSER_IMMERSIVE_SHEET_HEADER_CONTENT_TOP_INSET,
      TAB_OVERVIEW_LAYOUT_FOOTER_CLEARANCE
    )
  }

  private localizedOptions(): TabOverviewLayoutOptionState[] {
    const localized: TabOverviewLayoutOptionState[] = [];
    for (let index = 0; index < this.options.length; index += 1) {
      const option = this.options[index];
      const title = typeof option.title === 'string' ? localizeAppearanceSettingsCopy(option.title) : option.title;
      localized.push({
        style: option.style,
        title: title,
        isSelected: option.isSelected
      });
    }
    return localized;
  }

  @Builder
  private buildChoiceScroll(topPadding: number, bottomPadding: number) {
    Scroll(this.sheetBlurScroller) {
      Column({ space: 18 }) {
        TabOverviewLayoutOptionGrid({
          options: this.localizedOptions(),
          onSelect: (style: BrowserTabsOverviewLayoutStyle) => {
            this.onSelect(style);
          }
        })

        SettingsGroupCard({}) {
          SettingsSwitchRow({
            title: $r('app.string.settings_appearance_close_button_always'),
            checked: this.closeButtonAlwaysVisible,
            rowPosition: 'single',
            isEnabled: !this.isSaving,
            onChange: (checked: boolean) => {
              this.onCloseButtonAlwaysVisibleChange(checked);
            }
          })
        }

        if (this.errorMessage.length > 0) {
          Text(localizeAppearanceSettingsCopy(this.errorMessage))
            .width('100%')
            .fontSize(13)
            .lineHeight(18)
            .fontColor(this.storedAccentColor)
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: 16, right: 16, top: topPadding, bottom: bottomPadding })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .clip(this.layoutMode !== 'phone')
    .attributeModifier(browserSheetHeaderBlurModifier(this.layoutMode === 'phone' ? this.sheetHeaderBlurRadius : 0))
    .onAppear(() => {
      this.resetSheetHeaderBlur();
    })
    .onDidScroll((_xOffset: number, yOffset: number) => {
      this.noteSheetScrollOffset(this.sheetBlurScroller.currentOffset().yOffset);
    })
  }

  @Builder
  private buildActionFooter() {
    Column({ space: 8 }) {
      BrowserSheetActionButton({
        label: this.isSaving ? $r('app.string.settings_appearance_applying') : $r('app.string.settings_appearance_apply'),
        emphasis: 'primary',
        stacked: true,
        actionEnabled: !this.isSaving,
        accentColor: this.storedAccentColor,
        onAction: () => {
          this.onApply();
        }
      })

      BrowserSheetActionButton({
        label: $r('app.string.settings_account_cancel'),
        emphasis: 'ghost',
        stacked: true,
        actionEnabled: !this.isSaving,
        onAction: () => {
          this.onCancel();
        }
      })
    }
    .width('100%')
  }

}

/**
 * Two by two: the first pair on top, the second pair below.
 *
 * A single row of four previews is too narrow to read. The sheet and the appearance intro share
 * this grid so the fourth style does not get squeezed back into one line.
 */
@Component
export struct TabOverviewLayoutOptionGrid {
  @StorageProp(BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY) private storedResolvedThemeMode: string = 'light';
  @Prop options: TabOverviewLayoutOptionState[] = [];
  @Prop accentColor: string = '';
  @Prop primaryTextColor: string = '';
  @Prop previewHeight: number = TAB_OVERVIEW_LAYOUT_OPTION_PREVIEW_HEIGHT;
  @Prop radioGroup: string = TAB_OVERVIEW_LAYOUT_RADIO_GROUP;
  onSelect: (style: BrowserTabsOverviewLayoutStyle) => void = (_style: BrowserTabsOverviewLayoutStyle) => {};

  build() {
    // Two content-sized rows, not a Grid. Grid fills the sheet and pushed the switch down into
    // the floating buttons. ForEach keeps each tile's click on its own style.
    Column({ space: 18 }) {
      Row({ space: 12 }) {
        ForEach(this.optionsInRange(0, 2), (option: TabOverviewLayoutOptionState) => {
          TabOverviewLayoutOption({
            option: option,
            previewResource: this.resolvePreviewResource(option.style),
            accentColor: this.accentColor,
            primaryTextColor: this.primaryTextColor,
            previewHeight: this.previewHeight,
            radioGroup: this.radioGroup,
            onSelect: (style: BrowserTabsOverviewLayoutStyle) => {
              this.onSelect(style);
            }
          })
            .layoutWeight(1)
        }, (option: TabOverviewLayoutOptionState) => `${option.style}:${option.isSelected ? 'selected' : 'idle'}`)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.options.length > 2) {
        Row({ space: 12 }) {
          ForEach(this.optionsInRange(2, 4), (option: TabOverviewLayoutOptionState) => {
            TabOverviewLayoutOption({
              option: option,
              previewResource: this.resolvePreviewResource(option.style),
              accentColor: this.accentColor,
              primaryTextColor: this.primaryTextColor,
              previewHeight: this.previewHeight,
              radioGroup: this.radioGroup,
              onSelect: (style: BrowserTabsOverviewLayoutStyle) => {
                this.onSelect(style);
              }
            })
              .layoutWeight(1)
          }, (option: TabOverviewLayoutOptionState) => `${option.style}:${option.isSelected ? 'selected' : 'idle'}`)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
    }
    .width('100%')
  }

  private optionsInRange(start: number, end: number): TabOverviewLayoutOptionState[] {
    const result: TabOverviewLayoutOptionState[] = [];
    const last = Math.min(end, this.options.length);
    for (let index = start; index < last; index++) {
      const option = this.options[index];
      if (option !== undefined) {
        result.push(option);
      }
    }
    return result;
  }

  private resolvePreviewResource(style: BrowserTabsOverviewLayoutStyle): Resource {
    if (style === 'horizontal_cards') {
      return this.storedResolvedThemeMode === 'dark' ?
        $r('app.media.tab_overview_large_cards_dark') : $r('app.media.tab_overview_large_cards_light');
    }
    if (style === 'stack') {
      return this.storedResolvedThemeMode === 'dark' ?
        $r('app.media.tab_overview_stack_dark') : $r('app.media.tab_overview_stack_light');
    }
    if (style === 'list') {
      return this.storedResolvedThemeMode === 'dark' ?
        $r('app.media.tab_overview_list_dark') : $r('app.media.tab_overview_list_light');
    }
    return this.storedResolvedThemeMode === 'dark' ?
      $r('app.media.tab_overview_grid_dark') : $r('app.media.tab_overview_grid_light');
  }
}

@Component
export struct TabOverviewLayoutOption {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @Prop option: TabOverviewLayoutOptionState = {
    style: 'grid',
    title: '卡片平铺',
    isSelected: false
  };
  @Prop previewResource: Resource = $r('app.media.tab_overview_grid_light');
  @Prop accentColor: string = '';
  @Prop primaryTextColor: string = '';
  @Prop previewHeight: number = TAB_OVERVIEW_LAYOUT_OPTION_PREVIEW_HEIGHT;
  @Prop radioGroup: string = TAB_OVERVIEW_LAYOUT_RADIO_GROUP;
  onSelect: (style: BrowserTabsOverviewLayoutStyle) => void = (_style: BrowserTabsOverviewLayoutStyle) => {};

  build() {
    Column({ space: 10 }) {
      Image(this.previewResource)
        .width('100%')
        .height(this.previewHeight)
        .objectFit(ImageFit.Contain)

      Text(this.option.title)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.resolvePrimaryTextColor())
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Radio({
        value: this.option.style,
        group: this.radioGroup
      })
        .checked(this.option.isSelected)
        .hitTestBehavior(HitTestMode.None)
        .radioStyle({ checkedBackgroundColor: this.resolveAccentColor() })
        .onChange((checked: boolean) => {
          if (checked) {
            this.onSelect(this.option.style);
          }
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onSelect(this.option.style);
    })
  }

  private resolveAccentColor(): string {
    return this.accentColor.length > 0 ? this.accentColor : this.storedAccentColor;
  }

  private resolvePrimaryTextColor(): string {
    return this.primaryTextColor.length > 0 ? this.primaryTextColor : this.storedPrimaryTextColor;
  }
}

