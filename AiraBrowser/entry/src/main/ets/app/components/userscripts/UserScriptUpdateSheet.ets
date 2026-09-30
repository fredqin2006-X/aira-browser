import { DEFAULT_THEME_PALETTE } from '../../../features/theme/palettes/DefaultThemePalette';
import {
  DESKTOP_DIALOG_PADDING_VP,
  DESKTOP_DIALOG_TITLE_FONT_SIZE_FP
} from '../../../core/browser/BrowserDialogPresentationTokens';
import { UserScriptUpdateResult } from '../../../services/userscripts/UserScriptUpdateService';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_DIVIDER_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import {
  BROWSER_IMMERSIVE_SHEET_HEADER_CONTENT_TOP_INSET,
  BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING,
  BROWSER_SHEET_IMMERSIVE_FOOTER_CLEARANCE,
  resolveBrowserSheetHeaderBlurRadius,
  BrowserBottomSheetSurface,
  BrowserFeatureSheetHeader,
  BrowserImmersiveSheetLayout,
  BrowserSheetActionButton,
  browserSheetHeaderBlurModifier
} from '../browser/BrowserModalBottomSheet';
import { AiraIcon } from '../common/AiraIcon';
import {
  SettingsGroupCard,
  SettingsGroupDivider
} from '../settings/SettingsLayout';

const USER_SCRIPT_UPDATE_SHEET_MAX_WIDTH: number = 540;
const USER_SCRIPT_UPDATE_RESULTS_MAX_HEIGHT: number = 360;

@Component
export struct UserScriptUpdateSheet {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY) private storedDividerColor: string = '#E3E8EF';
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = DEFAULT_THEME_PALETTE.light.pageBackground;
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private storedSurfaceBackgroundColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  @Prop results: UserScriptUpdateResult[] = [];
  @Prop checking: boolean = false;
  @Prop updating: boolean = false;
  @Prop fillAvailableHeight: boolean = false;
  @Prop layoutMode: 'phone' | 'large_screen' = 'phone';
  onUpdateSelected: () => void = () => {};
  onClose: () => void = () => {};
  @State private sheetHeaderBlurRadius: number = 0;
  @State private sheetScrollOffset: number = 0;

  build() {
    BrowserBottomSheetSurface({
      maxWidth: USER_SCRIPT_UPDATE_SHEET_MAX_WIDTH,
      surfaceColor: this.storedPageBackgroundColor,
      fullHeight: this.layoutMode === 'phone' || this.fillAvailableHeight,
      presentation: this.layoutMode === 'large_screen' ? 'flat_content' : 'bottom_sheet',
      horizontalPadding: this.layoutMode === 'phone' ? 0 : DESKTOP_DIALOG_PADDING_VP,
      topPadding: this.layoutMode === 'phone' ? 0 : DESKTOP_DIALOG_PADDING_VP,
      bottomPadding: this.layoutMode === 'phone' ? 0 : DESKTOP_DIALOG_PADDING_VP
    }) {
      if (this.layoutMode === 'phone') {
        this.buildImmersivePhoneLayout()
      } else {
        this.buildLargeScreenLayout()
      }
    }
  }

  @Builder
  private buildImmersivePhoneLayout() {
    BrowserImmersiveSheetLayout({
      footerVisible: this.availableCount() > 0,
            closeVisible: true,
      closeAccessibilityLabel: $r('app.string.user_script_close_update_check'),
      onClose: (): void => {
        this.onClose();
      },
      scrollContent: () => {
        this.buildPhoneScrollContent()
      },
      header: () => {
        this.buildPhoneHeader()
      },
      footer: () => {
        this.buildUpdateButton()
      }
    })
  }

  @Builder
  private buildPhoneScrollContent() {
    Scroll(this.sheetBlurScroller) {
      Column({ space: 18 }) {
        Text(this.buildSummary())
          .width('100%')
          .fontSize(14)
          .lineHeight(20)
          .fontColor(this.storedSecondaryTextColor)

        this.buildStateCard(false)
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({
        left: 16,
        right: 16,
        top: BROWSER_IMMERSIVE_SHEET_HEADER_CONTENT_TOP_INSET,
        bottom: this.availableCount() > 0
          ? BROWSER_SHEET_IMMERSIVE_FOOTER_CLEARANCE
          : BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .clip(false)
    .attributeModifier(browserSheetHeaderBlurModifier(this.sheetHeaderBlurRadius))
    .onAppear(() => {
      this.resetSheetHeaderBlur();
    })
    .onDidScroll((_xOffset: number, yOffset: number) => {
      this.noteSheetScrollOffset(this.sheetBlurScroller.currentOffset().yOffset);
    })
  }

  @Builder
  private buildPhoneHeader() {
    BrowserFeatureSheetHeader({
      title: $r('app.string.user_script_update_check_title'),
      titleColor: this.storedPrimaryTextColor
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
  private buildLargeScreenLayout() {
    Column({ space: 18 }) {
      Column({ space: 6 }) {
        Text($r('app.string.user_script_update_check_title'))
          .width('100%')
          .fontSize(DESKTOP_DIALOG_TITLE_FONT_SIZE_FP)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.storedPrimaryTextColor)

        Text(this.buildSummary())
          .width('100%')
          .fontSize(14)
          .lineHeight(20)
          .fontColor(this.storedSecondaryTextColor)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column() {
        this.buildStateCard(true)
      }
      .width('100%')
      .layoutWeight(this.fillAvailableHeight ? 1 : 0)

      Column({ space: 8 }) {
        if (this.availableCount() > 0) {
          this.buildUpdateButton()
        }

        BrowserSheetActionButton({
          label: $r('app.string.user_script_action_close'),
          emphasis: 'ghost',
          stacked: true,
          actionEnabled: !this.updating,
          onAction: () => {
            this.onClose();
          }
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height(this.fillAvailableHeight ? '100%' : '')
  }

  @Builder
  private buildUpdateButton() {
    BrowserSheetActionButton({
      label: this.updating
        ? $r('app.string.user_script_updating')
        : $r('app.string.user_script_update_count', this.availableCount()),
      emphasis: 'primary',
      stacked: true,
      actionEnabled: !this.checking && !this.updating,
      accentColor: this.storedAccentColor,
      onAction: () => {
        this.onUpdateSelected();
      }
    })
  }

  @Builder
  private buildStateCard(useInternalScroll: boolean) {
    SettingsGroupCard({
      surfaceColor: this.storedSurfaceBackgroundColor,
      fullHeight: useInternalScroll && this.fillAvailableHeight
    }) {
      if (this.checking) {
        this.buildLoadingState()
      } else if (this.results.length <= 0) {
        this.buildEmptyState()
      } else if (useInternalScroll) {
        Scroll() {
          this.buildResults()
        }
        .width('100%')
        .height(this.fillAvailableHeight ? '100%' : '')
        .constraintSize({
          maxHeight: this.fillAvailableHeight ? '100%' : USER_SCRIPT_UPDATE_RESULTS_MAX_HEIGHT
        })
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
      } else {
        this.buildResults()
      }
    }
  }

  @Builder
  private buildResults() {
    Column({ space: 0 }) {
      ForEach(this.results, (result: UserScriptUpdateResult, index: number) => {
        this.buildResultRow(result)
        if (index < this.results.length - 1) {
          SettingsGroupDivider({ dividerColor: this.storedDividerColor })
        }
      }, (result: UserScriptUpdateResult) => result.scriptId)
    }
    .width('100%')
  }

  @Builder
  private buildLoadingState() {
    Row({ space: 12 }) {
      LoadingProgress()
        .width(28)
        .height(28)
        .color(this.storedAccentColor)

      Text($r('app.string.user_script_checking_updates'))
        .layoutWeight(1)
        .fontSize(16)
        .fontColor(this.storedPrimaryTextColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(this.fillAvailableHeight ? '100%' : '')
    .padding({ left: 12, right: 12, top: 16, bottom: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildEmptyState() {
    Row({ space: 12 }) {
      AiraIcon({
        airaIconId: 'settings.userScripts',
        iconSize: 26,
        iconColor: this.storedSecondaryTextColor
      })

      Text($r('app.string.user_script_no_updatable_scripts'))
        .layoutWeight(1)
        .fontSize(16)
        .fontColor(this.storedPrimaryTextColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(this.fillAvailableHeight ? '100%' : '')
    .padding({ left: 12, right: 12, top: 16, bottom: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildResultRow(result: UserScriptUpdateResult) {
    Row({ space: 12 }) {
      Column({ space: 5 }) {
        Text(result.scriptName.length > 0 ? result.scriptName : result.scriptId)
          .width('100%')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.storedPrimaryTextColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.resultMessage(result))
          .width('100%')
          .fontSize(13)
          .lineHeight(18)
          .fontColor(this.storedSecondaryTextColor)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.statusLabel(result))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(result.status === 'available' ? this.storedAccentColor : this.storedSecondaryTextColor)
        .maxLines(1)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 13, bottom: 13 })
    .alignItems(VerticalAlign.Center)
  }

  private availableCount(): number {
    return this.results.filter((result: UserScriptUpdateResult) => result.status === 'available').length;
  }

  private failedCount(): number {
    return this.results.filter((result: UserScriptUpdateResult) => result.status === 'failed').length;
  }

  private buildSummary(): ResourceStr {
    if (this.checking) {
      return $r('app.string.user_script_update_summary_reading');
    }
    if (this.updating) {
      return $r('app.string.user_script_update_summary_installing');
    }
    if (this.results.length <= 0) {
      return $r('app.string.user_script_update_summary_none');
    }
    const available = this.availableCount();
    if (available > 0) {
      return $r('app.string.user_script_update_summary_available', available);
    }
    const failed = this.failedCount();
    if (failed > 0) {
      return $r('app.string.user_script_update_summary_failed', failed);
    }
    return $r('app.string.user_script_update_summary_all_latest');
  }

  private statusLabel(result: UserScriptUpdateResult): ResourceStr {
    if (result.status === 'available') {
      return $r('app.string.user_script_status_available');
    }
    if (result.status === 'up-to-date') {
      return $r('app.string.user_script_status_up_to_date');
    }
    if (result.status === 'failed') {
      return $r('app.string.user_script_status_failed');
    }
    return $r('app.string.user_script_status_unsupported');
  }

  private resultMessage(result: UserScriptUpdateResult): string {
    if (result.status === 'available') {
      return `${result.previousVersion} -> ${result.nextVersion}`;
    }
    return result.message;
  }
}
