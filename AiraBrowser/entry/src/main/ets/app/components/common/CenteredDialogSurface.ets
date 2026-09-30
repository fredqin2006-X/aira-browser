import { display } from '@kit.ArkUI';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_FLOATING_SURFACE_KEY,
  BROWSER_THEME_STORAGE_ON_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import {
  DESKTOP_DIALOG_ACTION_FONT_SIZE_FP,
  DESKTOP_DIALOG_ACTION_GAP_VP,
  DESKTOP_DIALOG_ACTION_HEIGHT_VP,
  DESKTOP_DIALOG_CORNER_RADIUS_VP,
  DESKTOP_DIALOG_DESTRUCTIVE_FILL,
  DESKTOP_DIALOG_DESTRUCTIVE_TEXT,
  DESKTOP_DIALOG_NARROW_WINDOW_VP,
  DESKTOP_DIALOG_PADDING_VP,
  DESKTOP_DIALOG_TITLE_FONT_SIZE_FP,
  DesktopDialogTier
} from '../../../core/browser/BrowserDialogPresentationTokens';
import {
  CENTERED_DIALOG_ALERT_WIDTH_RATIO,
  CENTERED_DIALOG_MAX_WIDTH_VP,
  CenteredDialogWidthViewModel
} from '../../../core/browser/CenteredDialogWidthViewModel';
import { DesktopDialogWidthViewModel } from '../../../core/browser/DesktopDialogWidthViewModel';
import { isAppString } from '../../../core/resources/AppResourceText';

export { CENTERED_DIALOG_MAX_WIDTH_VP };
export const CENTERED_DIALOG_HORIZONTAL_MARGIN_VP: number = 12;
/** Width the PC/large-screen shell gives a tall centered dialog that holds a list. */
export const CENTERED_DIALOG_WIDE_MAX_WIDTH_VP: number = 520;
export const CENTERED_DIALOG_CORNER_RADIUS_VP: number = DESKTOP_DIALOG_CORNER_RADIUS_VP;
export const CENTERED_DIALOG_CONTENT_GAP_VP: number = 16;
export const CENTERED_DIALOG_HORIZONTAL_PADDING_VP: number = DESKTOP_DIALOG_PADDING_VP;
export const CENTERED_DIALOG_TOP_PADDING_VP: number = DESKTOP_DIALOG_PADDING_VP;
export const CENTERED_DIALOG_BOTTOM_PADDING_VP: number = DESKTOP_DIALOG_PADDING_VP;
export const CENTERED_DIALOG_TITLE_FONT_SIZE_FP: number = DESKTOP_DIALOG_TITLE_FONT_SIZE_FP;
export const CENTERED_DIALOG_ACTION_GAP_VP: number = DESKTOP_DIALOG_ACTION_GAP_VP;
export const CENTERED_DIALOG_ACTION_HEIGHT_VP: number = DESKTOP_DIALOG_ACTION_HEIGHT_VP;
export const CENTERED_DIALOG_ACTION_FONT_SIZE_FP: number = DESKTOP_DIALOG_ACTION_FONT_SIZE_FP;
const CENTERED_DIALOG_TALL_HEIGHT: string = 'calc(100% - 48vp)';
const CENTERED_DIALOG_TALL_MAX_HEIGHT_VP: number = 720;
// AlertDialog.width accepts Dimension (not calc expressions) and has no
// constraintSize, so a percentage is the only value that preserves the centered
// 12vp contract on a phone. A percentage is relative to the window, though, so
// the same 90% becomes an absurdly wide alert on a PC/large-screen window. The
// shared width owner keeps the percentage only while it still fits the
// centered-dialog maximum and pins to that maximum otherwise.
const CENTERED_DIALOG_ALERT_WIDTH_PERCENT: Dimension = '90%';
const ALERT_PAIR_FALLBACK_ACCENT_COLOR: string = '#0A59F7';
const ALERT_PAIR_FALLBACK_ON_PRIMARY_COLOR: string = '#FFFFFF';
const ALERT_PAIR_GHOST_BACKGROUND_COLOR: string = '#00000000';

const centeredDialogWidthViewModel: CenteredDialogWidthViewModel = new CenteredDialogWidthViewModel();
const desktopDialogWidthViewModel: DesktopDialogWidthViewModel = new DesktopDialogWidthViewModel();

/**
 * One opaque surface for every centered dialog. Reads the same floating-surface
 * token the rest of the shell uses, and falls back to the light/dark resource
 * when the theme has not been published yet.
 */
export function resolveCenteredDialogSurfaceColor(): ResourceColor {
  const storedColor = AppStorage.get<string>(BROWSER_THEME_STORAGE_FLOATING_SURFACE_KEY);
  if (storedColor === undefined || storedColor.length === 0) {
    return $r('app.color.surface_floating_background');
  }
  return storedColor;
}

export type CenteredAlertDialogParams =
  AlertDialogParamWithConfirm | AlertDialogParamWithButtons | AlertDialogParamWithOptions;

/**
 * Resolves the AlertDialog width for the current window so a wide PC/large-screen
 * window does not stretch the alert to the whole viewport.
 */
function resolveCenteredAlertDialogWidth(tier: DesktopDialogTier): Dimension {
  if (shouldUseDesktopDialogWidth(readDisplayWidthVp())) {
    return resolveCenteredDialogControllerWidth(tier);
  }
  const resolved = centeredDialogWidthViewModel.resolve(readDisplayWidthVp());
  if (resolved.percentBased) {
    return CENTERED_DIALOG_ALERT_WIDTH_PERCENT;
  }
  return resolved.widthVp;
}

function resolveAlertDialogTier(params: CenteredAlertDialogParams): DesktopDialogTier {
  const options = params as AlertDialogParamWithOptions;
  if (options.buttons !== undefined && options.buttons.length >= 3) {
    return 's';
  }
  return 'xs';
}

function isDestructiveAlertLabel(value: ResourceStr): boolean {
  if (typeof value !== 'string') {
    return isAppString(value, $r('app.string.settings_delete')) ||
      isAppString(value, $r('app.string.ui_clear'));
  }
  return value.includes('删除') || value.includes('清除') ||
    value.includes('移除') || value.includes('移出') ||
    value.includes('清空') || value.includes('退出') ||
    value.includes('重置') || value.includes('不保存');
}

/** Call sites mark a dangerous action with red text and no fill. That is the same action. */
function isCallerDestructiveAlertColor(color: ResourceColor | undefined): boolean {
  if (color === undefined || typeof color !== 'object') {
    return false;
  }
  const marked: Resource = $r('app.color.permission_blocked');
  return color.id === marked.id;
}

function styleDestructiveAlertButton(button: AlertDialogButtonBaseOptions): void {
  const labeledDestructive = button.value !== undefined && isDestructiveAlertLabel(button.value);
  if (!labeledDestructive && !isCallerDestructiveAlertColor(button.fontColor)) {
    return;
  }
  button.backgroundColor = DESKTOP_DIALOG_DESTRUCTIVE_FILL;
  button.fontColor = DESKTOP_DIALOG_DESTRUCTIVE_TEXT;
}

function alertButtonLabel(button: AlertDialogButtonBaseOptions): ResourceStr {
  return button.value === undefined ? '' : button.value;
}

function isDismissAlertLabel(label: ResourceStr): boolean {
  if (typeof label !== 'string') {
    return isAppString(label, $r('app.string.settings_account_cancel')) ||
      isAppString(label, $r('app.string.settings_sync_later')) ||
      isAppString(label, $r('app.string.settings_pro_got_it'));
  }
  return label === '取消' || label === '稍后' || label === '稍后处理' || label === '知道了';
}

function resolveStoredAlertColor(key: string, fallback: string): ResourceColor {
  const stored = AppStorage.get<string>(key);
  if (stored === undefined || stored.length === 0) {
    return fallback;
  }
  return stored;
}

function resolveAlertTextColor(): ResourceColor {
  const stored = AppStorage.get<string>(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY);
  if (stored === undefined || stored.length === 0) {
    return $r('sys.color.ohos_id_color_text_primary');
  }
  return stored;
}

/**
 * primaryButton is the left-hand button. secondaryButton is the right-hand button.
 * A dismiss label moves under the action; two real choices keep that left-to-right
 * order from top to bottom. Neither button is marked primary, so Enter does not
 * confirm a destructive action and the system does not restyle the lower button.
 */
function orderPairedAlertButtons(
  leading: AlertDialogButtonBaseOptions,
  trailing: AlertDialogButtonBaseOptions
): AlertDialogButtonBaseOptions[] {
  const leadingDismiss = isDismissAlertLabel(alertButtonLabel(leading));
  const trailingDismiss = isDismissAlertLabel(alertButtonLabel(trailing));
  if (leadingDismiss && !trailingDismiss) {
    return [trailing, leading];
  }
  return [leading, trailing];
}

function styleStackedAlertPair(
  top: AlertDialogButtonBaseOptions,
  bottom: AlertDialogButtonBaseOptions
): void {
  if (top.backgroundColor === undefined && top.fontColor === undefined) {
    top.backgroundColor = resolveStoredAlertColor(
      BROWSER_THEME_STORAGE_ACCENT_KEY, ALERT_PAIR_FALLBACK_ACCENT_COLOR);
    top.fontColor = resolveStoredAlertColor(
      BROWSER_THEME_STORAGE_ON_PRIMARY_KEY, ALERT_PAIR_FALLBACK_ON_PRIMARY_COLOR);
  }
  if (bottom.backgroundColor !== undefined || isDestructiveAlertLabel(alertButtonLabel(bottom))) {
    return;
  }
  bottom.backgroundColor = ALERT_PAIR_GHOST_BACKGROUND_COLOR;
  if (bottom.fontColor === undefined) {
    bottom.fontColor = resolveAlertTextColor();
  }
}

interface StackedAlertDialogParams {
  primaryButton?: AlertDialogButtonBaseOptions;
  secondaryButton?: AlertDialogButtonBaseOptions;
  buttons?: AlertDialogButtonOptions[];
  buttonDirection?: DialogButtonDirection;
}

/**
 * The primary/secondary API cannot set buttonDirection. A new options object
 * carries the same dialog fields plus a vertical button list, and omits the
 * old pair so the system does not also draw the side-by-side buttons.
 */
function stackPairedAlertButtons(params: CenteredAlertDialogParams): AlertDialogParamWithOptions | undefined {
  const paired = params as StackedAlertDialogParams;
  if (paired.primaryButton === undefined || paired.secondaryButton === undefined) {
    return undefined;
  }
  const leading = paired.primaryButton;
  const trailing = paired.secondaryButton;
  styleDestructiveAlertButton(leading);
  styleDestructiveAlertButton(trailing);
  const ordered = orderPairedAlertButtons(leading, trailing);
  styleStackedAlertPair(ordered[0], ordered[1]);
  const source = params as AlertDialogParam;
  const stacked: AlertDialogParamWithOptions = {
    title: source.title,
    subtitle: source.subtitle,
    message: source.message,
    autoCancel: source.autoCancel,
    cancel: source.cancel,
    alignment: source.alignment,
    offset: source.offset,
    gridCount: source.gridCount,
    maskRect: source.maskRect,
    showInSubWindow: source.showInSubWindow,
    isModal: source.isModal,
    backgroundColor: source.backgroundColor,
    backgroundBlurStyle: source.backgroundBlurStyle,
    onWillDismiss: source.onWillDismiss,
    cornerRadius: source.cornerRadius,
    width: source.width,
    height: source.height,
    borderWidth: source.borderWidth,
    borderColor: source.borderColor,
    borderStyle: source.borderStyle,
    shadow: source.shadow,
    textStyle: source.textStyle,
    enableHoverMode: source.enableHoverMode,
    hoverModeArea: source.hoverModeArea,
    buttons: [
      ordered[0] as AlertDialogButtonOptions,
      ordered[1] as AlertDialogButtonOptions
    ],
    buttonDirection: DialogButtonDirection.VERTICAL
  };
  return stacked;
}

function applyAlertActionChrome(params: CenteredAlertDialogParams): CenteredAlertDialogParams {
  const stacked = stackPairedAlertButtons(params);
  if (stacked !== undefined) {
    return stacked;
  }
  const options = params as AlertDialogParamWithOptions;
  if (options.buttons !== undefined) {
    const labels: string[] = [];
    for (let index = 0; index < options.buttons.length; index++) {
      const button = options.buttons[index];
      styleDestructiveAlertButton(button);
      labels.push(typeof button.value === 'string' ? button.value : '');
    }
    const windowWidthVp = readDisplayWidthVp();
    const layout = desktopDialogWidthViewModel.resolve(
      resolveAlertDialogTier(params), windowWidthVp, readDisplayHeightVp());
    const contentWidthVp = Math.max(0, layout.widthVp - layout.paddingVp * 2);
    const actionLayout = desktopDialogWidthViewModel.resolveActionLayout(
      labels, contentWidthVp, windowWidthVp);
    options.buttonDirection = actionLayout === 'stack' ?
      DialogButtonDirection.VERTICAL : DialogButtonDirection.HORIZONTAL;
    return params;
  }
  const paired = params as AlertDialogParamWithButtons;
  if (paired.primaryButton !== undefined) {
    styleDestructiveAlertButton(paired.primaryButton);
  }
  if (paired.secondaryButton !== undefined) {
    styleDestructiveAlertButton(paired.secondaryButton);
  }
  return params;
}

function shouldUseDesktopDialogWidth(windowWidthVp: number): boolean {
  return Number.isFinite(windowWidthVp) && windowWidthVp >= DESKTOP_DIALOG_NARROW_WINDOW_VP;
}

/**
 * Controller width for a centered dialog. CustomDialog caps its box at 400vp
 * unless this is set. Phone and unknown windows keep the existing alert width.
 */
export function resolveCenteredDialogControllerWidth(tier: DesktopDialogTier = 's'): Dimension {
  const windowWidthVp = readDisplayWidthVp();
  if (!shouldUseDesktopDialogWidth(windowWidthVp)) {
    const resolved = centeredDialogWidthViewModel.resolve(windowWidthVp);
    if (resolved.percentBased) {
      return CENTERED_DIALOG_ALERT_WIDTH_PERCENT;
    }
    return resolved.widthVp;
  }
  return desktopDialogWidthViewModel.resolve(tier, windowWidthVp, readDisplayHeightVp()).widthVp;
}

function resolveCenteredWideDialogWidth(): Dimension {
  const windowWidthVp = readDisplayWidthVp();
  if (!Number.isFinite(windowWidthVp) || windowWidthVp <= 0 ||
    windowWidthVp * CENTERED_DIALOG_ALERT_WIDTH_RATIO <= CENTERED_DIALOG_WIDE_MAX_WIDTH_VP) {
    return CENTERED_DIALOG_ALERT_WIDTH_PERCENT;
  }
  return Math.min(CENTERED_DIALOG_WIDE_MAX_WIDTH_VP,
    windowWidthVp - CENTERED_DIALOG_HORIZONTAL_MARGIN_VP * 2);
}

/**
 * Width for a wide centered dialog on the PC/large-screen shell.
 *
 * A CustomDialogController caps its own box at 400 vp by default, so a caller that
 * needs a wider surface must widen the controller box as well as the content; the
 * content alone just overflows and gets clipped.
 */
export function resolveWideCenteredDialogWidth(): Dimension {
  return resolveCenteredWideDialogWidth();
}

function readDisplayExtentVp(extentPx: number, densityPixels: number): number {
  if (!Number.isFinite(extentPx) || extentPx <= 0 ||
    !Number.isFinite(densityPixels) || densityPixels <= 0) {
    return 0;
  }
  return extentPx / densityPixels;
}

function readDisplayWidthVp(): number {
  try {
    const defaultDisplay = display.getDefaultDisplaySync();
    return readDisplayExtentVp(defaultDisplay.width, defaultDisplay.densityPixels);
  } catch (_error) {
    return 0;
  }
}

function readDisplayHeightVp(): number {
  try {
    const defaultDisplay = display.getDefaultDisplaySync();
    return readDisplayExtentVp(defaultDisplay.height, defaultDisplay.densityPixels);
  } catch (_error) {
    return 0;
  }
}

/** Adds the shared centered-dialog surface without choosing the execution owner. */
export function configureCenteredAlertDialog(params: CenteredAlertDialogParams): CenteredAlertDialogParams {
  params.width = resolveCenteredAlertDialogWidth(resolveAlertDialogTier(params));
  params.cornerRadius = CENTERED_DIALOG_CORNER_RADIUS_VP;
  params.backgroundColor = resolveCenteredDialogSurfaceColor();
  params.backgroundBlurStyle = BlurStyle.NONE;
  params.alignment = DialogAlignment.Center;
  return applyAlertActionChrome(params);
}

/** Applies the shared solid surface while retaining AlertDialog's native behavior. */
export function showCenteredAlertDialog(params: CenteredAlertDialogParams): void {
  AlertDialog.show(configureCenteredAlertDialog(params));
}

class CenteredDialogSurfaceModifier implements AttributeModifier<CommonAttribute> {
  private readonly fillHeight: boolean;
  private readonly boundHeight: boolean;
  private readonly contentPadding: boolean;
  private readonly paddingTop: number;
  private readonly paddingBottom: number;
  private readonly definiteWidth: boolean;

  constructor(
    fillHeight: boolean,
    boundHeight: boolean = false,
    contentPadding: boolean = false,
    paddingTop: number = CENTERED_DIALOG_TOP_PADDING_VP,
    paddingBottom: number = CENTERED_DIALOG_BOTTOM_PADDING_VP,
    definiteWidth: boolean = false
  ) {
    this.fillHeight = fillHeight;
    this.boundHeight = boundHeight;
    this.contentPadding = contentPadding;
    this.paddingTop = paddingTop;
    this.paddingBottom = paddingBottom;
    this.definiteWidth = definiteWidth;
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    // Content that itself wraps a Navigation/Scroll has no intrinsic width, so a
    // percentage here resolves against an indeterminate parent and the dialog
    // collapses to its content. Those surfaces take the same definite width the
    // AlertDialog path already resolves instead of the calc() expression. The
    // wide variant uses the PC dialog width rather than the phone alert width.
    // On a wide window the controller already owns the tier width, so capping
    // the content at the phone maximum would clip every S+ dialog.
    const windowWidthVp = readDisplayWidthVp();
    if (shouldUseDesktopDialogWidth(windowWidthVp)) {
      instance.width('100%')
      if (this.fillHeight || this.boundHeight) {
        const maxHeightVp = desktopDialogWidthViewModel.resolve(
          'l', windowWidthVp, readDisplayHeightVp()).maxHeightVp;
        if (this.fillHeight) {
          instance.height(maxHeightVp)
        }
        instance.constraintSize({ maxHeight: maxHeightVp })
      }
    } else {
      // The controller already sizes the card. A second calc() inset here sat
      // outside the shared padding and made custom dialogs looser than alerts.
      instance.width(this.definiteWidth ? resolveCenteredWideDialogWidth() : '100%')
      if (this.fillHeight) {
        instance.height(CENTERED_DIALOG_TALL_HEIGHT)
        instance.constraintSize({
          maxWidth: this.definiteWidth ? CENTERED_DIALOG_WIDE_MAX_WIDTH_VP : CENTERED_DIALOG_MAX_WIDTH_VP,
          maxHeight: CENTERED_DIALOG_TALL_MAX_HEIGHT_VP
        })
      } else if (this.boundHeight) {
        instance.constraintSize({
          maxWidth: CENTERED_DIALOG_MAX_WIDTH_VP,
          maxHeight: CENTERED_DIALOG_TALL_HEIGHT
        })
      } else {
        instance.constraintSize({ maxWidth: CENTERED_DIALOG_MAX_WIDTH_VP })
      }
    }
    instance.borderRadius(CENTERED_DIALOG_CORNER_RADIUS_VP)
    instance.clip(true)
    instance.backgroundColor(resolveCenteredDialogSurfaceColor())
    if (this.contentPadding) {
      instance.padding({
        left: CENTERED_DIALOG_HORIZONTAL_PADDING_VP,
        right: CENTERED_DIALOG_HORIZONTAL_PADDING_VP,
        top: this.paddingTop,
        bottom: this.paddingBottom
      })
    }
  }
}

export const CENTERED_DIALOG_SURFACE_MODIFIER: AttributeModifier<CommonAttribute> =
  new CenteredDialogSurfaceModifier(false, false, true);
export const CENTERED_DIALOG_COMPACT_SURFACE_MODIFIER: AttributeModifier<CommonAttribute> =
  new CenteredDialogSurfaceModifier(false, false, true, 16, 12);
export const CENTERED_DIALOG_TALL_SURFACE_MODIFIER: AttributeModifier<CommonAttribute> =
  new CenteredDialogSurfaceModifier(true);
export const CENTERED_DIALOG_TALL_PADDED_SURFACE_MODIFIER: AttributeModifier<CommonAttribute> =
  new CenteredDialogSurfaceModifier(true, false, true);
export const CENTERED_DIALOG_SCROLL_SURFACE_MODIFIER: AttributeModifier<CommonAttribute> =
  new CenteredDialogSurfaceModifier(false, true);
export const CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER: AttributeModifier<CommonAttribute> =
  new CenteredDialogSurfaceModifier(false, false, true);
export const CENTERED_DIALOG_SYSTEM_COMPACT_SURFACE_MODIFIER: AttributeModifier<CommonAttribute> =
  new CenteredDialogSurfaceModifier(false, false, true, 16, 12);
export const CENTERED_DIALOG_SYSTEM_TALL_SURFACE_MODIFIER: AttributeModifier<CommonAttribute> =
  new CenteredDialogSurfaceModifier(true);
// Same tall surface, but with a definite width for content that has no intrinsic width
// (a wrapped Navigation or Scroll) and would otherwise collapse narrower than its peers.
export const CENTERED_DIALOG_SYSTEM_TALL_DEFINITE_SURFACE_MODIFIER: AttributeModifier<CommonAttribute> =
  new CenteredDialogSurfaceModifier(true, false, false, CENTERED_DIALOG_TOP_PADDING_VP,
    CENTERED_DIALOG_BOTTOM_PADDING_VP, true);
// Definite width, but no forced height. A tall fill uses the physical display, so a
// shorter app window clips the footer and leaves a blank band above it.
export const CENTERED_DIALOG_SYSTEM_HUG_DEFINITE_SURFACE_MODIFIER: AttributeModifier<CommonAttribute> =
  new CenteredDialogSurfaceModifier(false, false, false, CENTERED_DIALOG_TOP_PADDING_VP,
    CENTERED_DIALOG_BOTTOM_PADDING_VP, true);
export const CENTERED_DIALOG_SYSTEM_TALL_PADDED_SURFACE_MODIFIER: AttributeModifier<CommonAttribute> =
  new CenteredDialogSurfaceModifier(true, false, true);
export const CENTERED_DIALOG_SYSTEM_SCROLL_SURFACE_MODIFIER: AttributeModifier<CommonAttribute> =
  new CenteredDialogSurfaceModifier(false, true);

@Component
export struct CenteredDialogSurface {
  @Prop fillHeight: boolean = false;
  @BuilderParam content: () => void = this.emptyContent;

  build() {
    if (this.fillHeight) {
      this.buildTallSurface()
    } else {
      this.buildCompactSurface()
    }
  }

  @Builder
  private buildCompactSurface() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.content()
    }
    .attributeModifier(new CenteredDialogSurfaceModifier(false, false, true))
  }

  @Builder
  private buildTallSurface() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.content()
    }
    .attributeModifier(new CenteredDialogSurfaceModifier(true))
  }

  @Builder
  private emptyContent() {
  }
}
