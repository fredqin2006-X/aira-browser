import { BROWSER_GLOBAL_SYMBOL_WEIGHT } from './BrowserIconStyle';
import { BrowserArkWebMediaButtonState } from '../../../core/browser/media/BrowserArkWebMediaTakeoverCoordinator';
import { BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY } from '../../../core/theme/BrowserThemeStorageKeys';
import { HdsImmersiveMaterialSurface } from '../common/HdsImmersiveMaterialSurface';
import { isHdsMaterialAvailable } from '../common/HdsImmersiveMaterialTokens';
import { BrowserFloatingGlassMaterialSurface } from './BrowserFloatingGlassMaterialSurface';
import { resolveBrowserFloatingGlassMaterialTintForMode } from './BrowserFloatingGlassMaterialTokens';

const ARKWEB_MEDIA_BUTTON_SIZE: number = 48;
const ARKWEB_MEDIA_ICON_SIZE: number = 22;
const ARKWEB_MEDIA_BUSY_OPACITY: number = 0.7;

@Component
export struct BrowserArkWebMediaTakeoverFloatingButton {
  @StorageProp(BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY) private storedResolvedThemeMode: string = 'light';
  @Prop sourceCount: number = 0;
  @Prop controllable: boolean = false;
  @Prop busy: boolean = false;
  @Prop buttonColor: ResourceColor = '';
  @Prop iconColor: ResourceColor = '';
  onButtonTap: () => void = (): void => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseHdsMaterialPlate()) {
        HdsImmersiveMaterialSurface({
          plateWidth: ARKWEB_MEDIA_BUTTON_SIZE,
          plateHeight: ARKWEB_MEDIA_BUTTON_SIZE,
          plateRadius: ARKWEB_MEDIA_BUTTON_SIZE / 2
        })
      }
      BrowserFloatingGlassMaterialSurface({
        surfaceWidth: ARKWEB_MEDIA_BUTTON_SIZE,
        surfaceHeight: ARKWEB_MEDIA_BUTTON_SIZE,
        surfaceRadius: ARKWEB_MEDIA_BUTTON_SIZE / 2,
        tintColor: resolveBrowserFloatingGlassMaterialTintForMode(this.storedResolvedThemeMode),
        hostMaterialActive: this.shouldUseHdsMaterialPlate()
      }) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.play_fill'))
            .fontSize(ARKWEB_MEDIA_ICON_SIZE)
            .fontWeight(BROWSER_GLOBAL_SYMBOL_WEIGHT)
            .fontColor([this.iconColor])
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
        .enabled(!this.busy)
        .stateEffect(true)
        .accessibilityText(this.buildAccessibilityText())
        .onClick(() => {
          this.onButtonTap();
        })
      }
    }
    .width(ARKWEB_MEDIA_BUTTON_SIZE)
    .height(ARKWEB_MEDIA_BUTTON_SIZE)
    .opacity(this.busy ? ARKWEB_MEDIA_BUSY_OPACITY : 1)
  }

  private shouldUseHdsMaterialPlate(): boolean {
    return isHdsMaterialAvailable();
  }

  private buildAccessibilityText(): ResourceStr {
    if (!this.controllable) {
      return $r('app.string.media_resource_takeover_a11y_uncontrollable');
    }
    if (this.sourceCount > 1) {
      return $r('app.string.media_resource_takeover_a11y_sources', this.sourceCount);
    }
    return $r('app.string.media_resource_takeover_a11y_default');
  }
}

@Component
export struct BrowserArkWebMediaTakeoverFloatingButtonHost {
  @Prop state: BrowserArkWebMediaButtonState;
  @Prop buttonColor: ResourceColor = '';
  @Prop iconColor: ResourceColor = '';
  @Prop layerIndex: number = 0;
  onButtonTap: () => void = (): void => {};

  build() {
    BrowserArkWebMediaTakeoverFloatingButton({
      sourceCount: this.state.sourceCount,
      controllable: this.state.controllable,
      busy: this.state.busy,
      buttonColor: this.buttonColor,
      iconColor: this.iconColor,
      onButtonTap: this.onButtonTap
    })
      .position({ x: this.state.x, y: this.state.y })
      .zIndex(this.layerIndex)
  }
}
