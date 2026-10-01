import { LengthMetrics } from '@kit.ArkUI';
import { TranslationProviderLogoViewModel } from '../../../core/translation/TranslationProviderLogoViewModel';
import { WebpageTranslationPanelState } from '../../../core/translation/WebpageTranslationCoordinator';
import { resolveAppResourceText } from '../../../core/resources/AppResourceText';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_OUTLINE_KEY,
  BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import {
  FLOATING_PROMPT_CARD_ICON_RADIUS,
  FLOATING_PROMPT_CARD_ICON_SIZE,
  FloatingPromptActionButton,
  FloatingPromptCard,
  FloatingPromptMenuButton
} from '../common/FloatingPromptCard';
import {
  createFloatingGlassMaterialIfAvailable,
  resolveFloatingGlassMaterialBackgroundColor,
  resolveFloatingGlassMaterialTintForMode,
  systemMaterialModifier
} from '../common/FloatingGlassMaterialTokens';

const WEBPAGE_TRANSLATION_DISPLAY_MODE_RADIO_GROUP: string = 'webpage-translation-display-mode';

@Component
export struct WebpageTranslationPanel {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_OUTLINE_KEY) private storedOutlineColor: string = '#C8D0DA';
  @StorageProp(BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY) private storedResolvedThemeMode: string = 'light';
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private storedSurfaceBackgroundColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @Prop state: WebpageTranslationPanelState;
  @State private translatingTipIndex: number = 0;
  private translatingTipTimer: number = 0;
  private logoViewModel: TranslationProviderLogoViewModel = new TranslationProviderLogoViewModel();
  onClose: () => void = () => {};
  onTranslate: () => void = () => {};
  onRestoreOriginal: () => void = () => {};
  onShowBilingualTranslation: () => void = () => {};
  onShowTranslationOnly: () => void = () => {};
  onCancel: () => void = () => {};
  onOpenTargetLanguage: () => void = () => {};

  aboutToAppear(): void {
    this.startTranslatingTipTimer();
  }

  aboutToDisappear(): void {
    this.stopTranslatingTipTimer();
  }

  build() {
    FloatingPromptCard({
      title: this.buildTitleText(),
      subtitle: this.buildSubtitleText(),
      loading: this.state.canCancel,
      progress: this.resolveProgressPercent(),
      leading: () => {
        this.buildBrandIcon()
      },
      trailing: () => {
        this.buildTrailingAction()
      }
    })
  }

  @Builder
  private buildBrandIcon() {
    Stack() {
      Image(this.logoViewModel.resolveLogo(this.state.providerTemplateId))
        .width(30)
        .height(30)
        .objectFit(ImageFit.Contain)
    }
    .width(FLOATING_PROMPT_CARD_ICON_SIZE)
    .height(FLOATING_PROMPT_CARD_ICON_SIZE)
    .borderRadius(FLOATING_PROMPT_CARD_ICON_RADIUS)
    .clip(true)
    .backgroundColor(this.storedSurfaceBackgroundColor)
    .borderWidth(1)
    .borderColor(this.storedOutlineColor)
  }

  @Builder
  private buildTrailingAction() {
    if (this.state.canCancel) {
      FloatingPromptActionButton({
        text: resolveAppResourceText($r('app.string.settings_web_translation_cancel')),
        actionEnabled: true,
        onAction: this.onCancel
      })
    } else {
      FloatingPromptMenuButton({
        text: resolveAppResourceText($r('app.string.webpage_translation_actions')),
        menuContent: () => {
          this.buildMoreMenu()
        }
      })
    }
  }

  @Builder
  private buildMoreMenu() {
    Menu() {
      if (this.shouldShowDisplayModeMenuItems()) {
        MenuItemGroup() {
          this.buildDisplayModeMenuItems()
        }
      }

      if (this.shouldShowTranslationActionMenuItems()) {
        MenuItemGroup() {
          this.buildTranslationActionMenuItems()
        }
      }

      MenuItemGroup() {
        this.buildTranslationSettingsMenuItems()
      }

      MenuItemGroup() {
        this.buildCloseMenuItem()
      }
    }
    .width(220)
    .menuItemGroupDivider({
      strokeWidth: LengthMetrics.vp(0.5),
      color: this.storedOutlineColor,
      startMargin: LengthMetrics.vp(12),
      endMargin: LengthMetrics.vp(12)
    })
    .backgroundColor(resolveFloatingGlassMaterialBackgroundColor(
      $r('app.color.surface_floating_background')
    ))
    .attributeModifier(systemMaterialModifier(createFloatingGlassMaterialIfAvailable(
      resolveFloatingGlassMaterialTintForMode(this.storedResolvedThemeMode)
    )))
  }

  @Builder
  private buildDisplayModeMenuItems() {
    MenuItem(() => {
      this.buildDisplayModeMenuItemContent(
        resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_009')),
        'original'
      )
    })
      .onClick(() => {
        if (this.state.displayMode === 'original') {
          return;
        }
        this.onRestoreOriginal();
      })

    MenuItem(() => {
      this.buildDisplayModeMenuItemContent(
        resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_003')),
        'bilingual'
      )
    })
      .onClick(() => {
        if (this.state.displayMode === 'bilingual') {
          return;
        }
        this.onShowBilingualTranslation();
      })

    MenuItem(() => {
      this.buildDisplayModeMenuItemContent(
        resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_001')),
        'translation_only'
      )
    })
      .onClick(() => {
        if (this.state.displayMode === 'translation_only') {
          return;
        }
        this.onShowTranslationOnly();
      })
  }

  @Builder
  private buildTranslationActionMenuItems() {
    if (this.shouldShowTranslateMenuItem()) {
      MenuItem({
        startIcon: $r('sys.symbol.translate_square_fill'),
        content: this.buildPrimaryActionText()
      })
        .enabled(this.state.canTranslate)
        .onClick(() => {
          this.onTranslate();
        })
    }

    if (this.state.canCancel) {
      MenuItem({
        startIcon: $r('sys.symbol.xmark'),
        content: resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_004'))
      })
        .onClick(() => {
          this.onCancel();
        })
    }
  }

  @Builder
  private buildTranslationSettingsMenuItems() {
    MenuItem({
      startIcon: $r('sys.symbol.translate_square_fill'),
      content: resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_018', this.resolveTargetLanguageLabel()))
    })
      .onClick(() => {
        this.onOpenTargetLanguage();
      })
  }

  @Builder
  private buildCloseMenuItem() {
    MenuItem({
      startIcon: $r('sys.symbol.xmark'),
      content: resolveAppResourceText($r('app.string.ui_close'))
    })
      .onClick(() => {
        this.onClose();
      })
  }

  @Builder
  private buildDisplayModeMenuItemContent(
    title: string,
    displayMode: 'original' | 'bilingual' | 'translation_only'
  ) {
    Row({ space: 12 }) {
      Text(title)
        .fontSize(16)
        .fontColor(this.storedPrimaryTextColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Radio({
        value: displayMode,
        group: WEBPAGE_TRANSLATION_DISPLAY_MODE_RADIO_GROUP
      })
        .checked(this.state.displayMode === displayMode)
        .hitTestBehavior(HitTestMode.None)
        .radioStyle({
          checkedBackgroundColor: this.storedAccentColor
        })
    }
    .width('100%')
    .padding({ left: 12, right: 8, top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  private shouldShowDisplayModeMenuItems(): boolean {
    return this.state.canRestore;
  }

  private shouldShowTranslateMenuItem(): boolean {
    return this.state.status === 'idle' ||
      this.state.status === 'error' ||
      this.state.status === 'restored' ||
      this.state.status === 'partially_translated' ||
      this.state.status === 'translated';
  }

  private shouldShowTranslationActionMenuItems(): boolean {
    return this.shouldShowTranslateMenuItem() || this.state.canCancel;
  }

  private buildPrimaryActionText(): string {
    if (this.state.status === 'translated' || this.state.status === 'restored') {
      return resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_013'));
    }
    if (this.state.status === 'partially_translated') {
      return resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_013'));
    }
    return resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_011'));
  }

  private buildTitleText(): string {
    if (this.state.canCancel) {
      return this.buildTranslatingTitleText();
    }
    if (this.state.status === 'translated') {
      return resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_006'));
    }
    if (this.state.status === 'partially_translated') {
      return resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_007'));
    }
    if (this.state.status === 'restored') {
      return resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_005'));
    }
    if (this.state.status === 'error') {
      const stateTitle = this.state.title.trim();
      const genericTitle = resolveAppResourceText($r('app.string.settings_web_translation'));
      if (stateTitle.length > 0 && stateTitle !== genericTitle && stateTitle !== '网页翻译') {
        return stateTitle;
      }
      return resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_012'));
    }
    return resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_008'));
  }

  private buildSubtitleText(): string {
    if (this.state.status === 'idle') {
      return resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_017', this.resolveTargetLanguageLabel()));
    }
    if (this.state.status === 'translated') {
      return resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_018', this.resolveTargetLanguageLabel()));
    }
    if (this.state.status === 'partially_translated') {
      return this.state.message;
    }
    return this.state.message;
  }

  private buildTranslatingTitleText(): string {
    const segmentTotal = this.state.segmentTotal !== undefined ? this.state.segmentTotal : 0;
    const hasSegmentProgress = segmentTotal > 0;
    const tipIndex = this.translatingTipIndex % (hasSegmentProgress ? 3 : 2);
    if (hasSegmentProgress && tipIndex === 1) {
      return resolveAppResourceText($r(
        'app.string.translation_ui_webpage_translation_panel_015',
        `${this.state.translatedCount}`,
        `${segmentTotal}`
      ));
    }
    if (tipIndex === 2 || (!hasSegmentProgress && tipIndex === 1)) {
      return resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_002'));
    }
    return this.buildProviderTranslatingTitleText();
  }

  private buildProviderTranslatingTitleText(): string {
    const providerName = this.state.providerDisplayName.trim();
    if (providerName.length === 0) {
      return resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_010'));
    }
    return resolveAppResourceText($r('app.string.translation_ui_webpage_translation_panel_016', providerName));
  }

  private resolveTargetLanguageLabel(): string {
    switch (this.state.targetLanguage.trim()) {
      case 'zh-CN':
        return resolveAppResourceText($r('app.string.settings_lang_zh_cn'));
      case 'zh-TW':
        return resolveAppResourceText($r('app.string.settings_lang_zh_tw'));
      case 'en':
        return resolveAppResourceText($r('app.string.settings_lang_en'));
      case 'ja':
        return resolveAppResourceText($r('app.string.settings_lang_ja'));
      case 'ko':
        return resolveAppResourceText($r('app.string.settings_lang_ko'));
      default:
        return this.state.targetLanguage.trim().length > 0
          ? this.state.targetLanguage.trim()
          : resolveAppResourceText($r('app.string.settings_lang_zh_cn'));
    }
  }

  private startTranslatingTipTimer(): void {
    if (this.translatingTipTimer !== 0) {
      return;
    }
    this.translatingTipTimer = setInterval(() => {
      if (!this.state.canCancel) {
        this.translatingTipIndex = 0;
        return;
      }
      this.translatingTipIndex = this.translatingTipIndex + 1;
    }, 3200);
  }

  private stopTranslatingTipTimer(): void {
    if (this.translatingTipTimer !== 0) {
      clearInterval(this.translatingTipTimer);
      this.translatingTipTimer = 0;
    }
  }

  private resolveProgressPercent(): number {
    const message = this.state.message;
    const match = message.match(/(\d+)\/(\d+)/);
    if (match === null || match.length < 3) {
      return 12;
    }
    const current = Number(match[1]);
    const total = Number(match[2]);
    if (!Number.isFinite(current) || !Number.isFinite(total) || total <= 0) {
      return 12;
    }
    return Math.max(8, Math.min(100, Math.round(current * 100 / total)));
  }
}
