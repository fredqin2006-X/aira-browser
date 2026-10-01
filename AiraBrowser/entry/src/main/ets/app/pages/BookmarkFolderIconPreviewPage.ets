import { DEFAULT_THEME_PALETTE } from '../../features/theme/palettes/DefaultThemePalette';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_CONTROL_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../core/theme/BrowserThemeStorageKeys';
import { BookmarkFolderIcon } from '../components/bookmarks/BookmarkFolderIcon';
import { SettingsHdsScaffold } from '../components/settings/SettingsHdsScaffold';
import {
  SettingsGroupCard,
  SettingsScrollBody,
  SettingsSection
} from '../components/settings/SettingsLayout';
import { SettingsActionButton } from '../components/settings/SettingsRows';
import { SettingsNavigationCoordinator } from '../router/SettingsNavigationCoordinator';

@Entry
@Component
struct BookmarkFolderIconPreviewPage {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_CONTROL_BACKGROUND_KEY) private storedControlBackgroundColor: string = '#EEF2F6';
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = DEFAULT_THEME_PALETTE.light.pageBackground;
  @StorageProp(BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY) private storedPressedBackgroundColor: string = '#DDE4EC';
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private storedSurfaceBackgroundColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  @State private previewRevision: number = 0;
  private navigationCoordinator: SettingsNavigationCoordinator = new SettingsNavigationCoordinator();

  build() {
    Column() {
      SettingsHdsScaffold({
        title: $r('app.string.bookmark_icon_preview_001'),
        backIconKind: 'back',
        pageBackground: this.storedPageBackgroundColor,
        headerButtonBackground: this.storedPressedBackgroundColor,
        primaryTextColor: this.storedPrimaryTextColor,
        contentKind: 'canvas',
        onBack: () => {
          this.navigationCoordinator.back();
        }
      }) {
        SettingsScrollBody({
          contentSpace: 16,
          topPadding: 16,
          bottomPadding: 26
        }) {
          this.buildPreviewSection()
          this.buildThemeColorSection()
          SettingsActionButton({
            title: $r('app.string.bookmark_icon_preview_007'),
            accentColor: this.storedAccentColor,
            onAction: () => {
              this.previewRevision += 1;
            }
          })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.storedPageBackgroundColor)
  }

  @Builder
  private buildPreviewSection() {
    SettingsSection({
      title: $r('app.string.user_script_runtime_status'),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
        Row({ space: 18 }) {
          this.buildPreviewItem($r('app.string.bookmark_icon_preview_003'), false, false, 0)
          this.buildPreviewItem($r('app.string.bookmark_icon_preview_002'), true, false, 1)
          this.buildPreviewItem($r('app.string.bookmark_icon_preview_006'), true, true, this.previewRevision)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 12, right: 12, top: 22, bottom: 18 })
      }
    }
  }

  @Builder
  private buildThemeColorSection() {
    SettingsSection({
      title: $r('app.string.settings_appearance_theme_color'),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
        Row({ space: 18 }) {
          this.buildTintedPreview($r('app.string.bookmark_icon_preview_005'), '', '')
          this.buildTintedPreview($r('app.string.bookmark_icon_preview_004'), '#FF9428', '#FFCA28')
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 12, right: 12, top: 22, bottom: 18 })
      }
    }
  }

  @Builder
  private buildPreviewItem(label: ResourceStr, hasContent: boolean, animatePaper: boolean, key: number) {
    Column({ space: 12 }) {
      Stack() {
        BookmarkFolderIcon({
          widthVp: 92,
          hasContent: hasContent,
          animatePaper: animatePaper,
          playbackKey: key
        })
      }
      .width(116)
      .height(88)
      .borderRadius(20)
      .backgroundColor(this.storedControlBackgroundColor)
      .id(`${label}-${key}`)

      Text(label)
        .fontSize(14)
        .lineHeight(20)
        .fontColor(this.storedSecondaryTextColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildTintedPreview(label: ResourceStr, backColor: ResourceColor, frontColor: ResourceColor) {
    Column({ space: 12 }) {
      Stack() {
        BookmarkFolderIcon({
          widthVp: 92,
          hasContent: true,
          animatePaper: false,
          backColor: backColor,
          frontColor: frontColor
        })
      }
      .width(116)
      .height(88)
      .borderRadius(20)
      .backgroundColor(this.storedControlBackgroundColor)

      Text(label)
        .fontSize(14)
        .lineHeight(20)
        .fontColor(this.storedSecondaryTextColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }
}
