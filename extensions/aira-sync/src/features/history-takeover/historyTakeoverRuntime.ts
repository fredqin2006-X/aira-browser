import {
  HISTORY_TAKEOVER_OPEN_MESSAGE,
  detectHistoryPlatform,
  extensionHistoryCommandShortcuts,
  readInstalledHistoryBrowser,
  shouldAssignExtensionHistoryShortcut,
} from './historyTakeoverPolicy';

const AIRA_OPEN_HISTORY_COMMAND = 'open-aira-history';

type HistoryCommandApi = {
  getAll?: () => Promise<Array<{ name?: string; shortcut?: string }>>;
  update?: (detail: { name: string; shortcut: string }) => Promise<void>;
};

export async function ensureExtensionHistoryShortcut(): Promise<void> {
  const browser = await readInstalledHistoryBrowser();
  const commands = globalThis.chrome?.commands as HistoryCommandApi | undefined;
  if (!commands?.getAll || !commands.update) return;
  const current = (await commands.getAll()).find((command) => command.name === AIRA_OPEN_HISTORY_COMMAND);
  if (!shouldAssignExtensionHistoryShortcut(browser, current?.shortcut || '')) return;
  const platform = detectHistoryPlatform(navigator.platform || '', navigator.userAgent || '');
  let lastError: unknown;
  for (const shortcut of extensionHistoryCommandShortcuts(platform)) {
    try {
      await commands.update({ name: AIRA_OPEN_HISTORY_COMMAND, shortcut });
      return;
    } catch (error) {
      lastError = error;
    }
  }
  if (lastError) throw lastError;
}

type HistoryTakeoverOpenMessage = {
  type?: unknown;
};

function isHistoryTakeoverOpenMessage(message: unknown): message is { type: typeof HISTORY_TAKEOVER_OPEN_MESSAGE } {
  return Boolean(message)
    && typeof message === 'object'
    && (message as HistoryTakeoverOpenMessage).type === HISTORY_TAKEOVER_OPEN_MESSAGE;
}

export async function openOrFocusAiraHistoryPage(): Promise<void> {
  const runtime = globalThis.chrome?.runtime;
  const tabs = globalThis.chrome?.tabs;
  const windows = globalThis.chrome?.windows;
  const historyUrl = runtime?.getURL?.('history.html');
  if (!historyUrl || !tabs?.create) return;

  try {
    const existing = tabs.query ? await tabs.query({ url: `${historyUrl}*` }) : [];
    const tab = existing.find((item) => typeof item.id === 'number');
    if (tab?.id != null) {
      await tabs.update(tab.id, { active: true });
      if (windows?.update && typeof tab.windowId === 'number') {
        await windows.update(tab.windowId, { focused: true });
      }
      return;
    }
  } catch {
    // Querying by extension URL can fail; creating a tab is the fallback.
  }

  await tabs.create({ url: historyUrl, active: true }).catch(() => undefined);
}

export function bindHistoryTakeoverRuntime(): void {
  globalThis.chrome?.runtime?.onMessage?.addListener((message, _sender, sendResponse) => {
    if (!isHistoryTakeoverOpenMessage(message)) return undefined;
    void openOrFocusAiraHistoryPage();
    sendResponse?.({ ok: true });
    return false;
  });
}
