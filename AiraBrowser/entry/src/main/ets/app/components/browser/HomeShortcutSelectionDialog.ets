import { resolveAppResourceText } from '../../../core/resources/AppResourceText';
import {
  HomeShortcutSelectionAction,
  HomeShortcutSelectionState
} from '../../../core/shortcuts/HomeShortcutSelectionCoordinator';
import { BrowserLargeScreenModalHeader } from './BrowserLargeScreenModalHeader';
import { HomeShortcutSelectionContent } from './HomeShortcutSelectionSheet';
import { CENTERED_DIALOG_SYSTEM_HUG_DEFINITE_SURFACE_MODIFIER } from '../common/CenteredDialogSurface';
import { desktopDialogTierSpec } from '../../../core/browser/BrowserDialogPresentationTokens';
import { display } from '@kit.ArkUI';

const HOME_SHORTCUT_DIALOG_EDGE_VP: number = 48;

function readHomeShortcutDialogWindowHeightVp(): number {
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

function resolveHomeShortcutSelectionDialogMaxHeightVp(): number {
  const cap = desktopDialogTierSpec('m').maxHeightVp;
  const windowHeight = readHomeShortcutDialogWindowHeightVp();
  if (windowHeight <= 0) {
    return cap;
  }
  return Math.min(cap, Math.max(360, windowHeight - HOME_SHORTCUT_DIALOG_EDGE_VP));
}

@CustomDialog
export struct HomeShortcutSelectionDialog {
  controller?: CustomDialogController;
  @Link state: HomeShortcutSelectionState;
  onAction: (action: HomeShortcutSelectionAction) => void = (_action: HomeShortcutSelectionAction) => {};
  onClose: () => void = () => {};
  onBack: () => void = () => {};

  build() {
    Column() {
      BrowserLargeScreenModalHeader({
        title: resolveAppResourceText($r('app.string.browser_ui_home_shortcut_selection_sheet_003')),
        dialogMode: true,
        onClose: this.onClose
      })

      HomeShortcutSelectionContent({
        state: this.state,
        layoutMode: 'large_screen',
        onAction: this.onAction
      })
        .width('100%')
        .padding({ left: 20, right: 20, top: 18, bottom: 20 })
    }
    .attributeModifier(CENTERED_DIALOG_SYSTEM_HUG_DEFINITE_SURFACE_MODIFIER)
    .constraintSize({ maxHeight: resolveHomeShortcutSelectionDialogMaxHeightVp() })
    .keyboardShortcut(FunctionKey.ESC, [], () => {
      this.onBack();
    })
  }
}
