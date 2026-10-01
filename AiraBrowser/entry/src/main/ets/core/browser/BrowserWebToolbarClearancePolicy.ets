import {
  BROWSER_BOTTOM_ADDRESS_PANEL_FLOATING_BOTTOM_GAP,
  BROWSER_BOTTOM_ADDRESS_PANEL_FLOATING_LOW_HEIGHT
} from './BrowserBottomAddressPanelMetrics';

/**
 * Resting overlap of the floating capsule, in vp. The web view stays full-bleed; this is only the
 * extra scroll range that lets the last line clear the capsule, the same job Safari's root scroll
 * inset does. Scroll-compact and scroll-hidden keep this height: changing it mid-fling resizes the
 * document under the finger. The spacer goes away only when the capsule is no longer an overlay.
 */
export const BROWSER_WEB_TOOLBAR_CLEARANCE_VP: number =
  BROWSER_BOTTOM_ADDRESS_PANEL_FLOATING_LOW_HEIGHT + BROWSER_BOTTOM_ADDRESS_PANEL_FLOATING_BOTTOM_GAP;

export interface BrowserWebToolbarClearanceInput {
  overlayActive: boolean;
  viewportReserved: boolean;
  bottomLiftVp: number;
}

export function resolveWebToolbarClearanceVp(input: BrowserWebToolbarClearanceInput): number {
  if (!input.overlayActive || input.viewportReserved) {
    return 0;
  }
  const liftVp = Number.isFinite(input.bottomLiftVp) ? Math.max(0, input.bottomLiftVp) : 0;
  return Math.ceil(BROWSER_WEB_TOOLBAR_CLEARANCE_VP + liftVp);
}
