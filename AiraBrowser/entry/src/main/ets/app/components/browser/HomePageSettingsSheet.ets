import { display } from '@kit.ArkUI';
import { resolveAppResourceText } from '../../../core/resources/AppResourceText';
import { DEFAULT_THEME_PALETTE } from '../../../features/theme/palettes/DefaultThemePalette';
import { desktopDialogTierSpec } from '../../../core/browser/BrowserDialogPresentationTokens';
import {
  BROWSER_THEME_STORAGE_FLOATING_SURFACE_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { WallpaperMode } from '../../../common/models/WallpaperModels';
import { WallpaperSettingsCoordinator } from '../../../core/wallpaper/WallpaperSettingsCoordinator';
import { WallpaperSettingsViewState } from '../../../core/wallpaper/WallpaperSettingsViewModel';
import {
  HOME_LOGO_BUILTIN_ID,
  HomeLogoPickSource,
  HomeLogoSelection,
  resolveHomeLogoRowLabel
} from '../../../common/models/HomeLogoModels';
import {
  HOME_PAGE_PRESENTATION_HOME_LOGO_OPACITY_KEY,
  HOME_PAGE_PRESENTATION_HOME_LOGO_SCALE_RATIO_KEY
} from '../../../common/constants/HomePagePresentationStorageKeys';
import { HomeLogoSettingsCoordinator } from '../../../core/settings/HomeLogoSettingsCoordinator';
import {
  sharedHomePagePresentationSettingsRepository,
  sharedWallpaperRepository
} from '../../bootstrap/BrowserAppRuntime';
import { HomeNativeSettingsContent } from '../settings/HomeNativeSettingsContent';
import { HomeLogoSettingsContent } from '../settings/HomeLogoSettingsScreen';
import { WallpaperSettingsContent } from '../wallpaper/WallpaperSettingsScreen';
import {
  BROWSER_FEATURE_SHEET_HEADER_BUTTON_SIZE,
  BROWSER_FEATURE_SHEET_HEADER_ICON_SIZE,
  BROWSER_IMMERSIVE_SHEET_HEADER_CONTENT_TOP_INSET,
  BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING,
  BROWSER_SHEET_MODAL_HEADER_BUTTON_TOP,
  BROWSER_SHEET_MODAL_TOP_PADDING,
  BrowserBottomSheetSurface,
  BrowserSheetIconButton,
  browserSheetHeaderBlurModifier,
  resolveBrowserSheetHeaderBlurRadius
} from './BrowserModalBottomSheet';
import { BrowserLargeScreenModalHeader } from './BrowserLargeScreenModalHeader';
import { BrowserPhoneSettingsSheetHeader } from './BrowserPhoneSettingsSheetHeader';
import { CENTERED_DIALOG_SYSTEM_HUG_DEFINITE_SURFACE_MODIFIER } from '../common/CenteredDialogSurface';

export type HomePageSettingsLayoutMode = 'phone' | 'large_screen';
type HomePageSettingsSheetPage = 'main' | 'wallpaper' | 'logo';
const HOME_PAGE_SHEET_POP_GUARD_MS: number = 450;
const HOME_SETTINGS_HEADER_ALLOWANCE_VP: number = 72;
const HOME_SETTINGS_PHONE_CHROME_VP: number = 96;
const HOME_SETTINGS_DIALOG_EDGE_VP: number = 48;
const HOME_SETTINGS_SCROLL_MIN_HEIGHT_VP: number = 280;
const HOME_PAGE_PHONE_SCROLL_TOP_PADDING_VP: number = 4;
/**
 * Phone title overlays the scroller. Grow the viewport by the inset that
 * replaced the old gap, so the area under the title stays the same size.
 */
const HOME_PAGE_PHONE_HEADER_VIEWPORT_EXTRA_VP: number =
  BROWSER_IMMERSIVE_SHEET_HEADER_CONTENT_TOP_INSET - HOME_PAGE_PHONE_SCROLL_TOP_PADDING_VP;

function readWindowHeightVp(): number {
  try {
    const metrics = display.getDefaultDisplaySync();
    if (!Number.isFinite(metrics.height) || metrics.height <= 0 ||
      !Number.isFinite(metrics.densityPixels) || metrics.densityPixels <= 0) {
      return 0;
    }
    return metrics.height / metrics.densityPixels;
  } catch (_error) {
    return 0;
  }
}

/** Scroll cap so a short settings page hugs its rows, while wallpaper can still scroll. */
export function resolveHomeSettingsScrollMaxHeightVp(layoutMode: HomePageSettingsLayoutMode): number {
  const windowHeight = readWindowHeightVp();
  if (layoutMode === 'large_screen') {
    const dialogCap = desktopDialogTierSpec('m').maxHeightVp;
    const usable = windowHeight > 0 ?
      Math.min(dialogCap, windowHeight - HOME_SETTINGS_DIALOG_EDGE_VP) : dialogCap;
    return Math.max(HOME_SETTINGS_SCROLL_MIN_HEIGHT_VP, usable - HOME_SETTINGS_HEADER_ALLOWANCE_VP);
  }
  const usable = windowHeight > 0 ? windowHeight - HOME_SETTINGS_PHONE_CHROME_VP : 640;
  return Math.max(HOME_SETTINGS_SCROLL_MIN_HEIGHT_VP, usable - HOME_SETTINGS_HEADER_ALLOWANCE_VP);
}

export function resolveHomeSettingsDialogMaxHeightVp(): number {
  return resolveHomeSettingsScrollMaxHeightVp('large_screen') + HOME_SETTINGS_HEADER_ALLOWANCE_VP;
}

/**
 * The system sheet and the large-screen dialog both receive back before the
 * page inside them. This lets that outer dismiss pop the wallpaper page first.
 */
class HomePageSettingsSheetNavigation {
  private consumeBack: (() => boolean) | undefined = undefined;

  bind(consumeBack: () => boolean): void {
    this.consumeBack = consumeBack;
  }

  unbind(consumeBack: () => boolean): void {
    if (this.consumeBack === consumeBack) {
      this.consumeBack = undefined;
    }
  }

  tryConsumeBack(): boolean {
    if (this.consumeBack === undefined) {
      return false;
    }
    return this.consumeBack();
  }
}

export const homePageSettingsSheetNavigation: HomePageSettingsSheetNavigation =
  new HomePageSettingsSheetNavigation();

@Component
export struct HomePageSettingsSheet {
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = DEFAULT_THEME_PALETTE.light.pageBackground;
  @Prop privateModeVisible: boolean = false;
  onWallpaperChanged: () => void = () => {};
  onClose: () => void = () => {};

  build() {
    BrowserBottomSheetSurface({
      fullHeight: false,
      horizontalPadding: 0,
      topPadding: 0,
      bottomPadding: 0,
      surfaceColor: this.storedPageBackgroundColor
    }) {
      HomePageSettingsContent({
        privateModeVisible: this.privateModeVisible,
        layoutMode: 'phone',
        onWallpaperChanged: this.onWallpaperChanged,
        onClose: this.onClose
      })
    }
  }
}

@CustomDialog
export struct HomePageSettingsDialog {
  controller?: CustomDialogController;
  @Link privateModeVisible: boolean;
  onWallpaperChanged: () => void = () => {};
  onClose: () => void = () => {};

  build() {
    Column() {
      HomePageSettingsContent({
        privateModeVisible: this.privateModeVisible,
        layoutMode: 'large_screen',
        onWallpaperChanged: this.onWallpaperChanged,
        onClose: this.onClose
      })
    }
    .width('100%')
    .attributeModifier(CENTERED_DIALOG_SYSTEM_HUG_DEFINITE_SURFACE_MODIFIER)
    .constraintSize({ maxHeight: resolveHomeSettingsDialogMaxHeightVp() })
  }
}

@Component
export struct HomePageSettingsContent {
  private wallpaperCoordinator: WallpaperSettingsCoordinator =
    new WallpaperSettingsCoordinator(sharedWallpaperRepository);
  private logoCoordinator: HomeLogoSettingsCoordinator =
    new HomeLogoSettingsCoordinator(sharedHomePagePresentationSettingsRepository);
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = DEFAULT_THEME_PALETTE.light.pageBackground;
  @StorageProp(BROWSER_THEME_STORAGE_FLOATING_SURFACE_KEY) private storedFloatingSurfaceColor: string = '#FFFFFF';
  @Prop privateModeVisible: boolean = false;
  @Prop layoutMode: HomePageSettingsLayoutMode = 'phone';
  onWallpaperChanged: () => void = () => {};
  onClose: () => void = () => {};
  @State private wallpaperState: WallpaperSettingsViewState = this.wallpaperCoordinator.getCurrentState();
  @State private logoSelection: HomeLogoSelection = {
    id: HOME_LOGO_BUILTIN_ID,
    customAssets: []
  };
  @State private logoBusy: boolean = false;
  @State private sheetPage: HomePageSettingsSheetPage = 'main';
  @State private contentMaxHeightVp: number = HOME_SETTINGS_SCROLL_MIN_HEIGHT_VP;
  @State private mainBodyHeightVp: number = 0;
  @State private wallpaperBodyHeightVp: number = 0;
  @State private logoBodyHeightVp: number = 0;
  @State private sheetHeaderBlurRadius: number = 0;
  @State private sheetScrollOffset: number = 0;
  private mainSheetScroller: Scroller = new Scroller();
  private wallpaperSheetScroller: Scroller = new Scroller();
  private logoSheetScroller: Scroller = new Scroller();
  private sheetNavigationPopGuardUntilMs: number = 0;
  private readonly consumeSheetBack: () => boolean = (): boolean => this.popSheetNavigation();

  aboutToAppear(): void {
    this.contentMaxHeightVp = resolveHomeSettingsScrollMaxHeightVp(this.layoutMode);
    this.refreshWallpaperState();
    this.refreshLogoSelection();
    homePageSettingsSheetNavigation.bind(this.consumeSheetBack);
  }

  aboutToDisappear(): void {
    homePageSettingsSheetNavigation.unbind(this.consumeSheetBack);
    this.resetSheetNavigation();
  }

  build() {
    if (this.layoutMode === 'large_screen') {
      this.buildLargeScreenPage()
    } else {
      this.buildPhonePage()
    }
  }

  @Builder
  private buildLargeScreenPage() {
    Column({ space: 0 }) {
      BrowserLargeScreenModalHeader({
        title: this.resolveSheetTitle(),
        dialogMode: true,
        showBackButton: this.sheetPage !== 'main',
        onBack: (): void => {
          this.popSheetNavigation();
        },
        onClose: this.onClose
      })

      if (this.sheetPage === 'wallpaper') {
        this.buildWallpaperScroll()
      } else if (this.sheetPage === 'logo') {
        this.buildLogoScroll()
      } else {
        this.buildMainScroll()
      }
    }
    .width('100%')
    .backgroundColor(this.resolveSheetNavigationBackground())
    .clip(true)
  }

  @Builder
  private buildPhonePage() {
    // Title overlays the scroller so content can scroll under a progressive top blur.
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 0 }) {
        if (this.sheetPage === 'wallpaper') {
          this.buildWallpaperScroll()
        } else if (this.sheetPage === 'logo') {
          this.buildLogoScroll()
        } else {
          this.buildMainScroll()
        }
      }
      .width('100%')

      this.buildPhoneHeaderOverlay()
      this.buildPhoneCloseButton()
    }
    .width('100%')
    .backgroundColor(this.resolveSheetNavigationBackground())
  }

  @Builder
  private buildPhoneHeaderOverlay() {
    Column() {
      this.buildPhoneHeader()
    }
    .width('100%')
    .padding({ top: BROWSER_SHEET_MODAL_TOP_PADDING })
    .zIndex(2)
  }

  @Builder
  private buildPhoneCloseButton() {
    BrowserSheetIconButton({
      icon: $r('sys.symbol.xmark'),
      iconSize: BROWSER_FEATURE_SHEET_HEADER_ICON_SIZE,
      buttonSize: BROWSER_FEATURE_SHEET_HEADER_BUTTON_SIZE,
      accessibilityLabel: $r('app.string.browser_ui_home_page_settings_sheet_002'),
      immersiveMaterialEnabled: true,
      onAction: (): void => {
        this.onClose();
      }
    })
    .margin({ top: BROWSER_SHEET_MODAL_HEADER_BUTTON_TOP, right: 16 })
    .zIndex(3)
  }

  /**
   * Wallpaper uses a definite height. The short centered and minimal sheets are
   * FIT_CONTENT, and clearing the scroll height collapses the next page.
   */
  @Builder
  private buildMainScroll() {
    Scroll(this.mainSheetScroller) {
      Column({ space: 16 }) {
        HomeNativeSettingsContent({
          isEnabled: true,
          iconAppearanceEnabled: !this.privateModeVisible,
          wallpaperLabel: this.wallpaperState.modeTitle,
          logoLabel: resolveHomeLogoRowLabel(this.logoSelection),
          dialogPresentation: this.layoutMode === 'large_screen',
          onOpenLogoSettings: () => {
            this.openLogoSettings();
          },
          onOpenWallpaperSettings: () => {
            this.openWallpaperSettings();
          }
        })
      }
      .width('100%')
      .padding(this.resolveScrollPadding())
      .alignItems(HorizontalAlign.Start)
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        this.updatePageBodyHeight('main', newArea.height);
      })
    }
    .width('100%')
    .height(this.resolveMainScrollHeight())
    .constraintSize({ maxHeight: this.resolveScrollViewportCap() })
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
    .clip(this.layoutMode === 'large_screen')
    .attributeModifier(browserSheetHeaderBlurModifier(this.resolveSheetHeaderBlurRadius()))
    .onAppear(() => {
      this.syncSheetHeaderBlur(this.mainSheetScroller);
    })
    .onDidScroll((_xOffset: number, _yOffset: number) => {
      this.syncSheetHeaderBlur(this.mainSheetScroller);
    })
  }

  @Builder
  private buildWallpaperScroll() {
    Scroll(this.wallpaperSheetScroller) {
      Column({ space: 16 }) {
        WallpaperSettingsContent({
          state: this.wallpaperState,
          onColorSelect: (choiceId: string) => {
            this.applyWallpaperColor(choiceId);
          },
          onModeSelect: (mode: WallpaperMode) => {
            this.applyWallpaperMode(mode);
          },
          onVideoSelect: () => {
            this.applyWallpaperVideo();
          },
          onBingRetry: () => {
            this.retryBingPreview();
          }
        })
      }
      .width('100%')
      .padding(this.resolveScrollPadding())
      .alignItems(HorizontalAlign.Start)
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        this.updatePageBodyHeight('wallpaper', newArea.height);
      })
    }
    .width('100%')
    .height(this.resolveWallpaperScrollHeight())
    .constraintSize({ maxHeight: this.resolveScrollViewportCap() })
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
    .clip(this.layoutMode === 'large_screen')
    .attributeModifier(browserSheetHeaderBlurModifier(this.resolveSheetHeaderBlurRadius()))
    .onAppear(() => {
      this.syncSheetHeaderBlur(this.wallpaperSheetScroller);
    })
    .onDidScroll((_xOffset: number, _yOffset: number) => {
      this.syncSheetHeaderBlur(this.wallpaperSheetScroller);
    })
  }

  @Builder
  private buildLogoScroll() {
    Scroll(this.logoSheetScroller) {
      Column({ space: 16 }) {
        HomeLogoSettingsContent({
          selection: this.logoSelection,
          busy: this.logoBusy,
          onSelectLogo: (id: string) => {
            this.selectLogo(id);
          },
          onAddCustom: (source: HomeLogoPickSource) => {
            this.addCustomLogo(source);
          },
          onScaleCommit: (scaleRatio: number) => {
            this.commitLogoScale(scaleRatio);
          },
          onOpacityCommit: (opacity: number) => {
            this.commitLogoOpacity(opacity);
          }
        })
      }
      .width('100%')
      .padding(this.resolveScrollPadding())
      .alignItems(HorizontalAlign.Start)
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        this.updatePageBodyHeight('logo', newArea.height);
      })
    }
    .width('100%')
    .height(this.resolveLogoScrollHeight())
    .constraintSize({ maxHeight: this.resolveScrollViewportCap() })
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
    .clip(this.layoutMode === 'large_screen')
    .attributeModifier(browserSheetHeaderBlurModifier(this.resolveSheetHeaderBlurRadius()))
    .onAppear(() => {
      this.syncSheetHeaderBlur(this.logoSheetScroller);
    })
    .onDidScroll((_xOffset: number, _yOffset: number) => {
      this.syncSheetHeaderBlur(this.logoSheetScroller);
    })
  }

  @Builder
  private buildPhoneHeader() {
    BrowserPhoneSettingsSheetHeader({
      title: this.resolveSheetTitle(),
      showBackButton: this.sheetPage !== 'main',
      backAccessibilityText: $r('app.string.browser_ui_home_page_settings_sheet_003'),
      onBack: (): void => {
        this.popSheetNavigation();
      }
    })
  }

  private resolveScrollPadding(): Padding {
    return {
      left: 16,
      right: 16,
      top: this.layoutMode === 'large_screen' ? 10 : BROWSER_IMMERSIVE_SHEET_HEADER_CONTENT_TOP_INSET,
      bottom: this.layoutMode === 'large_screen' ? 32 : BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING
    };
  }

  private resolveScrollViewportCap(): number {
    if (this.layoutMode !== 'phone') {
      return this.contentMaxHeightVp;
    }
    return this.contentMaxHeightVp + HOME_PAGE_PHONE_HEADER_VIEWPORT_EXTRA_VP;
  }

  private resolveSheetHeaderBlurRadius(): number {
    return this.layoutMode === 'phone' ? this.sheetHeaderBlurRadius : 0;
  }

  private syncSheetHeaderBlur(scroller: Scroller): void {
    if (this.layoutMode !== 'phone') {
      return;
    }
    const offset = scroller.currentOffset().yOffset;
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

  private resolveSheetNavigationBackground(): ResourceColor {
    return this.layoutMode === 'large_screen' ?
      this.storedFloatingSurfaceColor : this.storedPageBackgroundColor;
  }

  private openWallpaperSettings(): void {
    this.refreshWallpaperState();
    if (this.sheetPage === 'wallpaper') {
      return;
    }
    this.resetSheetHeaderBlur();
    this.sheetPage = 'wallpaper';
  }

  private openLogoSettings(): void {
    this.refreshLogoSelection();
    if (this.sheetPage === 'logo') {
      return;
    }
    this.resetSheetHeaderBlur();
    this.sheetPage = 'logo';
  }

  private popSheetNavigation(): boolean {
    const now = Date.now();
    if (now < this.sheetNavigationPopGuardUntilMs) {
      return true;
    }
    if (this.sheetPage === 'main') {
      return false;
    }
    this.sheetNavigationPopGuardUntilMs = now + HOME_PAGE_SHEET_POP_GUARD_MS;
    this.resetSheetHeaderBlur();
    this.sheetPage = 'main';
    return true;
  }

  private resetSheetNavigation(): void {
    this.sheetNavigationPopGuardUntilMs = 0;
    this.resetSheetHeaderBlur();
    this.sheetPage = 'main';
  }

  private updatePageBodyHeight(page: HomePageSettingsSheetPage, height: Length): void {
    const parsed = Number.parseFloat(`${height}`);
    if (!Number.isFinite(parsed) || parsed <= 0) {
      return;
    }
    const next = Math.ceil(parsed);
    if (page === 'wallpaper') {
      if (next !== this.wallpaperBodyHeightVp) {
        this.wallpaperBodyHeightVp = next;
      }
      return;
    }
    if (page === 'logo') {
      if (next !== this.logoBodyHeightVp) {
        this.logoBodyHeightVp = next;
      }
      return;
    }
    if (next !== this.mainBodyHeightVp) {
      this.mainBodyHeightVp = next;
    }
  }

  private resolveMainScrollHeight(): Length {
    if (this.mainBodyHeightVp <= 0) {
      return '';
    }
    return Math.min(this.mainBodyHeightVp, this.resolveScrollViewportCap());
  }

  /** Definite height so FIT_CONTENT can grow from a short homepage sheet into wallpaper. */
  private resolveWallpaperScrollHeight(): number {
    const cap = this.resolveScrollViewportCap();
    const measured = this.wallpaperBodyHeightVp > 0 ? this.wallpaperBodyHeightVp : cap;
    return Math.min(measured, cap);
  }

  private resolveLogoScrollHeight(): number {
    const cap = this.resolveScrollViewportCap();
    const measured = this.logoBodyHeightVp > 0 ? this.logoBodyHeightVp : cap;
    return Math.min(measured, cap);
  }

  private resolveSheetTitle(): string {
    if (this.sheetPage === 'wallpaper') {
      return resolveAppResourceText($r('app.string.settings_home_wallpaper'));
    }
    if (this.sheetPage === 'logo') {
      return homeSheetText($r('app.string.settings_home_logo_settings'), 'Logo设置');
    }
    return homeSheetText($r('app.string.home_settings_title'), '主页设置');
  }

  private refreshLogoSelection(): void {
    this.logoSelection = this.logoCoordinator.getSelection();
  }

  private selectLogo(id: string): void {
    if (this.logoBusy) {
      return;
    }
    this.logoCoordinator.selectLogo(id)
      .then((selection: HomeLogoSelection) => {
        this.logoSelection = selection;
      })
      .catch((error: Error) => {
        this.refreshLogoSelection();
        this.showToast(error.message.length > 0 ? error.message : resolveAppResourceText($r('app.string.settings_home_04')));
      });
  }

  private commitLogoScale(scaleRatio: number): void {
    this.logoCoordinator.setScaleRatio(scaleRatio)
      .then((ratio: number) => {
        AppStorage.setOrCreate(HOME_PAGE_PRESENTATION_HOME_LOGO_SCALE_RATIO_KEY, ratio);
      })
      .catch((_error: Error) => {
        // Snap back to what is actually stored so the slider cannot drift from the saved value.
        AppStorage.setOrCreate(
          HOME_PAGE_PRESENTATION_HOME_LOGO_SCALE_RATIO_KEY,
          this.logoCoordinator.getScaleRatio()
        );
      });
  }

  private commitLogoOpacity(opacity: number): void {
    this.logoCoordinator.setOpacity(opacity)
      .then((next: number) => {
        AppStorage.setOrCreate(HOME_PAGE_PRESENTATION_HOME_LOGO_OPACITY_KEY, next);
      })
      .catch((_error: Error) => {
        AppStorage.setOrCreate(
          HOME_PAGE_PRESENTATION_HOME_LOGO_OPACITY_KEY,
          this.logoCoordinator.getOpacity()
        );
      });
  }

  private addCustomLogo(source: HomeLogoPickSource): void {
    if (this.logoBusy) {
      return;
    }
    this.logoBusy = true;
    this.logoCoordinator.importCustomLogo(source)
      .then((selection: HomeLogoSelection | undefined) => {
        this.logoBusy = false;
        if (selection !== undefined) {
          this.logoSelection = selection;
        }
      })
      .catch((error: Error) => {
        this.logoBusy = false;
        this.refreshLogoSelection();
        this.showToast(error.message.length > 0 ? error.message : resolveAppResourceText($r('app.string.browser_ui_home_page_settings_sheet_001')));
      });
  }

  private refreshWallpaperState(): void {
    this.wallpaperCoordinator.loadState((state: WallpaperSettingsViewState) => {
      this.wallpaperState = state;
    })
      .catch((_error: Error) => {
        this.wallpaperState = this.wallpaperCoordinator.getCurrentState();
      });
  }

  private applyWallpaperColor(choiceId: string): void {
    this.wallpaperCoordinator.selectColor(choiceId, (state: WallpaperSettingsViewState) => {
      this.wallpaperState = state;
    })
      .then((state: WallpaperSettingsViewState) => {
        this.wallpaperState = state;
        this.onWallpaperChanged();
      })
      .catch((error: Error) => {
        this.refreshWallpaperState();
        this.showToast(error.message.length > 0 ? error.message : resolveAppResourceText($r('app.string.wallpaper_select_failed')));
      });
  }

  private applyWallpaperMode(mode: WallpaperMode): void {
    this.wallpaperCoordinator.selectMode(mode, (state: WallpaperSettingsViewState) => {
      this.wallpaperState = state;
    })
      .then((state: WallpaperSettingsViewState) => {
        this.wallpaperState = state;
        this.onWallpaperChanged();
      })
      .catch((error: Error) => {
        this.refreshWallpaperState();
        this.showToast(error.message.length > 0 ? error.message : resolveAppResourceText($r('app.string.wallpaper_select_failed')));
      });
  }

  private applyWallpaperVideo(): void {
    this.wallpaperCoordinator.selectVideo((state: WallpaperSettingsViewState) => {
      this.wallpaperState = state;
    })
      .then((state: WallpaperSettingsViewState) => {
        this.wallpaperState = state;
        this.onWallpaperChanged();
      })
      .catch((error: Error) => {
        this.refreshWallpaperState();
        this.showToast(error.message.length > 0 ? error.message : resolveAppResourceText($r('app.string.wallpaper_select_video_failed')));
      });
  }

  private retryBingPreview(): void {
    this.wallpaperCoordinator.retryBingPreview((state: WallpaperSettingsViewState) => {
      this.wallpaperState = state;
    })
      .then((state: WallpaperSettingsViewState) => {
        this.wallpaperState = state;
        this.onWallpaperChanged();
      })
      .catch((_error: Error) => {
        this.wallpaperState = this.wallpaperCoordinator.getCurrentState();
      });
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 1800
      });
    } catch (_error) {
    }
  }
}

function homeSheetText(resource: Resource, fallback: string): string {
  const resolved = resolveAppResourceText(resource);
  return resolved.length > 0 ? resolved : fallback;
}
