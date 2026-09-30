import { pasteboard } from '@kit.BasicServicesKit';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';

export interface BrowserClipboardCopyResult {
  ok: boolean;
  message: string;
}

export interface BrowserClipboardCopyTextRequest {
  value: string;
  emptyMessage: ResourceStr;
  successMessage: ResourceStr;
  failureMessage?: ResourceStr;
}

export interface BrowserClipboardReadTextResult {
  ok: boolean;
  value: string;
  message: string;
}

export interface BrowserClipboardReadTextRequest {
  emptyMessage: string;
  failureMessage?: string;
}

export class BrowserClipboardService {
  async copyText(request: BrowserClipboardCopyTextRequest): Promise<BrowserClipboardCopyResult> {
    if (request.value.length === 0) {
      return {
        ok: false,
        message: resolveAppResourceText(request.emptyMessage)
      };
    }

    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, request.value);
      await pasteboard.getSystemPasteboard().setData(data);
      return {
        ok: true,
        message: resolveAppResourceText(request.successMessage)
      };
    } catch (_error) {
      return {
        ok: false,
        message: resolveAppResourceText(request.failureMessage ?? $r('app.string.ui_copy_failed'))
      };
    }
  }

  async readText(request: BrowserClipboardReadTextRequest): Promise<BrowserClipboardReadTextResult> {
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      const value = data.getPrimaryText();
      if (value.trim().length === 0) {
        return {
          ok: false,
          value: '',
          message: request.emptyMessage
        };
      }
      return {
        ok: true,
        value: value,
        message: ''
      };
    } catch (_error) {
      return {
        ok: false,
        value: '',
        message: request.failureMessage ?? '读取剪贴板失败，请稍后重试。'
      };
    }
  }
}
