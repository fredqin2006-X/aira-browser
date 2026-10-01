import { resolveAppResourceText } from '../../../core/resources/AppResourceText';
import {
  WallpaperColorChoiceViewState,
  WallpaperImageOptionViewState,
  WallpaperSettingsViewState
} from '../../../core/wallpaper/WallpaperSettingsViewModel';
import {
  WallpaperSettingsLayoutPolicy,
  WallpaperSettingsLayoutState
} from '../../../core/wallpaper/WallpaperSettingsLayoutPolicy';
import { WallpaperMode } from '../../../common/models/WallpaperModels';
import {
  SettingsFooterText,
  SettingsGroupCard,
  SettingsSection
} from '../settings/SettingsLayout';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_CONTROL_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_ON_ACCENT_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';

const WALLPAPER_IMAGE_CARD_CORNER_RADIUS: number = 22;
const WALLPAPER_IMAGE_SELECTION_HEIGHT: number = 54;
const WALLPAPER_IMAGE_CARD_RADIO_GROUP: string = 'wallpaper-image-options';
const WALLPAPER_IMAGE_SELECTED_BORDER_WIDTH: number = 2;
const WALLPAPER_CUSTOM_REPLACE_CAPSULE_WIDTH: number = 60;
const WALLPAPER_CUSTOM_REPLACE_CAPSULE_HEIGHT: number = 28;
const WALLPAPER_CUSTOM_REPLACE_CAPSULE_BOTTOM_MARGIN: number = 14;
const WALLPAPER_CUSTOM_REPLACE_CAPSULE_END_MARGIN: number = 14;
const WALLPAPER_COLOR_SWATCH_SIZE: number = 34;
/** The selection ring sits outside the swatch, so the ring is fully drawn and never covers it. */
const WALLPAPER_COLOR_SWATCH_RING_GAP: number = 4;
const WALLPAPER_COLOR_SWATCH_RING_WIDTH: number = 2;
/** A white swatch on a white card still needs an edge. */
const WALLPAPER_COLOR_SWATCH_EDGE_COLOR: string = '#1F000000';

@Component
export struct WallpaperSettingsContent {
  private layoutPolicy: WallpaperSettingsLayoutPolicy = new WallpaperSettingsLayoutPolicy();
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_CONTROL_BACKGROUND_KEY) private storedControlBackgroundColor: string = '#EEF2F6';
  @StorageProp(BROWSER_THEME_STORAGE_ON_ACCENT_KEY) private storedOnAccentColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private storedSurfaceBackgroundColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  @Prop state: WallpaperSettingsViewState;
  @State private layoutState: WallpaperSettingsLayoutState = this.layoutPolicy.resolve({
    containerWidth: 390,
    containerHeight: 844
  });
  onColorSelect: (choiceId: string) => void = (_choiceId: string) => {};
  onModeSelect: (mode: WallpaperMode) => void = (_mode: WallpaperMode) => {};
  onVideoSelect: () => void = () => {};
  onBingRetry: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      this.buildColorSection()
      this.buildImageModeSection()
    }
    .width('100%')
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.updateResponsiveLayout(
        this.parseAreaDimension(newArea.width),
        this.parseAreaDimension(newArea.height)
      );
    })
  }

  /** One row of round swatches: the flat colors, then the follow-theme gradient last. */
  @Builder
  private buildColorSection() {
    SettingsSection({
      title: $r('app.string.wallpaper_ui_wallpaper_settings_screen_003'),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
        // Space-between keeps every swatch on one line on a narrow phone, where fixed gaps
        // would push the last one out of the card.
        Row() {
          ForEach(this.state.colorChoices, (choice: WallpaperColorChoiceViewState) => {
            this.buildColorSwatch(choice)
          }, (choice: WallpaperColorChoiceViewState) => `${choice.id}:${choice.isSelected ? '1' : '0'}`)
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 16, bottom: 16 })
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
      }
    }
  }

  @Builder
  private buildColorSwatch(choice: WallpaperColorChoiceViewState) {
    Stack({ alignContent: Alignment.Center }) {
      if (choice.kind === 'auto') {
        this.buildAutoBlackWhiteSwatch()
      } else if (choice.kind === 'theme') {
        this.buildMeshGradientSwatch()
      } else {
        Row()
          .width(WALLPAPER_COLOR_SWATCH_SIZE)
          .height(WALLPAPER_COLOR_SWATCH_SIZE)
          .borderRadius(WALLPAPER_COLOR_SWATCH_SIZE / 2)
          .backgroundColor(choice.color)
          .border({ width: 1, color: WALLPAPER_COLOR_SWATCH_EDGE_COLOR })
      }
    }
    .width(this.resolveSwatchOuterSize())
    .height(this.resolveSwatchOuterSize())
    .borderRadius(this.resolveSwatchOuterSize() / 2)
    .border({
      width: choice.isSelected ? WALLPAPER_COLOR_SWATCH_RING_WIDTH : 0,
      color: choice.isSelected ? this.storedAccentColor : Color.Transparent
    })
    .enabled(choice.isEnabled)
    .accessibilityText(choice.isSelected
      ? resolveAppResourceText($r('app.string.wallpaper_selected', choice.label))
      : choice.label)
    .onClick(() => {
      if (choice.isEnabled) {
        this.onColorSelect(choice.id);
      }
    })
  }

  /**
   * One swatch for both neutrals: white half and black half. It means "white in light mode,
   * black in dark mode", so the two are no longer separate choices.
   */
  @Builder
  private buildAutoBlackWhiteSwatch() {
    Row() {
      Row()
        .layoutWeight(1)
        .height('100%')
        .backgroundColor('#FFFFFF')
        .borderRadius({
          topLeft: WALLPAPER_COLOR_SWATCH_SIZE / 2,
          bottomLeft: WALLPAPER_COLOR_SWATCH_SIZE / 2
        })
      Row()
        .layoutWeight(1)
        .height('100%')
        .backgroundColor('#000000')
        .borderRadius({
          topRight: WALLPAPER_COLOR_SWATCH_SIZE / 2,
          bottomRight: WALLPAPER_COLOR_SWATCH_SIZE / 2
        })
    }
    .width(WALLPAPER_COLOR_SWATCH_SIZE)
    .height(WALLPAPER_COLOR_SWATCH_SIZE)
    .borderRadius(WALLPAPER_COLOR_SWATCH_SIZE / 2)
    .border({ width: 1, color: WALLPAPER_COLOR_SWATCH_EDGE_COLOR })
    .clip(true)
  }

  /**
   * Stands in for "follow the theme": the theme color is whatever the palette picks, so the
   * swatch shows a mix of hues instead of one flat color.
   *
   * Every layer carries the circle radius itself. A gradient is not rounded by the parent's
   * clip, and without this the swatch shows square corners. The radii are wide so the blobs
   * cover the whole disc, with no pale gaps left at the edge.
   */
  @Builder
  private buildMeshGradientSwatch() {
    Stack() {
      this.buildMeshLayer('#F1F2F7', '', '', 0)
      this.buildMeshLayer('#FF7A59', '16%', '18%', 100)
      this.buildMeshLayer('#7B6CFF', '84%', '22%', 96)
      this.buildMeshLayer('#35D0BA', '20%', '86%', 100)
      this.buildMeshLayer('#FFC24B', '86%', '84%', 94)
    }
    .width(WALLPAPER_COLOR_SWATCH_SIZE)
    .height(WALLPAPER_COLOR_SWATCH_SIZE)
    .borderRadius(WALLPAPER_COLOR_SWATCH_SIZE / 2)
    .border({ width: 1, color: WALLPAPER_COLOR_SWATCH_EDGE_COLOR })
    .clip(true)
  }

  @Builder
  private buildMeshLayer(
    color: string,
    centerX: string,
    centerY: string,
    radiusPercent: number
  ) {
    if (radiusPercent <= 0) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor(color)
        .borderRadius(WALLPAPER_COLOR_SWATCH_SIZE / 2)
    } else {
      Row()
        .width('100%')
        .height('100%')
        .borderRadius(WALLPAPER_COLOR_SWATCH_SIZE / 2)
        .radialGradient({
          center: [centerX, centerY],
          radius: `${radiusPercent}%`,
          colors: [[color, 0.0], [`#00${color.substring(1)}`, 1.0]]
        })
    }
  }

  private resolveSwatchOuterSize(): number {
    return WALLPAPER_COLOR_SWATCH_SIZE + WALLPAPER_COLOR_SWATCH_RING_GAP * 2;
  }

  @Builder
  private buildImageModeSection() {
    Row() {
      Column() {
        SettingsSection({
          title: $r('app.string.wallpaper_ui_wallpaper_settings_screen_002'),
          secondaryTextColor: this.storedSecondaryTextColor
        }) {
          Row({ space: this.layoutState.cardGap }) {
            ForEach(this.state.imageOptions, (option: WallpaperImageOptionViewState) => {
              this.buildImageModeCard(option)
            }, (option: WallpaperImageOptionViewState) =>
              `${option.id}:${option.previewPath}:${option.isSelected}:${this.state.bingPreviewStatus}:${this.state.mode}:${this.layoutState.mode}`)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          if ((this.state.bingPreviewStatusText ?? '').length > 0) {
            this.buildBingPreviewStatus()
          }

          SettingsFooterText({
            text: this.state.footerText,
            secondaryTextColor: this.storedSecondaryTextColor
          })
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: this.layoutState.groupMaxWidth })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private buildImageModeCard(option: WallpaperImageOptionViewState) {
    Column({ space: 10 }) {
      Button() {
        this.buildImageModePreview(option)
      }
      .width('100%')
      .aspectRatio(this.layoutState.previewAspectRatio)
      .type(ButtonType.Normal)
      .accessibilityText(this.resolvePreviewAccessibilityText(option))
      .padding(0)
      .backgroundColor(this.storedControlBackgroundColor)
      .border({
        width: option.isSelected ? WALLPAPER_IMAGE_SELECTED_BORDER_WIDTH : 0,
        color: this.storedAccentColor
      })
      .borderRadius(WALLPAPER_IMAGE_CARD_CORNER_RADIUS)
      .clip(true)
      .stateEffect(true)
      .onClick(() => {
        this.selectImageOption(option);
      })

      this.buildImageModeSelection(option)
    }
    .layoutWeight(1)
    .enabled(option.isEnabled)
    .opacity(option.isEnabled ? 1 : 0.48)
  }

  @Builder
  private buildImageModePreview(option: WallpaperImageOptionViewState) {
    Stack({ alignContent: Alignment.Center }) {
      if (option.previewPath.trim().length > 0) {
        Image(option.previewPath)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .interpolation(ImageInterpolation.Medium)
          .borderRadius(WALLPAPER_IMAGE_CARD_CORNER_RADIUS)
          .clip(true)
        if (option.id === 'custom' || option.id === 'video') {
          this.buildCustomReplaceCapsule()
        }
      } else if (option.id === 'video') {
        SymbolGlyph($r('sys.symbol.play_fill'))
          .fontSize(34)
          .fontWeight(FontWeight.Medium)
          .fontColor([this.storedSecondaryTextColor])
      } else if (option.id === 'bing' && this.state.bingPreviewStatus === 'loading') {
        LoadingProgress()
          .width(30)
          .height(30)
          .color(this.storedAccentColor)
      } else if (option.id === 'bing' && this.state.bingPreviewStatus === 'error') {
        Text($r('app.string.history_load_failed'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.storedSecondaryTextColor)
      } else if (option.id === 'custom') {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(34)
          .fontWeight(FontWeight.Medium)
          .fontColor([this.storedSecondaryTextColor])
      } else {
        Text('Bing')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.storedSecondaryTextColor)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.storedControlBackgroundColor)
    .borderRadius(WALLPAPER_IMAGE_CARD_CORNER_RADIUS)
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private buildCustomReplaceCapsule() {
    Row() {
      Text($r('app.string.wallpaper_ui_wallpaper_settings_screen_005'))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.storedOnAccentColor)
    }
    .width(WALLPAPER_CUSTOM_REPLACE_CAPSULE_WIDTH)
    .height(WALLPAPER_CUSTOM_REPLACE_CAPSULE_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.storedAccentColor)
    .borderRadius(WALLPAPER_CUSTOM_REPLACE_CAPSULE_HEIGHT / 2)
    .clip(true)
    .align(this.layoutState.customActionPlacement === 'end' ? Alignment.BottomEnd : Alignment.Bottom)
    .margin({
      right: this.layoutState.customActionPlacement === 'end' ? WALLPAPER_CUSTOM_REPLACE_CAPSULE_END_MARGIN : 0,
      bottom: WALLPAPER_CUSTOM_REPLACE_CAPSULE_BOTTOM_MARGIN
    })
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private buildImageModeSelection(option: WallpaperImageOptionViewState) {
    if (this.layoutState.selectionAxis === 'horizontal') {
      Row({ space: 8 }) {
        this.buildImageModeRadio(option)
        this.buildImageModeTitle(option, TextAlign.Start)
      }
      .width('100%')
      .height(WALLPAPER_IMAGE_SELECTION_HEIGHT)
      .padding({ left: 14, right: 14 })
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .opacity(this.state.mode === 'theme' ? 0.45 : 1)
      .onClick(() => {
        this.selectImageOption(option);
      })
    } else {
      Column({ space: 6 }) {
        this.buildImageModeRadio(option)
        this.buildImageModeTitle(option, TextAlign.Center)
      }
      .width('100%')
      .height(WALLPAPER_IMAGE_SELECTION_HEIGHT)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .opacity(this.state.mode === 'theme' ? 0.45 : 1)
      .onClick(() => {
        this.selectImageOption(option);
      })
    }
  }

  @Builder
  private buildImageModeRadio(option: WallpaperImageOptionViewState) {
    Radio({
      value: option.id,
      group: WALLPAPER_IMAGE_CARD_RADIO_GROUP
    })
      .checked(option.isSelected)
      .enabled(option.isEnabled)
      .hitTestBehavior(HitTestMode.None)
      .radioStyle({
        checkedBackgroundColor: this.storedAccentColor
      })
  }

  @Builder
  private buildImageModeTitle(option: WallpaperImageOptionViewState, textAlign: TextAlign) {
    Text(option.title)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.storedPrimaryTextColor)
      .textAlign(textAlign)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  private buildBingPreviewStatus() {
    Row({ space: 8 }) {
      if (this.state.bingPreviewStatus === 'loading') {
        LoadingProgress()
          .width(18)
          .height(18)
          .color(this.storedAccentColor)
      }

      Text(this.state.bingPreviewStatusText ?? '')
        .fontSize(13)
        .lineHeight(18)
        .fontColor(this.storedSecondaryTextColor)
        .layoutWeight(1)

      if (this.state.bingRetryVisible) {
        Button($r('app.string.settings_sync_retry'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.storedAccentColor)
          .onClick(() => {
            this.onBingRetry();
          })
      }
    }
    .width('100%')
    .padding({ left: 6, right: 6 })
    .alignItems(VerticalAlign.Center)
  }

  private selectImageOption(option: WallpaperImageOptionViewState): void {
    if (!option.isEnabled) {
      return;
    }
    if (option.id === 'video') {
      this.onVideoSelect();
      return;
    }
    if (option.id === 'bing' || option.id === 'custom') {
      this.onModeSelect(option.id);
    }
  }

  private resolvePreviewAccessibilityText(option: WallpaperImageOptionViewState): string {
    if (option.id === 'custom') {
      return option.isEmpty
        ? resolveAppResourceText($r('app.string.wallpaper_ui_wallpaper_settings_screen_009'))
        : resolveAppResourceText($r('app.string.wallpaper_ui_wallpaper_settings_screen_006'));
    }
    if (option.id === 'video') {
      return option.isEmpty
        ? resolveAppResourceText($r('app.string.wallpaper_ui_wallpaper_settings_screen_010'))
        : resolveAppResourceText($r('app.string.wallpaper_ui_wallpaper_settings_screen_007'));
    }
    if (this.state.bingPreviewStatus === 'loading') {
      return resolveAppResourceText($r('app.string.wallpaper_ui_wallpaper_settings_screen_008'));
    }
    if (this.state.bingPreviewStatus === 'error' && option.isEmpty) {
      return resolveAppResourceText($r('app.string.wallpaper_ui_wallpaper_settings_screen_004'));
    }
    return resolveAppResourceText($r('app.string.wallpaper_ui_wallpaper_settings_screen_001'));
  }

  private updateResponsiveLayout(containerWidth: number, containerHeight: number): void {
    if (containerWidth <= 0 || containerHeight <= 0) {
      return;
    }
    const nextState = this.layoutPolicy.resolve({
      containerWidth,
      containerHeight
    });
    if (this.layoutPolicy.buildRenderKey(nextState) === this.layoutPolicy.buildRenderKey(this.layoutState)) {
      return;
    }
    this.layoutState = nextState;
  }

  private parseAreaDimension(value: Length): number {
    const parsed = Number.parseFloat(`${value}`);
    return Number.isFinite(parsed) ? parsed : 0;
  }

}
