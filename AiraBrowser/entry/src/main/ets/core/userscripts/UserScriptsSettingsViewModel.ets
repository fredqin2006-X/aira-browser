import {
  InstalledUserScriptState,
  UserScriptPackageCandidate
} from '../../features/userscripts/UserScriptMetadataModels';
import { UserScriptValueManagementProjection } from '../../features/userscripts/UserScriptValueModels';
import { UserScriptCapabilityContractService } from '../../services/userscripts/UserScriptCapabilityContractService';
import { UserScriptMatchService } from '../../services/userscripts/UserScriptMatchService';
import { resolveAppResourceText } from '../resources/AppResourceText';
import { USER_SCRIPT_SOURCE_OFFLINE_MESSAGE, USER_SCRIPT_SOURCE_UNREACHABLE_MESSAGE } from '../../services/userscripts/UserScriptSourceFetchService';

export interface UserScriptRowView {
  id: string;
  title: string;
  version: string;
  description: string;
  scopeSummary: string;
  iconUrl: string;
  enabled: boolean;
  canUpdate: boolean;
}

export const USER_SCRIPT_DESKTOP_CARD_MIN_WIDTH_VP: number = 300;
export const USER_SCRIPT_DESKTOP_CARD_GAP_VP: number = 16;
export const USER_SCRIPT_DESKTOP_MAX_COLUMNS: number = 4;

/** Column count for the PC script grid. Narrow panes stay one column; wide windows cap at four. */
export function resolveUserScriptDesktopColumnCount(contentWidthVp: number): number {
  if (!Number.isFinite(contentWidthVp) || contentWidthVp <= 0) {
    return 1;
  }
  const slotWidthVp = USER_SCRIPT_DESKTOP_CARD_MIN_WIDTH_VP + USER_SCRIPT_DESKTOP_CARD_GAP_VP;
  const columnCount = Math.floor((contentWidthVp + USER_SCRIPT_DESKTOP_CARD_GAP_VP) / slotWidthVp);
  return Math.max(1, Math.min(USER_SCRIPT_DESKTOP_MAX_COLUMNS, columnCount));
}

/**
 * Fixed slot width for every script card. A short row must not stretch its only card
 * to the full pane; it keeps the same width as a card in a full row.
 */
export function resolveUserScriptDesktopCardWidth(contentWidthVp: number): number {
  if (!Number.isFinite(contentWidthVp) || contentWidthVp <= 0) {
    return USER_SCRIPT_DESKTOP_CARD_MIN_WIDTH_VP;
  }
  const columnCount = resolveUserScriptDesktopColumnCount(contentWidthVp);
  const gaps = USER_SCRIPT_DESKTOP_CARD_GAP_VP * Math.max(0, columnCount - 1);
  return Math.max(1, Math.floor((contentWidthVp - gaps) / columnCount));
}

export interface UserScriptsSettingsState {
  autoUpdateEnabled: boolean;
  rows: UserScriptRowView[];
  hasScripts: boolean;
}

export interface UserScriptValueRecoveryViewState {
  visible: boolean;
  title: string;
  message: string;
}

export interface UserScriptInstallPreviewState {
  name: string;
  iconUrl: string;
  version: string;
  description: string;
  scope: string;
  scopeDetail: string;
  grants: string;
  sourceLabel: string;
  updateLabel: string;
  runAtLabel: string;
  warnings: string[];
  errorMessage: string;
  saveEnabled: boolean;
}

export type UserScriptInstallSurfaceMode = 'loading' | 'failure' | 'content';

export function resolveUserScriptInstallLoadErrorMessage(
  source: string,
  importBusy: boolean,
  helperMessage: string
): string {
  if (importBusy || source.trim().length > 0) {
    return '';
  }
  return helperMessage.trim();
}

export function resolveUserScriptInstallSurfaceMode(
  source: string,
  importBusy: boolean,
  loadErrorMessage: string
): UserScriptInstallSurfaceMode {
  if (source.trim().length <= 0 && importBusy) {
    return 'loading';
  }
  if (source.trim().length <= 0 && loadErrorMessage.trim().length > 0) {
    return 'failure';
  }
  return 'content';
}

export function resolveUserScriptInstallLoadFailureTitle(errorMessage: string): string {
  const message = errorMessage.trim();
  if (message.indexOf(USER_SCRIPT_SOURCE_OFFLINE_MESSAGE) >= 0) {
    return resolveAppResourceText($r('app.string.user_script_load_error_no_network'));
  }
  if (message.indexOf(USER_SCRIPT_SOURCE_UNREACHABLE_MESSAGE) >= 0) {
    return resolveAppResourceText($r('app.string.user_script_load_error_cannot_connect'));
  }
  return resolveAppResourceText($r('app.string.user_script_load_error_cannot_read'));
}

export class UserScriptsSettingsViewModel {
  private capabilityContract: UserScriptCapabilityContractService = new UserScriptCapabilityContractService();
  private matchService: UserScriptMatchService = new UserScriptMatchService();

  buildState(
    scripts: InstalledUserScriptState[],
    autoUpdateEnabled: boolean = false
  ): UserScriptsSettingsState {
    const rows = scripts.map((script: InstalledUserScriptState): UserScriptRowView => {
      return {
        id: script.id,
        title: script.name,
        version: script.version.trim(),
        description: script.description.trim(),
        scopeSummary: this.matchService.summarizeScope(script),
        iconUrl: script.iconUrl,
        enabled: script.enabled,
        canUpdate: script.updateUrl.length > 0 || script.downloadUrl.length > 0
      };
    });
    return {
      autoUpdateEnabled: autoUpdateEnabled,
      rows: rows,
      hasScripts: scripts.length > 0
    };
  }

  buildValueRecoveryState(projection: UserScriptValueManagementProjection): UserScriptValueRecoveryViewState {
    const blocked = projection.readiness.status === 'blocked';
    if (!blocked && !projection.incident.active &&
      !projection.migration.unreadableLegacySnapshot &&
      projection.migration.skippedScriptCount <= 0 &&
      projection.migration.skippedUnattributedRecordCount <= 0) {
      return {
        visible: false,
        title: '',
        message: ''
      };
    }
    if (!blocked && !projection.incident.active) {
      if (projection.migration.unreadableLegacySnapshot) {
        return {
          visible: true,
          title: resolveAppResourceText($r('app.string.user_script_recovery_title_partial')),
          message: resolveAppResourceText($r('app.string.user_script_recovery_unreadable'))
        };
      }
      const scriptMessage = projection.migration.skippedScriptCount > 0 ?
        resolveAppResourceText($r('app.string.user_script_recovery_scripts_skipped'), projection.migration.skippedScriptCount) : '';
      const recordMessage = projection.migration.skippedUnattributedRecordCount > 0 ?
        resolveAppResourceText($r('app.string.user_script_recovery_records_skipped'), projection.migration.skippedUnattributedRecordCount) : '';
      return {
        visible: true,
        title: resolveAppResourceText($r('app.string.user_script_recovery_title_partial')),
        message: `${scriptMessage}${recordMessage}${resolveAppResourceText($r('app.string.user_script_recovery_files_kept'))}`
      };
    }
    const stage = projection.incident.stage.length > 0 ?
      projection.incident.stage : projection.readiness.failureStage;
    const code = projection.incident.code.length > 0 ?
      projection.incident.code : projection.readiness.failureCode;
    const diagnostic = stage.length > 0 || code.length > 0
      ? resolveAppResourceText($r('app.string.user_script_recovery_diagnostic'), stage || 'unknown', code || 'unknown')
      : '';
    return {
      visible: true,
      title: blocked
        ? resolveAppResourceText($r('app.string.user_script_recovery_unavailable'))
        : resolveAppResourceText($r('app.string.user_script_recovery_not_saved')),
      message: blocked ?
        `${resolveAppResourceText($r('app.string.user_script_recovery_blocked_message'))}${diagnostic}` :
        `${resolveAppResourceText($r('app.string.user_script_recovery_pending_message'))}${diagnostic}`
    };
  }

  buildInstallPreview(
    candidate: UserScriptPackageCandidate | undefined,
    warnings: string[],
    errorMessage: string
  ): UserScriptInstallPreviewState {
    if (candidate === undefined) {
      return {
        name: '',
        iconUrl: '',
        version: '',
        description: '',
        scope: '',
        scopeDetail: '',
        grants: '',
        sourceLabel: '',
        updateLabel: '',
        runAtLabel: '',
        warnings: warnings,
        errorMessage: errorMessage,
        saveEnabled: false
      };
    }
    return {
      name: candidate.name,
      iconUrl: candidate.iconUrl,
      version: candidate.version,
      description: candidate.description,
      scope: this.matchService.summarizeScope(candidate),
      scopeDetail: this.summarizeScopeDetail(candidate),
      grants: this.capabilityContract.summarizeGrants(candidate.grants),
      sourceLabel: this.summarizeInstallSource(candidate),
      updateLabel: this.summarizeUpdateInfo(candidate),
      runAtLabel: this.summarizeRunAt(candidate.runAt),
      warnings: warnings,
      errorMessage: errorMessage,
      saveEnabled: errorMessage.length === 0
    };
  }

  private summarizeScopeDetail(record: InstalledUserScriptState | UserScriptPackageCandidate): string {
    const rules: string[] = [];
    record.matches.forEach((rule: string) => rules.push(`@match ${rule}`));
    record.includes.forEach((rule: string) => rules.push(`@include ${rule}`));
    record.excludes.forEach((rule: string) => rules.push(`@exclude ${rule}`));
    if (rules.length <= 0) {
      return '';
    }
    const previewRules = rules.slice(0, 3);
    const suffix = rules.length > previewRules.length
      ? resolveAppResourceText($r('app.string.user_script_scope_rules_more'), rules.length)
      : resolveAppResourceText($r('app.string.user_script_scope_rules'), rules.length);
    return `${previewRules.join('\n')}\n${suffix}`;
  }

  private summarizeInstallSource(record: InstalledUserScriptState | UserScriptPackageCandidate): string {
    if (record.installSource === 'url') {
      return 'URL';
    }
    if (record.installSource === 'file') {
      return resolveAppResourceText($r('app.string.user_script_install_source_file'));
    }
    if (record.installSource === 'gallery') {
      return resolveAppResourceText($r('app.string.user_script_install_source_gallery'));
    }
    return resolveAppResourceText($r('app.string.user_script_install_source_manual'));
  }

  private summarizeUpdateInfo(record: InstalledUserScriptState | UserScriptPackageCandidate): string {
    if (record.updateUrl.length > 0 && record.downloadUrl.length > 0) {
      return resolveAppResourceText($r('app.string.user_script_update_check_and_download'));
    }
    if (record.updateUrl.length > 0) {
      return resolveAppResourceText($r('app.string.user_script_update_check_only'));
    }
    if (record.downloadUrl.length > 0) {
      return resolveAppResourceText($r('app.string.user_script_update_download_only'));
    }
    return resolveAppResourceText($r('app.string.user_script_update_none'));
  }

  private summarizeRunAt(runAt: string): string {
    if (runAt === 'document-start') {
      return resolveAppResourceText($r('app.string.user_script_run_at_document_start'));
    }
    if (runAt === 'document-idle') {
      return resolveAppResourceText($r('app.string.user_script_run_at_document_idle'));
    }
    if (runAt === 'main-menu') {
      return resolveAppResourceText($r('app.string.user_script_run_at_main_menu'));
    }
    if (runAt === 'tool-menu') {
      return resolveAppResourceText($r('app.string.user_script_run_at_tool_menu'));
    }
    if (runAt === 'context-menu') {
      return resolveAppResourceText($r('app.string.user_script_run_at_context_menu'));
    }
    return resolveAppResourceText($r('app.string.user_script_run_at_document_end'));
  }

}
