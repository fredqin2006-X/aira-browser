import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { i18n } from '@kit.LocalizationKit';
import buffer from '@ohos.buffer';
import { BrowserWebLoadDataPayload } from '../../core/browser/BrowserWebLoadCoordinator';
import {
  MarkdownDocumentTheme,
  MarkdownDocumentViewerService
} from '../markdown/MarkdownDocumentViewerService';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';

const SYNC_DESKTOP_BOOKMARK_GUIDE_RAW_FILE_NAME_ZH: string = 'sync_desktop_bookmark_guide.md';
const SYNC_DESKTOP_BOOKMARK_GUIDE_RAW_FILE_NAME_EN: string = 'sync_desktop_bookmark_guide_en.md';
export const SYNC_DESKTOP_BOOKMARK_GUIDE_TITLE: ResourceStr =
  $r('app.string.settings_sync_self_host_guide_title');
const SYNC_DESKTOP_BOOKMARK_GUIDE_SOURCE_URL: string = 'https://aira.local/settings/sync-desktop-bookmark-guide.md';
const SYNC_DESKTOP_BOOKMARK_GUIDE_BASE_URL: string = 'https://aira.local/settings/';
const SYNC_DESKTOP_BOOKMARK_GUIDE_LOCAL_PACKAGE_URL: string = 'https://wwbgv.lanzoul.com/b00oe0qfcd';

interface SyncDesktopBookmarkGuideImagePlaceholder {
  placeholder: string;
  rawfileName: string;
}

export interface SyncDesktopBookmarkGuideLinkCopyResult {
  ok: boolean;
  message: string;
}

const SYNC_DESKTOP_BOOKMARK_GUIDE_IMAGES: SyncDesktopBookmarkGuideImagePlaceholder[] = [
  { placeholder: 'SYNC_DESKTOP_BOOKMARK_GUIDE_01_IMAGE', rawfileName: 'sync_desktop_bookmark_guide_01.png' },
  { placeholder: 'SYNC_DESKTOP_BOOKMARK_GUIDE_02_IMAGE', rawfileName: 'sync_desktop_bookmark_guide_02.png' },
  { placeholder: 'SYNC_DESKTOP_BOOKMARK_GUIDE_03_IMAGE', rawfileName: 'sync_desktop_bookmark_guide_03.png' },
  { placeholder: 'SYNC_DESKTOP_BOOKMARK_GUIDE_04_IMAGE', rawfileName: 'sync_desktop_bookmark_guide_04.png' },
  { placeholder: 'SYNC_DESKTOP_BOOKMARK_GUIDE_05_IMAGE', rawfileName: 'sync_desktop_bookmark_guide_05.png' }
];

export class SyncDesktopBookmarkGuideMarkdownService {
  private markdownViewerService: MarkdownDocumentViewerService = new MarkdownDocumentViewerService();

  async buildPayload(context: common.Context, theme?: MarkdownDocumentTheme): Promise<BrowserWebLoadDataPayload> {
    const markdown = this.applyImagePlaceholders(this.readMarkdown(context));
    return this.markdownViewerService.buildPayloadFromMarkdown({
      title: this.resolveGuideTitle(),
      sourceUri: SYNC_DESKTOP_BOOKMARK_GUIDE_SOURCE_URL,
      markdown: markdown,
      baseUrl: SYNC_DESKTOP_BOOKMARK_GUIDE_BASE_URL,
      historyUrl: SYNC_DESKTOP_BOOKMARK_GUIDE_SOURCE_URL,
      theme: theme
    });
  }

  shouldCopyGuideLink(url: string): boolean {
    const normalized = url.trim().toLowerCase();
    return normalized.startsWith('https://chromewebstore.google.com/') ||
      normalized.startsWith('https://microsoftedge.microsoft.com/addons/') ||
      normalized.startsWith('https://addons.mozilla.org/') ||
      normalized === SYNC_DESKTOP_BOOKMARK_GUIDE_LOCAL_PACKAGE_URL;
  }

  async copyGuideLink(url: string): Promise<SyncDesktopBookmarkGuideLinkCopyResult> {
    const normalizedUrl = url.trim();
    if (!this.shouldCopyGuideLink(normalizedUrl)) {
      return {
        ok: false,
        message: resolveAppResourceText($r('app.string.settings_sync_self_host_guide_link_unset'))
      };
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, normalizedUrl);
      await pasteboard.getSystemPasteboard().setData(data);
      return {
        ok: true,
        message: resolveAppResourceText($r('app.string.settings_sync_self_host_guide_link_copied'))
      };
    } catch (_error) {
      return {
        ok: false,
        message: resolveAppResourceText($r('app.string.settings_sync_self_host_guide_copy_failed'))
      };
    }
  }

  private readMarkdown(context: common.Context): string {
    try {
      const rawFile = context.resourceManager.getRawFileContentSync(this.resolveGuideRawFileName());
      return buffer.from(rawFile.buffer).toString('utf8');
    } catch (error) {
      return [
        `# ${this.resolveGuideTitle()}`,
        '',
        resolveAppResourceText(
          $r('app.string.settings_sync_self_host_guide_load_failed'),
          this.stringifyError(error)
        )
      ].join('\n');
    }
  }

  /**
   * rawfile 目录不参与资源限定词匹配，所以教程正文按系统语言显式挑文件：
   * 英文走英文正文，其余语言回落到 base 对应的中文正文，与 string.json 的兜底关系一致。
   */
  private resolveGuideRawFileName(): string {
    const language = i18n.System.getSystemLanguage().trim().toLowerCase();
    return language.startsWith('en')
      ? SYNC_DESKTOP_BOOKMARK_GUIDE_RAW_FILE_NAME_EN
      : SYNC_DESKTOP_BOOKMARK_GUIDE_RAW_FILE_NAME_ZH;
  }

  private resolveGuideTitle(): string {
    const title = SYNC_DESKTOP_BOOKMARK_GUIDE_TITLE;
    return typeof title === 'string' ? title : resolveAppResourceText(title);
  }

  private applyImagePlaceholders(markdown: string): string {
    let hydratedMarkdown = markdown;
    for (let index = 0; index < SYNC_DESKTOP_BOOKMARK_GUIDE_IMAGES.length; index += 1) {
      const image = SYNC_DESKTOP_BOOKMARK_GUIDE_IMAGES[index];
      const resourceUrl = `resource://rawfile/${image.rawfileName}`;
      hydratedMarkdown = hydratedMarkdown.replace(new RegExp(`\\{\\{${image.placeholder}\\}\\}`, 'g'), resourceUrl);
    }
    return hydratedMarkdown;
  }

  private stringifyError(error: Object | undefined): string {
    if (error instanceof Error && error.message.length > 0) {
      return error.message;
    }
    return JSON.stringify(error);
  }
}
