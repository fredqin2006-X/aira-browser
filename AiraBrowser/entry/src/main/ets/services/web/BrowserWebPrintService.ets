import { common } from '@kit.AbilityKit';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';
import { BusinessError, print } from '@kit.BasicServicesKit';
import { webview } from '@kit.ArkWeb';
import { BrowserRuntimeLifecyclePort } from './BrowserRuntimeLifecyclePort';

export interface BrowserWebPrintRequest {
  controller: webview.WebviewController;
  context: common.UIAbilityContext;
  title: string;
  printBackground: boolean;
  onStatusMessage?: (message: string) => void;
}

export interface BrowserWebPrintFromLifecyclePortRequest {
  runtimeLifecyclePort: BrowserRuntimeLifecyclePort;
  context: common.UIAbilityContext;
  title: string;
  printBackground: boolean;
  onStatusMessage?: (message: string) => void;
}

export interface BrowserWebPrintAvailabilityFacts {
  runtimeLifecyclePort: BrowserRuntimeLifecyclePort;
  showHomePage: boolean;
  showTabsSheet: boolean;
  webPageVisible: boolean;
}

export interface BrowserWebPrintResult {
  ok: boolean;
  message: string;
  code?: number;
}

const DEFAULT_WEB_PRINT_JOB_NAME = 'Aira Web Page';
const MAX_WEB_PRINT_JOB_NAME_LENGTH = 80;

export class BrowserWebPrintService {
  canPrintCurrentPage(facts: BrowserWebPrintAvailabilityFacts): boolean {
    return !facts.showHomePage && !facts.showTabsSheet && facts.webPageVisible &&
      facts.runtimeLifecyclePort.resolveActiveController() !== undefined;
  }

  async printCurrentPageFromLifecyclePort(
    request: BrowserWebPrintFromLifecyclePortRequest
  ): Promise<BrowserWebPrintResult> {
    const controller = request.runtimeLifecyclePort.resolveActiveController();
    if (controller === undefined) {
      return {
        ok: false,
        message: resolveAppResourceText($r('app.string.browser_browser_keyboard_shortcut_coordinator_025'))
      };
    }
    return await this.printCurrentPage({
      controller: controller,
      context: request.context,
      title: request.title,
      printBackground: request.printBackground,
      onStatusMessage: request.onStatusMessage
    });
  }

  async printCurrentPage(request: BrowserWebPrintRequest): Promise<BrowserWebPrintResult> {
    let adapter: print.PrintDocumentAdapter;
    try {
      request.controller.setPrintBackground(request.printBackground);
      adapter = request.controller.createWebPrintDocumentAdapter(this.resolveJobName(request.title));
    } catch (error) {
      return this.buildFailureResult(error, resolveAppResourceText($r('app.string.print_cannot_create')));
    }

    try {
      const attributes: print.PrintAttributes = {};
      const task: print.PrintTask = await print.print(this.resolveJobName(request.title), adapter, attributes,
        request.context);
      task.on('succeed', () => {
        request.onStatusMessage?.(resolveAppResourceText($r('app.string.print_done')));
      });
      task.on('fail', () => {
        request.onStatusMessage?.(resolveAppResourceText($r('app.string.print_failed')));
      });
      task.on('cancel', () => {
        request.onStatusMessage?.(resolveAppResourceText($r('app.string.print_canceled')));
      });
      task.on('block', () => {
        request.onStatusMessage?.(resolveAppResourceText($r('app.string.print_blocked')));
      });
      return {
        ok: true,
        message: resolveAppResourceText($r('app.string.print_opening'))
      };
    } catch (error) {
      return this.buildFailureResult(error, resolveAppResourceText($r('app.string.print_cannot_start')));
    }
  }

  private resolveJobName(title: string): string {
    const normalized = title.trim().replace(/\s+/g, ' ');
    if (normalized.length <= 0) {
      return DEFAULT_WEB_PRINT_JOB_NAME;
    }
    if (normalized.length <= MAX_WEB_PRINT_JOB_NAME_LENGTH) {
      return normalized;
    }
    return normalized.substring(0, MAX_WEB_PRINT_JOB_NAME_LENGTH);
  }

  private buildFailureResult(error: Object, fallbackMessage: string): BrowserWebPrintResult {
    const businessError = error as BusinessError;
    if (businessError?.code === 201) {
      return {
        ok: false,
        message: resolveAppResourceText($r('app.string.print_permission')),
        code: businessError.code
      };
    }
    return {
      ok: false,
      message: fallbackMessage,
      code: businessError?.code
    };
  }
}
