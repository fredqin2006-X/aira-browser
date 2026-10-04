/**
 * ArkWeb's `onInterceptRequest` can only replace a request with one finished body. An EventSource
 * (`text/event-stream`) stays open and delivers chunks; handing that request to the callback makes
 * the renderer wait until the connection ends, which is the multi-second freeze on search pages.
 * Huawei's browser does not intercept these, so the kernel keeps the stream. Match them here and
 * return null before ad blocking or media discovery touches the request.
 */
export class BrowserWebStreamingRequestBypass {
  static shouldLeaveToKernel(url: string, acceptHeader: string): boolean {
    if (BrowserWebStreamingRequestBypass.isEventStreamUrl(url)) {
      return true;
    }
    return BrowserWebStreamingRequestBypass.acceptsEventStream(acceptHeader);
  }

  static isEventStreamUrl(url: string): boolean {
    const path = BrowserWebStreamingRequestBypass.pathWithoutQuery(url).toLowerCase();
    return path.endsWith('/stream') || path.endsWith('/stream/');
  }

  static acceptsEventStream(acceptHeader: string): boolean {
    return acceptHeader.toLowerCase().indexOf('text/event-stream') >= 0;
  }

  private static pathWithoutQuery(url: string): string {
    const trimmed = url.trim();
    if (trimmed.length <= 0) {
      return '';
    }
    const query = trimmed.indexOf('?');
    const hash = trimmed.indexOf('#');
    let end = trimmed.length;
    if (query >= 0 && query < end) {
      end = query;
    }
    if (hash >= 0 && hash < end) {
      end = hash;
    }
    return trimmed.substring(0, end);
  }
}
