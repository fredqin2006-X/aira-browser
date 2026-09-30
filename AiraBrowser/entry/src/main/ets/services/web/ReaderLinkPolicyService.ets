export type ReaderLinkOpenKind = 'app_web' | 'external' | 'blocked';

export interface ReaderLinkOpenDecision {
  kind: ReaderLinkOpenKind;
  url: string;
  message: ResourceStr;
}

export class ReaderLinkPolicyService {
  resolve(url: string): ReaderLinkOpenDecision {
    const normalizedUrl = url.trim();
    if (normalizedUrl.length <= 0) {
      return {
        kind: 'blocked',
        url: '',
        message: $r('app.string.reader_link_empty')
      };
    }
    const scheme = this.getUrlScheme(normalizedUrl);
    if (scheme === 'http' || scheme === 'https') {
      return {
        kind: 'app_web',
        url: normalizedUrl,
        message: $r('app.string.reader_link_opening')
      };
    }
    if (scheme === 'mailto' || scheme === 'tel' || scheme === 'sms' || scheme === 'geo') {
      return {
        kind: 'external',
        url: normalizedUrl,
        message: $r('app.string.reader_link_system')
      };
    }
    if (scheme.length > 0) {
      return {
        kind: 'external',
        url: normalizedUrl,
        message: $r('app.string.reader_link_external_app')
      };
    }
    return {
      kind: 'blocked',
      url: normalizedUrl,
      message: $r('app.string.reader_link_unsupported')
    };
  }

  private getUrlScheme(url: string): string {
    const match = url.match(/^([a-z][a-z0-9+.-]*):/i);
    return match === null ? '' : match[1].toLowerCase();
  }
}
