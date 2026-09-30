import {
  OfflinePageManifest,
  OfflinePageOpenResult,
  OfflinePageViewerState
} from '../../common/models/OfflinePageModels';
import { OfflinePageFileStore } from '../../data/offline/OfflinePageFileStore';
import { OfflinePageManifestCodec } from '../../data/offline/OfflinePageManifestCodec';
import { OfflinePageRepository } from '../../data/offline/OfflinePageRepository';
import { OfflinePageHtmlSanitizerService } from '../../services/offline/OfflinePageHtmlSanitizerService';
import { BrowserPrivacyEffectPolicyService } from '../../services/privacy/BrowserPrivacyEffectPolicyService';
import { BrowserProfileBoundaryService } from '../browser/BrowserProfileBoundaryService';
import { resolveAppResourceText } from '../resources/AppResourceText';

export interface OfflinePageOpenCoordinatorOptions {
  repository: OfflinePageRepository;
  fileStore?: OfflinePageFileStore;
  manifestCodec?: OfflinePageManifestCodec;
  htmlSanitizer?: OfflinePageHtmlSanitizerService;
  privacyEffectPolicy?: BrowserPrivacyEffectPolicyService;
  profileBoundaryService?: BrowserProfileBoundaryService;
}

export class OfflinePageOpenCoordinator {
  private repository: OfflinePageRepository;
  private fileStore: OfflinePageFileStore;
  private manifestCodec: OfflinePageManifestCodec;
  private htmlSanitizer: OfflinePageHtmlSanitizerService;
  private privacyEffectPolicy: BrowserPrivacyEffectPolicyService;
  private profileBoundaryService: BrowserProfileBoundaryService;

  constructor(options: OfflinePageOpenCoordinatorOptions) {
    this.repository = options.repository;
    this.fileStore = options.fileStore ?? new OfflinePageFileStore();
    this.manifestCodec = options.manifestCodec ?? new OfflinePageManifestCodec();
    this.htmlSanitizer = options.htmlSanitizer ?? new OfflinePageHtmlSanitizerService();
    this.privacyEffectPolicy = options.privacyEffectPolicy ?? new BrowserPrivacyEffectPolicyService();
    this.profileBoundaryService = options.profileBoundaryService ?? new BrowserProfileBoundaryService();
  }

  buildLoadingState(pageId: string): OfflinePageViewerState {
    return {
      loading: true,
      canOpen: false,
      pageId: pageId,
      title: resolveAppResourceText($r('app.string.offline_page_title')),
      siteName: resolveAppResourceText($r('app.string.offline_page_site')),
      host: '',
      originalUrl: '',
      savedAt: 0,
      updatedAt: 0,
      totalBytes: 0,
      resourceCount: 0,
      failedResourceCount: 0,
      saveStatus: 'saving',
      openStatus: 'corrupted',
      html: '',
      archiveUri: '',
      contentKind: 'html',
      message: $r('app.string.offline_open_loading')
    };
  }

  buildFailureState(pageId: string, message: ResourceStr): OfflinePageViewerState {
    return {
      loading: false,
      canOpen: false,
      pageId: pageId,
      title: resolveAppResourceText($r('app.string.offline_page_title')),
      siteName: resolveAppResourceText($r('app.string.offline_page_site')),
      host: '',
      originalUrl: '',
      savedAt: 0,
      updatedAt: 0,
      totalBytes: 0,
      resourceCount: 0,
      failedResourceCount: 0,
      saveStatus: 'failed',
      openStatus: 'corrupted',
      html: '',
      archiveUri: '',
      contentKind: 'html',
      message: message
    };
  }

  async open(pageId: string, dataScope: string, privacyMode: string): Promise<OfflinePageOpenResult> {
    const decision = this.privacyEffectPolicy.decide({
      intent: 'regular_profile_management_read',
      requestingBoundary: this.profileBoundaryService.buildBoundary({
        dataScope: dataScope,
        privacyMode: privacyMode
      }),
      targetScope: 'regular_profile_data',
      targetIsClear: true
    });
    if (decision.outcome !== 'allow') {
      return this.buildFailure($r('app.string.offline_list_blocked'));
    }
    const normalizedId = pageId.trim();
    if (normalizedId.length === 0) {
      return this.buildFailure($r('app.string.offline_open_missing'));
    }
    try {
      await this.repository.initialize();
      const record = await this.repository.findById(normalizedId);
      if (record === undefined) {
        return this.buildFailure($r('app.string.offline_page_not_found'));
      }
      const manifest = await this.readManifest(record.manifestPath);
      if (manifest?.contentKind === 'web_archive') {
        const htmlSnapshotPath = this.resolveSiblingPath(record.snapshotPath, 'snapshot.html');
        if (await this.fileStore.textFileAvailable(htmlSnapshotPath)) {
          const html = await this.fileStore.readText(htmlSnapshotPath);
          if (html.trim().length > 0) {
            return {
              ok: true,
              message: '',
              record: record,
              html: this.htmlSanitizer.normalizeForViewer(html),
              archiveUri: '',
              contentKind: 'html'
            };
          }
        }
        if (!await this.fileStore.textFileAvailable(record.snapshotPath)) {
          return this.buildFailure($r('app.string.offline_open_archive_missing'));
        }
        return {
          ok: true,
          message: '',
          record: record,
          html: '',
          archiveUri: this.fileStore.toFileUri(record.snapshotPath),
          contentKind: 'web_archive'
        };
      }
      const html = await this.fileStore.readText(record.snapshotPath);
      if (html.trim().length === 0) {
        return this.buildFailure($r('app.string.offline_open_content_empty'));
      }
      return {
        ok: true,
        message: '',
        record: record,
        html: this.htmlSanitizer.normalizeForViewer(html),
        archiveUri: '',
        contentKind: 'html'
      };
    } catch (_error) {
      return this.buildFailure($r('app.string.offline_open_failed'));
    }
  }

  buildViewerState(result: OfflinePageOpenResult, pageId: string): OfflinePageViewerState {
    if (!result.ok || result.record === undefined) {
      return this.buildFailureState(pageId, result.message);
    }
    return {
      loading: false,
      canOpen: true,
      pageId: result.record.id,
      title: result.record.title,
      siteName: result.record.siteName,
      host: result.record.host,
      originalUrl: result.record.originalUrl,
      savedAt: result.record.savedAt,
      updatedAt: result.record.updatedAt,
      totalBytes: result.record.totalBytes,
      resourceCount: result.record.resourceCount,
      failedResourceCount: result.record.failedResourceCount,
      saveStatus: result.record.saveStatus,
      openStatus: result.record.openStatus,
      html: result.html,
      archiveUri: result.archiveUri,
      contentKind: result.contentKind,
      message: ''
    };
  }

  private async readManifest(path: string): Promise<OfflinePageManifest | undefined> {
    try {
      return this.manifestCodec.decode(await this.fileStore.readText(path));
    } catch (_error) {
      return undefined;
    }
  }

  private resolveSiblingPath(path: string, fileName: string): string {
    const normalizedPath = path.trim();
    const index = normalizedPath.lastIndexOf('/');
    if (index <= 0) {
      return fileName;
    }
    return `${normalizedPath.substring(0, index)}/${fileName}`;
  }

  private buildFailure(message: ResourceStr): OfflinePageOpenResult {
    return {
      ok: false,
      message: message,
      html: '',
      archiveUri: '',
      contentKind: 'html'
    };
  }
}
