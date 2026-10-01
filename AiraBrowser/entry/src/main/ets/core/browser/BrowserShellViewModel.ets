import { resolveAppResourceText } from '../resources/AppResourceText';
import { BrowserTabState } from '../tabs/TabManager';

export type BrowserRuntimeTone = 'primary' | 'secondary' | 'warning';

export interface BrowserTabRuntimePresentation {
  label: string;
  helperMessage: string;
  tone: BrowserRuntimeTone;
  evidenceLine: string;
}

export interface BrowserTabRuntimeEvidenceInput {
  retentionReason?: string;
  retentionScore?: number;
  restorePriority?: number;
  isWebStateRestoreCandidate?: boolean;
  hasLiveController?: boolean;
}

export class BrowserShellViewModel {
  resolveLiveRuntimeHelperMessage(
    tab: BrowserTabState,
    activeTabId: string,
    helperMessage: string
  ): string {
    if (helperMessage.length > 0) {
      return helperMessage;
    }
    return this.getTabRuntimePresentation(tab, activeTabId).helperMessage;
  }

  getTabRuntimePresentation(
    tab: BrowserTabState,
    activeTabId: string,
    evidence: BrowserTabRuntimeEvidenceInput = {}
  ): BrowserTabRuntimePresentation {
    return {
      label: this.getRuntimeLabel(tab, activeTabId),
      helperMessage: this.getRuntimeHelperMessage(tab),
      tone: this.getRuntimeTone(tab),
      evidenceLine: this.buildTabRuntimeEvidenceLine(tab, activeTabId, evidence)
    };
  }

  buildTabRuntimeEvidenceLine(
    tab: BrowserTabState,
    activeTabId: string,
    evidence: BrowserTabRuntimeEvidenceInput = {}
  ): string {
    const isWebStateRestoreCandidate = evidence.isWebStateRestoreCandidate ?? false;
    const hasLiveController = evidence.hasLiveController ?? false;
    const retentionReason = this.normalizeEvidenceValue(evidence.retentionReason ?? '');
    const retentionScore = evidence.retentionScore ?? 0;
    const restorePriority = evidence.restorePriority ?? 0;
    return `tabRuntime tab=${tab.id} active=${tab.id === activeTabId ? 'true' : 'false'} state=${tab.runtimeState} ` +
      `discard=${tab.lastDiscardReason.length > 0 ? tab.lastDiscardReason : 'none'} webStateRestoreCandidate=${isWebStateRestoreCandidate ? 'true' : 'false'} ` +
      `live=${hasLiveController ? 'true' : 'false'} score=${retentionScore} restorePriority=${restorePriority} ` +
      `reason=${retentionReason.length > 0 ? retentionReason : 'none'}`;
  }

  private normalizeEvidenceValue(value: string): string {
    return value.trim().split(' ').join('_');
  }

  private getRuntimeLabel(tab: BrowserTabState, activeTabId: string): string {
    switch (tab.runtimeState) {
      case 'active':
        return tab.id === activeTabId ? resolveAppResourceText($r('app.string.tab_runtime_active')) : resolveAppResourceText($r('app.string.tab_runtime_ready'));
      case 'background-hot':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_002'));
      case 'background-warm':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_004'));
      case 'cold':
        if (tab.lastDiscardReason === 'retention_stale') {
          return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_012'));
        }
        if (tab.lastDiscardReason === 'retention_budget' || tab.lastDiscardReason === 'retention_cold') {
          return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_007'));
        }
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_006'));
      case 'discarded':
        if (tab.lastDiscardReason === 'retention_stale' || tab.lastDiscardReason === 'retention_budget' ||
          tab.lastDiscardReason === 'retention_cold') {
          return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_010'));
        }
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_009'));
      case 'crashed':
        return this.getCrashLabel(tab);
      case 'loading':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_034'));
      case 'restoring':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_039'));
      case 'error':
        return tab.lastError.length > 0
          ? resolveAppResourceText($r('app.string.tab_runtime_load_failed_detail', tab.lastError))
          : resolveAppResourceText($r('app.string.history_load_failed'));
      case 'background':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_003'));
      case 'suspended':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_011'));
      default:
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_043'));
    }
  }

  private getRuntimeHelperMessage(tab: BrowserTabState): string {
    switch (tab.runtimeState) {
      case 'restoring':
        return this.getRestoreHelperMessage(tab);
      case 'loading':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_025'));
      case 'error':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_016'));
      case 'background-hot':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_017'));
      case 'background-warm':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_023'));
      case 'cold':
        if (tab.lastDiscardReason === 'retention_stale') {
          return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_030'));
        }
        if (tab.lastDiscardReason === 'retention_budget') {
          return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_027'));
        }
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_020'));
      case 'discarded':
        if (tab.lastDiscardReason === 'retention_stale') {
          return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_018'));
        }
        if (tab.lastDiscardReason === 'retention_budget' || tab.lastDiscardReason === 'retention_cold') {
          return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_021'));
        }
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_022'));
      case 'crashed':
        return this.getCrashHelperMessage(tab);
      case 'suspended':
      case 'background':
      case 'active':
      default:
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_008'));
    }
  }

  private getRuntimeTone(tab: BrowserTabState): BrowserRuntimeTone {
    if (tab.runtimeState === 'error' || tab.runtimeState === 'crashed') {
      return 'warning';
    }
    if (tab.runtimeState === 'active' || tab.runtimeState === 'loading' || tab.runtimeState === 'restoring') {
      return 'primary';
    }
    return 'secondary';
  }

  private getRestoreHelperMessage(tab: BrowserTabState): string {
    switch (tab.lastRestoreReason) {
      case 'controller_attach':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_015'));
      case 'tab_switch':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_033'));
      case 'discard_restore':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_037'));
      case 'crash_restore':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_031'));
      case 'snapshot_restore':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_032'));
      case 'snapshot_fallback_reload':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_013'));
      case 'cold_start':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_036'));
      case 'manual_reload':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_040'));
      case 'external_launch':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_035'));
      default:
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_038'));
    }
  }

  private getCrashLabel(tab: BrowserTabState): string {
    switch (tab.lastCrashReason) {
      case 'snapshot_restore_failed':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_014'));
      case 'navigation_failed':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_005'));
      case 'render_process_terminated':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_041'));
      default:
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_042'));
    }
  }

  private getCrashHelperMessage(tab: BrowserTabState): string {
    switch (tab.lastCrashReason) {
      case 'snapshot_restore_failed':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_024'));
      case 'navigation_failed':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_019'));
      case 'render_process_terminated':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_026'));
      case 'main_frame_error':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_001'));
      case 'recovery_degraded_to_home':
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_029'));
      default:
        return resolveAppResourceText($r('app.string.browser_browser_shell_view_model_028'));
    }
  }
}
