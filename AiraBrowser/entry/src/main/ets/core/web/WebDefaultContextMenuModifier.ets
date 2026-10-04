import deviceInfo from '@ohos.deviceInfo';

const WEB_DEFAULT_CONTEXT_MENU_MIN_API_VERSION: number = 24;
const WEB_FORCE_ZOOM_MIN_API_VERSION: number = 21;

interface WebDefaultContextMenuAttribute {
  enableDefaultContextMenu?: (enable: boolean) => void;
}

interface WebForceZoomAttribute {
  forceEnableZoom?: (enable: boolean) => void;
}

export interface BrowserWebAttributeModifierOptions {
  forceEnableWebZoom?: boolean;
  enableDefaultContextMenu?: boolean;
  onInterceptRequest?: (event: OnInterceptRequestEvent) => WebResourceResponse | null;
}

export class BrowserWebAttributeModifier implements AttributeModifier<WebAttribute> {
  private readonly forceEnableWebZoom: boolean;
  private readonly enableDefaultContextMenu: boolean;
  private readonly onInterceptRequest?: (event: OnInterceptRequestEvent) => WebResourceResponse | null;

  constructor(options?: BrowserWebAttributeModifierOptions) {
    this.forceEnableWebZoom = options?.forceEnableWebZoom === true;
    this.enableDefaultContextMenu = options?.enableDefaultContextMenu !== false;
    this.onInterceptRequest = options?.onInterceptRequest;
  }

  applyNormalAttribute(instance: WebAttribute): void {
    this.applyDefaultContextMenuAttribute(instance);
    this.applyForceZoomAttribute(instance);
    if (this.onInterceptRequest !== undefined) {
      instance.onInterceptRequest(this.onInterceptRequest);
    }
  }

  private applyDefaultContextMenuAttribute(instance: WebAttribute): void {
    if (deviceInfo.sdkApiVersion < WEB_DEFAULT_CONTEXT_MENU_MIN_API_VERSION) {
      return;
    }
    const attribute = instance as object as WebDefaultContextMenuAttribute;
    if (attribute.enableDefaultContextMenu === undefined) {
      return;
    }
    try {
      attribute.enableDefaultContextMenu(this.enableDefaultContextMenu);
    } catch (_error) {
    }
  }

  private applyForceZoomAttribute(instance: WebAttribute): void {
    if (deviceInfo.sdkApiVersion < WEB_FORCE_ZOOM_MIN_API_VERSION) {
      return;
    }
    const attribute = instance as object as WebForceZoomAttribute;
    if (attribute.forceEnableZoom === undefined) {
      return;
    }
    try {
      attribute.forceEnableZoom(this.forceEnableWebZoom);
    } catch (_error) {
    }
  }
}

export const WEB_DEFAULT_CONTEXT_MENU_MODIFIER: BrowserWebAttributeModifier = new BrowserWebAttributeModifier();
