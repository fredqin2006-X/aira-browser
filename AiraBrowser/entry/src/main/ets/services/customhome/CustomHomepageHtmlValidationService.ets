import { resolveAppResourceText } from '../../core/resources/AppResourceText';

interface CustomHomepageHtmlValidationInput {
  html: string;
  sourceLabel?: string;
}

interface CustomHomepageBlockedPattern {
  pattern: RegExp;
  message: () => string;
}



const CUSTOM_HOMEPAGE_REQUIRED_TAGS: string[] = [
  '<html',
  '<head',
  '<body'
];

const CUSTOM_HOMEPAGE_BLOCKED_PATTERNS: CustomHomepageBlockedPattern[] = [
  { pattern: /<iframe\b/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_iframe')) },
  { pattern: /<object\b/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_object')) },
  { pattern: /<embed\b/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_embed')) },
  { pattern: /<base\b/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_base')) },
  { pattern: /<meta[^>]+http-equiv\s*=\s*["']?refresh/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_refresh')) },
  { pattern: /\son[a-z]+\s*=/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_inline_event')) },
  { pattern: /\b(?:href|src|action|formaction)\s*=\s*["']?\s*javascript:/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_javascript_url')) },
  { pattern: /\b(?:href|src|action|formaction)\s*=\s*["']?\s*data:text\/html/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_data_html')) },
  { pattern: /navigator\.serviceworker/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_service_worker')) },
  { pattern: /serviceworker\s*\.\s*register/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_service_worker')) },
  { pattern: /register\s*\(\s*["'][^"']*service-worker/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_service_worker')) },
  { pattern: /\bfile:\/\//i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_file_url')) },
  { pattern: /<script[^>]+src\s*=\s*["']https?:\/\//i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_remote_script')) },
  { pattern: /\b(?:window\.)?location\s*\.\s*(?:href|assign|replace)\b/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_location')) },
  { pattern: /\bwindow\s*\.\s*open\s*\(/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_window_open')) },
  { pattern: /\bfetch\s*\(/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_network')) },
  { pattern: /\bXMLHttpRequest\b/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_network')) },
  { pattern: /\bnavigator\s*\.\s*sendBeacon\b/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_network')) },
  { pattern: /\bWebSocket\s*\(/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_network')) },
  { pattern: /\bEventSource\s*\(/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_html_no_network')) }
];

export class CustomHomepageHtmlValidationService {
  validateForImport(input: CustomHomepageHtmlValidationInput): void {
    const html = input.html.trim();
    if (html.length === 0) {
      throw new Error(resolveAppResourceText($r('app.string.custom_home_html_unavailable')));
    }
    this.ensureTextHtml(html);
    this.ensureDocumentShape(html);
    this.ensureSafeHtmlContent(html);
  }

  validateScriptAssetForImport(script: string): void {
    const source = script.trim();
    if (source.length === 0) {
      return;
    }
    this.ensureTextHtml(source);
    this.ensureSafeScriptContent(source);
  }

  looksLikeHtml(sample: string): boolean {
    const normalized = sample.trim().toLowerCase();
    if (normalized.length === 0) {
      return false;
    }
    return normalized.includes('<!doctype html') ||
      normalized.includes('<html') ||
      normalized.includes('<head') ||
      normalized.includes('<body');
  }

  private ensureTextHtml(html: string): void {
    if (/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/.test(html)) {
      throw new Error(resolveAppResourceText($r('app.string.custom_home_html_control_chars')));
    }
  }

  private ensureDocumentShape(html: string): void {
    const lower = html.toLowerCase();
    const hasDoctype = lower.includes('<!doctype html');
    for (let index = 0; index < CUSTOM_HOMEPAGE_REQUIRED_TAGS.length; index += 1) {
      if (!lower.includes(CUSTOM_HOMEPAGE_REQUIRED_TAGS[index])) {
        throw new Error(resolveAppResourceText($r('app.string.custom_home_html_structure')));
      }
    }
    if (!hasDoctype) {
      throw new Error(resolveAppResourceText($r('app.string.custom_home_html_doctype')));
    }
  }

  private ensureSafeHtmlContent(html: string): void {
    for (let index = 0; index < CUSTOM_HOMEPAGE_BLOCKED_PATTERNS.length; index += 1) {
      const blocked = CUSTOM_HOMEPAGE_BLOCKED_PATTERNS[index];
      if (blocked.pattern.test(html)) {
        throw new Error(blocked.message());
      }
    }
  }

  private ensureSafeScriptContent(script: string): void {
    const blockedPatterns: CustomHomepageBlockedPattern[] = [
      { pattern: /navigator\.serviceworker/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_script_no_service_worker')) },
      { pattern: /serviceworker\s*\.\s*register/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_script_no_service_worker')) },
      { pattern: /register\s*\(\s*["'][^"']*service-worker/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_script_no_service_worker')) },
      { pattern: /\bfile:\/\//i, message: (): string => resolveAppResourceText($r('app.string.custom_home_script_no_file_url')) },
      { pattern: /\b(?:window\.)?location\s*\.\s*(?:href|assign|replace)\b/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_script_no_location')) },
      { pattern: /\bwindow\s*\.\s*open\s*\(/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_script_no_window_open')) },
      { pattern: /\bfetch\s*\(/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_script_no_network')) },
      { pattern: /\bXMLHttpRequest\b/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_script_no_network')) },
      { pattern: /\bnavigator\s*\.\s*sendBeacon\b/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_script_no_network')) },
      { pattern: /\bWebSocket\s*\(/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_script_no_network')) },
      { pattern: /\bEventSource\s*\(/i, message: (): string => resolveAppResourceText($r('app.string.custom_home_script_no_network')) }
    ];
    for (let index = 0; index < blockedPatterns.length; index += 1) {
      const blocked = blockedPatterns[index];
      if (blocked.pattern.test(script)) {
        throw new Error(blocked.message());
      }
    }
  }
}
