import { BrowserBottomPanelActionId } from './BrowserBottomPanelActionCatalog';

export interface BrowserBottomPanelActionEnablement {
  enabled: boolean;
  disabledMessage: ResourceStr;
}

export type BrowserBottomPanelActionEnablementById =
  Record<string, BrowserBottomPanelActionEnablement | undefined>;

export function resolveBrowserBottomPanelActionEnablement(
  enablementById: BrowserBottomPanelActionEnablementById,
  actionId: BrowserBottomPanelActionId,
  fallbackEnabled: boolean = true,
  fallbackDisabledMessage: ResourceStr = ''
): BrowserBottomPanelActionEnablement {
  return enablementById[actionId] ?? {
    enabled: fallbackEnabled,
    disabledMessage: fallbackDisabledMessage
  };
}
