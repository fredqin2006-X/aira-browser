import {
  BrowserBottomPanelMotionState,
  DEFAULT_BROWSER_BOTTOM_PANEL_MOTION_STATE
} from './BrowserBottomAddressPanelViewModel';
import {
  BrowserBottomChromePresentation,
  DEFAULT_BROWSER_BOTTOM_CHROME_PRESENTATION
} from './BrowserBottomChromePresentationViewModel';
import { BrowserBottomPanelActionSnapshot } from './BrowserBottomPanelActionPresentationCoordinator';
import { AiraMembershipBadgeKind } from '../../common/models/MembershipModels';

export interface BrowserBottomPanelReadingContinuationPresentation {
  visible: boolean;
  title: string;
  loading: boolean;
}

export const HIDDEN_BROWSER_BOTTOM_PANEL_READING_CONTINUATION: BrowserBottomPanelReadingContinuationPresentation = {
  visible: false,
  title: '',
  loading: false
};

/**
 * What the toolbar sheet's middle capsule shows about the account on Home.
 *
 * `label` is the nickname when signed in and the signed-out or Community wording otherwise, so the
 * capsule renders one string without re-deriving identity. `membershipBadge` reuses the settings
 * badge vocabulary; Community always resolves to `none` because it has no membership tier.
 */
export interface BrowserBottomPanelAccountCapsulePresentation {
  visible: boolean;
  label: string;
  avatarUri: string;
  signedIn: boolean;
  membershipBadge: AiraMembershipBadgeKind;
}

export const HIDDEN_BROWSER_BOTTOM_PANEL_ACCOUNT_CAPSULE: BrowserBottomPanelAccountCapsulePresentation = {
  visible: false,
  label: '',
  avatarUri: '',
  signedIn: false,
  membershipBadge: 'none'
};

export class BrowserBottomPanelLivePresentation {
  panelMotionState: BrowserBottomPanelMotionState;
  bottomChromePresentation: BrowserBottomChromePresentation;
  actionSnapshot?: BrowserBottomPanelActionSnapshot;
  readingContinuation: BrowserBottomPanelReadingContinuationPresentation;
  accountCapsule: BrowserBottomPanelAccountCapsulePresentation;
  addressFocused: boolean;
  floatingHeaderVisible: boolean;

  constructor(
    panelMotionState: BrowserBottomPanelMotionState,
    bottomChromePresentation: BrowserBottomChromePresentation,
    actionSnapshot?: BrowserBottomPanelActionSnapshot,
    readingContinuation: BrowserBottomPanelReadingContinuationPresentation =
      HIDDEN_BROWSER_BOTTOM_PANEL_READING_CONTINUATION,
    addressFocused: boolean = false,
    floatingHeaderVisible: boolean = true,
    accountCapsule: BrowserBottomPanelAccountCapsulePresentation =
      HIDDEN_BROWSER_BOTTOM_PANEL_ACCOUNT_CAPSULE
  ) {
    this.panelMotionState = panelMotionState;
    this.bottomChromePresentation = bottomChromePresentation;
    this.actionSnapshot = actionSnapshot;
    this.readingContinuation = readingContinuation;
    this.addressFocused = addressFocused;
    this.floatingHeaderVisible = floatingHeaderVisible;
    this.accountCapsule = accountCapsule;
  }
}

export const DEFAULT_BROWSER_BOTTOM_PANEL_LIVE_PRESENTATION: BrowserBottomPanelLivePresentation =
  new BrowserBottomPanelLivePresentation(
    DEFAULT_BROWSER_BOTTOM_PANEL_MOTION_STATE,
    DEFAULT_BROWSER_BOTTOM_CHROME_PRESENTATION
  );

export type BrowserBottomPanelPresentationListener = (presentation: BrowserBottomPanelLivePresentation) => void;

export class BrowserBottomPanelPresentationChannel {
  private presentation?: BrowserBottomPanelLivePresentation = undefined;
  private listener?: BrowserBottomPanelPresentationListener = undefined;

  publish(presentation: BrowserBottomPanelLivePresentation): void {
    this.presentation = presentation;
    if (this.listener !== undefined) {
      this.listener(presentation);
    }
  }

  current(): BrowserBottomPanelLivePresentation | undefined {
    return this.presentation;
  }

  connect(listener: BrowserBottomPanelPresentationListener): () => boolean {
    this.listener = listener;
    if (this.presentation !== undefined) {
      listener(this.presentation);
    }
    return (): boolean => {
      if (this.listener !== listener) {
        return false;
      }
      this.listener = undefined;
      return true;
    };
  }
}
