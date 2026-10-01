import { promptAction } from '@kit.ArkUI';
import { showCenteredAlertDialog } from '../common/CenteredDialogSurface';
import { HOME_LOGO_BUILTIN_ID, HomeLogoPickSource, HomeLogoSelection } from '../../../common/models/HomeLogoModels';
import { HOME_LOGO_SUPPORTED_FORMATS_TEXT } from '../../../core/settings/HomeLogoImageFormatPolicy';
import {
  buildHomeLogoGridRows,
  buildHomeLogoSettingsViewState,
  formatHomeLogoOpacityLabel,
  formatHomeLogoScaleLabel,
  HOME_LOGO_OPACITY_DEFAULT,
  HOME_LOGO_OPACITY_MAX,
  HOME_LOGO_OPACITY_MIN,
  HOME_LOGO_OPACITY_SLIDER_STEP,
  HOME_LOGO_PREVIEW_HEIGHT_VP,
  resolveHomeLogoCornerRadiusVp,
  HOME_LOGO_SCALE_DEFAULT_RATIO,
  HOME_LOGO_SCALE_MAX_RATIO,
  HOME_LOGO_SCALE_MIN_RATIO,
  HOME_LOGO_SCALE_SLIDER_STEP,
  homeLogoOpacityToSliderValue,
  homeLogoScaleToSliderValue,
  homeLogoSliderValueToOpacity,
  homeLogoSliderValueToScale,
  HomeLogoGridItem,
  HomeLogoGridRow,
  HomeLogoSettingsViewState,
  resolveHomeLogoPreviewMaxWidthVp
} from '../../../core/settings/HomeLogoSettingsPolicy';
import {
  HOME_PAGE_PRESENTATION_HOME_LOGO_OPACITY_KEY,
  HOME_PAGE_PRESENTATION_HOME_LOGO_SCALE_RATIO_KEY
} from '../../../common/constants/HomePagePresentationStorageKeys';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_CONTROL_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_ON_ACCENT_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { HomeLogoAssetImage } from '../browser/HomeLogoMark';
import {
  SettingsFooterText,
  SettingsSection
} from './SettingsLayout';

const HOME_LOGO_CARD_RADIUS: number = 18;
const HOME_LOGO_CARD_WELL_HEIGHT: number = 96;
const HOME_LOGO_SELECTED_BORDER_WIDTH: number = 2;
const HOME_LOGO_SLIDER_HEIGHT: number = 40;
const HOME_LOGO_SLIDER_TRACK_THICKNESS: number = 20;
const HOME_LOGO_SLIDER_TRACK_RADIUS: number = 10;
const HOME_LOGO_SLIDER_BLOCK_SIZE: number = 16;
const HOME_LOGO_DELETE_BUTTON_SIZE: number = 22;

@Component
export struct HomeLogoSettingsContent {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_CONTROL_BACKGROUND_KEY) private storedControlBackgroundColor: string = '#EEF2F6';
  @StorageProp(BROWSER_THEME_STORAGE_ON_ACCENT_KEY) private storedOnAccentColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  @Prop selection: HomeLogoSelection = {
    id: HOME_LOGO_BUILTIN_ID,
    customAssets: []
  };
  @Prop busy: boolean = false;
  @State private containerWidth: number = 360;
  @State private pressedItemId: string = '';
  /** AppStorage carries the live value while dragging; the sheet persists it on release. */
  @StorageProp(HOME_PAGE_PRESENTATION_HOME_LOGO_SCALE_RATIO_KEY)
  private storedScaleRatio: number = HOME_LOGO_SCALE_DEFAULT_RATIO;
  @StorageProp(HOME_PAGE_PRESENTATION_HOME_LOGO_OPACITY_KEY)
  private storedOpacity: number = HOME_LOGO_OPACITY_DEFAULT;
  onSelectLogo: (id: string) => void = (_id: string) => {};
  onAddCustom: (source: HomeLogoPickSource) => void = (_source: HomeLogoPickSource) => {};
  onDeleteCustom: (id: string) => void = (_id: string) => {};
  onScaleCommit: (scaleRatio: number) => void = (_scaleRatio: number) => {};
  onOpacityCommit: (opacity: number) => void = (_opacity: number) => {};

  build() {
    Column({ space: 16 }) {
      this.buildScaleSection()
      this.buildOpacitySection()
      this.buildGridSection()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.updateContainerWidth(newArea.width);
    })
  }

  /** Scales the logo against the shipped wordmark height, capped so it cannot swallow the home. */
  @Builder
  private buildScaleSection() {
    SettingsSection({
      title: $r('app.string.settings_home_logo_size'),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      Column({ space: 8 }) {
        Row() {
          Text($r('app.string.settings_logo_scale_small'))
            .fontSize(12)
            .fontColor(this.storedSecondaryTextColor)
          Blank()
          Text(formatHomeLogoScaleLabel(this.storedScaleRatio))
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.storedPrimaryTextColor)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Slider({
          value: homeLogoScaleToSliderValue(this.storedScaleRatio),
          min: Math.round(HOME_LOGO_SCALE_MIN_RATIO * 100),
          max: Math.round(HOME_LOGO_SCALE_MAX_RATIO * 100),
          step: HOME_LOGO_SCALE_SLIDER_STEP,
          style: SliderStyle.InSet
        })
          .width('100%')
          .height(HOME_LOGO_SLIDER_HEIGHT)
          .selectedColor(this.storedAccentColor)
          .blockColor(this.storedOnAccentColor)
          .trackColor(this.storedControlBackgroundColor)
          .trackThickness(HOME_LOGO_SLIDER_TRACK_THICKNESS)
          .trackBorderRadius(HOME_LOGO_SLIDER_TRACK_RADIUS)
          .selectedBorderRadius(HOME_LOGO_SLIDER_TRACK_RADIUS)
          .blockSize({ width: HOME_LOGO_SLIDER_BLOCK_SIZE, height: HOME_LOGO_SLIDER_BLOCK_SIZE })
          .onChange((value: number, mode: SliderChangeMode) => {
            const ratio = homeLogoSliderValueToScale(value);
            // Live resize, but only write settings once the finger leaves the slider.
            AppStorage.setOrCreate(HOME_PAGE_PRESENTATION_HOME_LOGO_SCALE_RATIO_KEY, ratio);
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              this.onScaleCommit(ratio);
            }
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 10 })
      .backgroundColor(this.storedControlBackgroundColor)
      .borderRadius(HOME_LOGO_CARD_RADIUS)
    }
  }

  /** Same card as size. 0 hides the mark; 100% is the solid wordmark. */
  @Builder
  private buildOpacitySection() {
    SettingsSection({
      title: $r('app.string.settings_home_logo_opacity'),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      Column({ space: 8 }) {
        Row() {
          Text($r('app.string.settings_logo_opacity_clear'))
            .fontSize(12)
            .fontColor(this.storedSecondaryTextColor)
          Blank()
          Text(formatHomeLogoOpacityLabel(this.storedOpacity))
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.storedPrimaryTextColor)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Slider({
          value: homeLogoOpacityToSliderValue(this.storedOpacity),
          min: Math.round(HOME_LOGO_OPACITY_MIN * 100),
          max: Math.round(HOME_LOGO_OPACITY_MAX * 100),
          step: HOME_LOGO_OPACITY_SLIDER_STEP,
          style: SliderStyle.InSet
        })
          .width('100%')
          .height(HOME_LOGO_SLIDER_HEIGHT)
          .selectedColor(this.storedAccentColor)
          .blockColor(this.storedOnAccentColor)
          .trackColor(this.storedControlBackgroundColor)
          .trackThickness(HOME_LOGO_SLIDER_TRACK_THICKNESS)
          .trackBorderRadius(HOME_LOGO_SLIDER_TRACK_RADIUS)
          .selectedBorderRadius(HOME_LOGO_SLIDER_TRACK_RADIUS)
          .blockSize({ width: HOME_LOGO_SLIDER_BLOCK_SIZE, height: HOME_LOGO_SLIDER_BLOCK_SIZE })
          .onChange((value: number, mode: SliderChangeMode) => {
            const opacity = homeLogoSliderValueToOpacity(value);
            AppStorage.setOrCreate(HOME_PAGE_PRESENTATION_HOME_LOGO_OPACITY_KEY, opacity);
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              this.onOpacityCommit(opacity);
            }
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 10 })
      .backgroundColor(this.storedControlBackgroundColor)
      .borderRadius(HOME_LOGO_CARD_RADIUS)
    }
  }

  /** Presets, then the user's images, then one trailing add tile that never selects. */
  @Builder
  private buildGridSection() {
    SettingsSection({
      title: $r('app.string.settings_home_logo_choose'),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      Column({ space: this.viewState().columnGap }) {
        ForEach(this.gridRows(), (row: HomeLogoGridRow) => {
          Row({ space: this.viewState().columnGap }) {
            ForEach(row.items, (item: HomeLogoGridItem) => {
              this.buildGridTile(item)
            }, (item: HomeLogoGridItem) => `${item.kind}:${item.id}:${item.selected ? '1' : '0'}`)

            ForEach(this.placeholderKeys(row), (key: string) => {
              Column()
                .layoutWeight(1)
                .height(1)
                .hitTestBehavior(HitTestMode.None)
            }, (key: string) => key)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }, (row: HomeLogoGridRow) => row.key)
      }
      .width('100%')

      SettingsFooterText({
        text: `${HOME_LOGO_SUPPORTED_FORMATS_TEXT}。图片按固定高度显示，宽度随原图比例变化。`,
        secondaryTextColor: this.storedSecondaryTextColor
      })
    }
  }

  @Builder
  private buildGridTile(item: HomeLogoGridItem) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (item.kind === 'add') {
          if (this.busy) {
            LoadingProgress()
              .width(24)
              .height(24)
              .color(this.storedAccentColor)
          } else {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize(30)
              .fontWeight(FontWeight.Medium)
              .fontColor([this.storedSecondaryTextColor])
          }
        } else {
          HomeLogoAssetImage({
            fileUri: item.fileUri,
            rawfileName: item.rawfileName,
            intrinsicWidth: item.intrinsicWidth,
            intrinsicHeight: item.intrinsicHeight,
            heightVp: HOME_LOGO_PREVIEW_HEIGHT_VP,
            maxWidthVp: this.previewMaxWidth(),
            colorMode: item.colorMode,
            cornerRadiusVp: resolveHomeLogoCornerRadiusVp(HOME_LOGO_PREVIEW_HEIGHT_VP, item.shape),
            tintColor: this.storedPrimaryTextColor
          })
        }
        if (item.kind === 'custom') {
          this.buildDeleteButton(item)
        }
      }
      .width('100%')
      .height(HOME_LOGO_CARD_WELL_HEIGHT)
      .backgroundColor(this.storedControlBackgroundColor)
      .borderRadius(HOME_LOGO_CARD_RADIUS)
      .border({
        width: HOME_LOGO_SELECTED_BORDER_WIDTH,
        color: item.selected ? this.storedAccentColor : Color.Transparent
      })
      .clip(true)

      // The add tile keeps an empty label line so every well in the row lines up.
      Text(item.title)
        .width('100%')
        .fontSize(13)
        .fontWeight(item.selected ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.storedPrimaryTextColor)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .enabled(!this.busy)
    .opacity(this.resolveTileOpacity(item))
    .accessibilityText(this.resolveTileAccessibilityText(item))
    .onTouch((event: TouchEvent) => {
      this.updateTilePress(item, event);
    })
    .onClick(() => {
      this.activateTile(item);
    })
  }

  /** Only an imported tile can be removed. The badge sits in the well corner and does not select. */
  @Builder
  private buildDeleteButton(item: HomeLogoGridItem) {
    Button({
      type: ButtonType.Circle
    }) {
      SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
        .fontSize(18)
        .fontColor([this.storedSecondaryTextColor])
    }
    .width(HOME_LOGO_DELETE_BUTTON_SIZE)
    .height(HOME_LOGO_DELETE_BUTTON_SIZE)
    .backgroundColor(Color.Transparent)
    .align(Alignment.TopEnd)
    .margin({ top: 4, right: 4 })
    .accessibilityText($r('app.string.settings_home_logo_delete_a11y', item.title))
    .onTouch((event: TouchEvent) => {
      event.stopPropagation();
    })
    .onClick(() => {
      this.confirmDeleteCustom(item);
    })
  }

  private confirmDeleteCustom(item: HomeLogoGridItem): void {
    if (this.busy || item.kind !== 'custom') {
      return;
    }
    showCenteredAlertDialog({
      title: $r('app.string.settings_home_logo_delete_title'),
      message: $r('app.string.settings_home_logo_delete_message', item.title),
      autoCancel: true,
      primaryButton: {
        value: $r('app.string.settings_home_logo_delete_cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.settings_home_logo_delete'),
        fontColor: $r('sys.color.ohos_id_color_warning'),
        action: () => {
          this.onDeleteCustom(item.id);
        }
      }
    });
  }

  private activateTile(item: HomeLogoGridItem): void {
    if (this.busy) {
      return;
    }
    if (item.kind === 'add') {
      this.openUploadSourceMenu();
      return;
    }
    this.onSelectLogo(item.id);
  }

  /** Touch feedback so a tap on the tile is visibly acknowledged before the selection lands. */
  private updateTilePress(item: HomeLogoGridItem, event: TouchEvent): void {
    if (this.busy) {
      return;
    }
    if (event.type === TouchType.Down) {
      this.pressedItemId = item.id;
      return;
    }
    if ((event.type === TouchType.Up || event.type === TouchType.Cancel) &&
      this.pressedItemId === item.id) {
      this.pressedItemId = '';
    }
  }

  private resolveTileOpacity(item: HomeLogoGridItem): number {
    if (this.busy) {
      return 0.48;
    }
    return this.pressedItemId === item.id ? 0.55 : 1;
  }

  private resolveTileAccessibilityText(item: HomeLogoGridItem): string {
    if (item.kind === 'add') {
      return '添加自定义 Logo';
    }
    return item.selected ? `${item.title}，已选中` : item.title;
  }

  /** Gallery for ordinary photos, files for SVG and anything the gallery never carries. */
  private openUploadSourceMenu(): void {
    if (this.busy) {
      return;
    }
    try {
      this.getUIContext().getPromptAction().showActionMenu({
        title: $r('app.string.settings_home_logo_source'),
        buttons: [
          { text: $r('app.string.settings_home_logo_from_photos'), color: this.storedPrimaryTextColor },
          { text: $r('app.string.settings_home_logo_from_files'), color: this.storedPrimaryTextColor }
        ]
      })
        .then((result: promptAction.ActionMenuSuccessResponse) => {
          if (result.index === 0) {
            this.onAddCustom('photos');
          } else if (result.index === 1) {
            this.onAddCustom('files');
          }
        })
        .catch((_error: Error) => {});
    } catch (_error) {
    }
  }

  private viewState(): HomeLogoSettingsViewState {
    return buildHomeLogoSettingsViewState(this.selection, this.containerWidth);
  }

  private gridRows(): HomeLogoGridRow[] {
    const state = this.viewState();
    return buildHomeLogoGridRows(state.items, state.columns);
  }

  private previewMaxWidth(): number {
    const state = this.viewState();
    return resolveHomeLogoPreviewMaxWidthVp(this.containerWidth, state.columns, state.columnGap);
  }

  private placeholderKeys(row: HomeLogoGridRow): string[] {
    const keys: string[] = [];
    for (let index = 0; index < row.placeholderCount; index += 1) {
      keys.push(`${row.key}-pad-${index}`);
    }
    return keys;
  }

  private updateContainerWidth(width: Length): void {
    const parsed = Number.parseFloat(`${width}`);
    if (!Number.isFinite(parsed) || parsed <= 0) {
      return;
    }
    const next = Math.ceil(parsed);
    if (next !== this.containerWidth) {
      this.containerWidth = next;
    }
  }
}
