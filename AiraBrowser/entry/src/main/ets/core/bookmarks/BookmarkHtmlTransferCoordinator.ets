import { common } from '@kit.AbilityKit';
import { AiraBookmarkImportApplyResult } from '../../common/models/AiraSyncModels';
import { BookmarkManagementFeature } from '../../features/bookmarks/BookmarkManagementFeature';
import { resolveAppResourceText } from '../resources/AppResourceText';
import {
  pickBookmarkOpenUri,
  pickBookmarkSaveUri,
  readBookmarkTextFromUri,
  resolveBookmarkFileTimestamp,
  writeBookmarkTextToUri
} from '../../services/bookmarks/BookmarkHtmlTransferApplicationService';

/**
 * Host ports for the staged bookmark HTML transfer. The page keeps the dialogs
 * and the refresh of its own surfaces; this coordinator owns only the file
 * pipeline and its progress staging.
 */
export class BookmarkHtmlTransferHost {
  pickerContext: () => common.UIAbilityContext = () => {
    throw new Error('BookmarkHtmlTransferHost.pickerContext is not bound.');
  };
  waitForProgressFrame: () => Promise<void> = () => Promise.resolve();
  beginTransfer: (title: ResourceStr, subtitle: ResourceStr) => void =
    (_title: ResourceStr, _subtitle: ResourceStr): void => {};
  updateTransfer: (title: ResourceStr, subtitle: ResourceStr, progress: number) => void =
    (_title: ResourceStr, _subtitle: ResourceStr, _progress: number): void => {};
  finishTransfer: (title: ResourceStr, subtitle: ResourceStr) => void =
    (_title: ResourceStr, _subtitle: ResourceStr): void => {};
  completeTransfer: () => void = (): void => {};
  refreshAfterImport: () => void = (): void => {};
  applyImportResult: (result: AiraBookmarkImportApplyResult) => void =
    (_result: AiraBookmarkImportApplyResult): void => {};
  showTransferSuccess: (title: ResourceStr, message: ResourceStr) => void =
    (_title: ResourceStr, _message: ResourceStr): void => {};
  showTransferFailure: (title: ResourceStr, message: ResourceStr) => void =
    (_title: ResourceStr, _message: ResourceStr): void => {};
  stringifyError: (error: Error) => string = (error: Error): string => error.message;
}

/**
 * Runs the picker -> read -> parse -> write -> refresh sequence for a bookmark
 * HTML import, and the export counterpart, reporting each stage through the
 * host so the page stays a UI shell.
 */
export class BookmarkHtmlTransferCoordinator {
  private readonly bookmarkManagementFeature: BookmarkManagementFeature;

  constructor(bookmarkManagementFeature: BookmarkManagementFeature) {
    this.bookmarkManagementFeature = bookmarkManagementFeature;
  }

  importHtml(host: BookmarkHtmlTransferHost): Promise<void> {
    let importStage: ResourceStr = $r('app.string.history_import_stage_picker');
    return pickBookmarkOpenUri(host.pickerContext())
      .then((uri: string): Promise<void> => {
        if (uri.length <= 0) {
          return Promise.resolve();
        }
        host.beginTransfer($r('app.string.bookmark_importing'), $r('app.string.bookmark_import_reading'));
        return host.waitForProgressFrame()
          .then((): Promise<string> => {
            importStage = $r('app.string.history_import_stage_read');
            host.updateTransfer($r('app.string.bookmark_importing'), $r('app.string.bookmark_import_reading'), 18);
            return readBookmarkTextFromUri(uri);
          })
          .then((payload: string): Promise<string> => {
            importStage = $r('app.string.bookmark_import_stage_parse');
            host.updateTransfer($r('app.string.bookmark_importing'), $r('app.string.bookmark_import_checking'), 36);
            return host.waitForProgressFrame().then((): string => payload);
          })
          .then((payload: string): Promise<AiraBookmarkImportApplyResult> => {
            importStage = $r('app.string.bookmark_import_stage_write');
            host.updateTransfer($r('app.string.bookmark_importing'), $r('app.string.bookmark_import_writing'), 68);
            return host.waitForProgressFrame()
              .then((): Promise<AiraBookmarkImportApplyResult> => this.bookmarkManagementFeature.applyHtmlImport(payload));
          })
          .then((result: AiraBookmarkImportApplyResult): void => {
            importStage = $r('app.string.bookmark_import_stage_refresh');
            host.updateTransfer($r('app.string.bookmark_importing'), $r('app.string.bookmark_import_refreshing'), 88);
            host.refreshAfterImport();
            host.applyImportResult(result);
            host.finishTransfer($r('app.string.history_import_success'), result.summary);
          });
      })
      .catch((error: Error): void => {
        host.completeTransfer();
        host.showTransferFailure(
          $r('app.string.history_import_failed'),
          $r('app.string.history_import_failed_detail', resolveAppResourceText(importStage), host.stringifyError(error))
        );
      });
  }

  exportHtml(host: BookmarkHtmlTransferHost): Promise<void> {
    const fileName = `aira-bookmarks-${resolveBookmarkFileTimestamp()}.html`;
    return pickBookmarkSaveUri(host.pickerContext(), fileName)
      .then((uri: string): Promise<void> => {
        if (uri.length <= 0) {
          return Promise.resolve();
        }
        const payload = this.bookmarkManagementFeature.buildHtmlExport();
        return writeBookmarkTextToUri(uri, payload).then((): void => {
          host.showTransferSuccess($r('app.string.history_export_success'), $r('app.string.bookmark_export_done'));
        });
      })
      .catch((error: Error): void => {
        host.showTransferFailure(
          $r('app.string.history_export_failed'),
          $r('app.string.bookmark_export_failed_detail', host.stringifyError(error))
        );
      });
  }
}
