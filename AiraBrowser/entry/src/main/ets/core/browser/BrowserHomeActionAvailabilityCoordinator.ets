import {
  BrowserBottomPanelActionCatalog,
  BrowserBottomPanelActionId
} from './BrowserBottomPanelActionCatalog';
import { bottomPanelHomeUnavailable } from './BrowserBottomPanelText';

export interface BrowserHomeActionAvailabilityResult {
  available: boolean;
  message: ResourceStr;
}

export class BrowserHomeActionAvailabilityCoordinator {
  resolve(actionId: BrowserBottomPanelActionId): BrowserHomeActionAvailabilityResult {
    if (this.isAvailableOnHome(actionId)) {
      return {
        available: true,
        message: ''
      };
    }
    return {
      available: false,
      message: this.resolveUnavailableMessage(actionId)
    };
  }

  private isAvailableOnHome(actionId: BrowserBottomPanelActionId): boolean {
    return BrowserBottomPanelActionCatalog.entry(actionId).surfaces.includes('home');
  }

  private resolveUnavailableMessage(actionId: BrowserBottomPanelActionId): ResourceStr {
    return bottomPanelHomeUnavailable(actionId);
  }
}
