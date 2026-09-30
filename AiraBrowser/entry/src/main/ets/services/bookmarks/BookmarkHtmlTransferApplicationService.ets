import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import buffer from '@ohos.buffer';
import { BookmarkManagementFeature } from '../../features/bookmarks/BookmarkManagementFeature';

export interface BookmarkHtmlTransferApplicationResult {
  completed: boolean;
  cancelled: boolean;
  title: ResourceStr;
  message: ResourceStr;
}

/** Platform boundary for bookmark HTML picker and file IO. */
export class BookmarkHtmlTransferApplicationService {
  private readonly bookmarkManagementFeature: BookmarkManagementFeature;

  constructor(bookmarkManagementFeature: BookmarkManagementFeature) {
    this.bookmarkManagementFeature = bookmarkManagementFeature;
  }

  async importHtml(context: common.UIAbilityContext): Promise<BookmarkHtmlTransferApplicationResult> {
    try {
      const uri = await pickBookmarkOpenUri(context);
      if (uri.length <= 0) {
        return this.cancelledResult($r('app.string.bookmark_import_cancelled'));
      }
      const payload = await readBookmarkTextFromUri(uri);
      const result = await this.bookmarkManagementFeature.applyHtmlImport(payload);
      return {
        completed: true,
        cancelled: false,
        title: $r('app.string.history_import_success'),
        message: result.summary
      };
    } catch (error) {
      return this.failureResult($r('app.string.history_import_failed'), error as Error);
    }
  }

  async exportHtml(context: common.UIAbilityContext): Promise<BookmarkHtmlTransferApplicationResult> {
    try {
      const uri = await pickBookmarkSaveUri(context, `aira-bookmarks-${resolveBookmarkFileTimestamp()}.html`);
      if (uri.length <= 0) {
        return this.cancelledResult($r('app.string.bookmark_export_cancelled'));
      }
      await this.bookmarkManagementFeature.refresh();
      const payload = this.bookmarkManagementFeature.buildHtmlExport();
      await writeBookmarkTextToUri(uri, payload);
      return {
        completed: true,
        cancelled: false,
        title: $r('app.string.history_export_success'),
        message: $r('app.string.bookmark_export_done')
      };
    } catch (error) {
      return this.failureResult($r('app.string.history_export_failed'), error as Error);
    }
  }

  private cancelledResult(message: ResourceStr): BookmarkHtmlTransferApplicationResult {
    return {
      completed: false,
      cancelled: true,
      title: '',
      message: message
    };
  }

  private failureResult(title: ResourceStr, error: Error): BookmarkHtmlTransferApplicationResult {
    return {
      completed: false,
      cancelled: false,
      title: title,
      message: error.message.length > 0 ? error.message : $r('app.string.ui_unknown_error')
    };
  }
}

/**
 * Pick an existing bookmark HTML document. Shared by the manager page staged
 * import flow and the all-in-one application service so both stay in step.
 */
export async function pickBookmarkOpenUri(context: common.UIAbilityContext): Promise<string> {
  const documentPicker = new picker.DocumentViewPicker(context);
  const uris = await documentPicker.select({
    maxSelectNumber: 1,
    fileSuffixFilters: ['.html', '.htm']
  });
  return uris.length > 0 ? uris[0] : '';
}

/** Pick the destination for a bookmark HTML export. */
export async function pickBookmarkSaveUri(context: common.UIAbilityContext, fileName: string): Promise<string> {
  const documentPicker = new picker.DocumentViewPicker(context);
  const uris = await documentPicker.save({
    newFileNames: [fileName],
    fileSuffixChoices: ['HTML|.html']
  });
  return uris.length > 0 ? uris[0] : '';
}

/** Write the exported HTML payload to a picked document URI. */
export async function writeBookmarkTextToUri(uri: string, payload: string): Promise<void> {
  const file = await fileIo.open(uri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
  try {
    await fileIo.write(file.fd, payload);
  } finally {
    await fileIo.close(file);
  }
}

/** Timestamp segment for the default bookmark export file name. */
export function resolveBookmarkFileTimestamp(): string {
  return new Date().toISOString()
    .replace(/[:.]/g, '-')
    .replace('T', '_')
    .replace('Z', '');
}

/** Read the complete UTF-8 byte stream before decoding so chunk boundaries cannot corrupt text. */
export async function readBookmarkTextFromUri(uri: string): Promise<string> {
  const file = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  const chunkSize = 64 * 1024;
  try {
    let bytesRead = 0;
    do {
      const data = new ArrayBuffer(chunkSize);
      bytesRead = await fileIo.read(file.fd, data);
      if (bytesRead > 0) {
        const chunk = new Uint8Array(bytesRead);
        chunk.set(new Uint8Array(data, 0, bytesRead));
        chunks.push(chunk);
        totalBytes += bytesRead;
      }
    } while (bytesRead > 0);
  } finally {
    await fileIo.close(file);
  }
  if (totalBytes === 0) {
    return '';
  }
  const merged = new Uint8Array(totalBytes);
  let offset = 0;
  chunks.forEach((chunk: Uint8Array): void => {
    merged.set(chunk, offset);
    offset += chunk.byteLength;
  });
  return buffer.from(merged.buffer, merged.byteOffset, merged.byteLength).toString('utf8');
}
