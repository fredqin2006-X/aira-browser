import { InstalledUserScriptState } from '../../features/userscripts/UserScriptMetadataModels';
import { UserScriptRuntimeStateRecord } from '../../features/userscripts/UserScriptRuntimeStateModels';
import { UserScriptValueRecord } from '../../features/userscripts/UserScriptValueModels';
import { UserScriptMatchService } from '../../services/userscripts/UserScriptMatchService';
import { resolveAppResourceText } from '../resources/AppResourceText';

export interface UserScriptDetailRowView {
  label: string;
  value: string;
}

export interface UserScriptDetailActionView {
  editEnabled: boolean;
  deleteEnabled: boolean;
}

export interface UserScriptDetailState {
  title: string;
  subtitle: string;
  enabled: boolean;
  found: boolean;
  statusTitle: string;
  statusDescription: string;
  metadataRows: UserScriptDetailRowView[];
  runtimeRows: UserScriptDetailRowView[];
  storageRows: UserScriptDetailRowView[];
  sourcePreview: string;
  actions: UserScriptDetailActionView;
}

export class UserScriptDetailViewModel {
  private matchService: UserScriptMatchService = new UserScriptMatchService();

  buildState(
    script: InstalledUserScriptState | undefined,
    runtimeState: UserScriptRuntimeStateRecord | undefined,
    values: UserScriptValueRecord[]
  ): UserScriptDetailState {
    if (script === undefined) {
      return {
        title: resolveAppResourceText($r('app.string.user_script_detail_missing_title')),
        subtitle: resolveAppResourceText($r('app.string.user_script_detail_missing_subtitle')),
        enabled: false,
        found: false,
        statusTitle: resolveAppResourceText($r('app.string.user_script_detail_unavailable')),
        statusDescription: resolveAppResourceText($r('app.string.user_script_detail_unavailable_hint')),
        metadataRows: [],
        runtimeRows: [],
        storageRows: [],
        sourcePreview: '',
        actions: {
          editEnabled: false,
          deleteEnabled: false
        }
      };
    }
    return {
      title: script.name,
      subtitle: `${this.matchService.summarizeScope(script)} · ${script.version}`,
      enabled: script.enabled,
      found: true,
      statusTitle: script.enabled
        ? resolveAppResourceText($r('app.string.user_script_detail_enabled'))
        : resolveAppResourceText($r('app.string.user_script_detail_disabled')),
      statusDescription: this.buildStatusDescription(script, runtimeState),
      metadataRows: this.buildMetadataRows(script),
      runtimeRows: this.buildRuntimeRows(runtimeState),
      storageRows: this.buildStorageRows(values),
      sourcePreview: this.buildSourcePreview(script.source),
      actions: {
        editEnabled: true,
        deleteEnabled: true
      }
    };
  }

  private buildStatusDescription(
    script: InstalledUserScriptState,
    runtimeState: UserScriptRuntimeStateRecord | undefined
  ): string {
    if (!script.enabled) {
      return resolveAppResourceText($r('app.string.user_script_detail_disabled_hint'));
    }
    if (runtimeState === undefined || runtimeState.status === 'never_run') {
      return resolveAppResourceText($r('app.string.user_script_detail_no_run_record'));
    }
    if (runtimeState.status === 'skipped') {
      return resolveAppResourceText(
        $r('app.string.user_script_detail_last_skipped'),
        this.formatRuntimeReason(runtimeState.lastSkipReason)
      );
    }
    if (runtimeState.lastBridgeRejectReason.length > 0) {
      return resolveAppResourceText(
        $r('app.string.user_script_detail_last_bridge_rejected'),
        this.formatRuntimeReason(runtimeState.lastBridgeRejectReason)
      );
    }
    if (runtimeState.status === 'failed') {
      return runtimeState.lastErrorMessage.length > 0
        ? runtimeState.lastErrorMessage
        : resolveAppResourceText($r('app.string.user_script_detail_last_failed'));
    }
    if (runtimeState.status === 'success') {
      return resolveAppResourceText($r('app.string.user_script_detail_runs_succeeded'), runtimeState.runCount);
    }
    return resolveAppResourceText($r('app.string.user_script_detail_injection_skipped'));
  }

  private buildMetadataRows(script: InstalledUserScriptState): UserScriptDetailRowView[] {
    return [
      { label: resolveAppResourceText($r('app.string.user_script_meta_name')), value: script.name },
      { label: resolveAppResourceText($r('app.string.user_script_meta_version')), value: script.version },
      {
        label: resolveAppResourceText($r('app.string.user_script_meta_namespace')),
        value: script.namespace.length > 0
          ? script.namespace
          : resolveAppResourceText($r('app.string.user_script_meta_unspecified'))
      },
      {
        label: resolveAppResourceText($r('app.string.user_script_meta_description')),
        value: script.description.length > 0
          ? script.description
          : resolveAppResourceText($r('app.string.user_script_meta_unspecified'))
      },
      { label: resolveAppResourceText($r('app.string.user_script_meta_scope')), value: this.matchService.summarizeScope(script) },
      {
        label: resolveAppResourceText($r('app.string.user_script_meta_excludes')),
        value: script.excludes.length > 0
          ? script.excludes.join('\n')
          : resolveAppResourceText($r('app.string.user_script_meta_none'))
      },
      { label: resolveAppResourceText($r('app.string.user_script_meta_grants')), value: script.grants.join(', ') },
      { label: resolveAppResourceText($r('app.string.user_script_meta_run_at')), value: script.runAt },
      { label: resolveAppResourceText($r('app.string.user_script_meta_source')), value: this.buildSourceUrl(script) }
    ];
  }

  private buildRuntimeRows(runtimeState: UserScriptRuntimeStateRecord | undefined): UserScriptDetailRowView[] {
    if (runtimeState === undefined || runtimeState.status === 'never_run') {
      return [
        { label: resolveAppResourceText($r('app.string.user_script_runtime_status')), value: resolveAppResourceText($r('app.string.user_script_runtime_never_run')) },
        { label: resolveAppResourceText($r('app.string.user_script_runtime_last_url')), value: resolveAppResourceText($r('app.string.user_script_meta_none')) },
        { label: resolveAppResourceText($r('app.string.user_script_runtime_last_injection_phase')), value: resolveAppResourceText($r('app.string.user_script_meta_none')) },
        { label: resolveAppResourceText($r('app.string.user_script_runtime_last_bridge_reject')), value: resolveAppResourceText($r('app.string.user_script_meta_none')) }
      ];
    }
    return [
      { label: resolveAppResourceText($r('app.string.user_script_runtime_status')), value: this.formatRuntimeStatus(runtimeState.status) },
      {
        label: resolveAppResourceText($r('app.string.user_script_runtime_last_url')),
        value: runtimeState.lastUrl.length > 0
          ? runtimeState.lastUrl
          : resolveAppResourceText($r('app.string.user_script_meta_none'))
      },
      { label: resolveAppResourceText($r('app.string.user_script_runtime_last_injection_phase')), value: this.formatInjectionPhase(runtimeState.lastInjectionPhase) },
      { label: resolveAppResourceText($r('app.string.user_script_runtime_run_count')), value: `${runtimeState.runCount}` },
      { label: resolveAppResourceText($r('app.string.user_script_runtime_failure_count')), value: `${runtimeState.failureCount}` },
      { label: resolveAppResourceText($r('app.string.user_script_runtime_last_run')), value: this.formatTime(runtimeState.lastRunAt) },
      { label: resolveAppResourceText($r('app.string.user_script_runtime_last_success')), value: this.formatTime(runtimeState.lastSuccessAt) },
      { label: resolveAppResourceText($r('app.string.user_script_runtime_last_failure')), value: this.formatTime(runtimeState.lastFailureAt) },
      { label: resolveAppResourceText($r('app.string.user_script_runtime_last_skip_reason')), value: this.formatRuntimeReason(runtimeState.lastSkipReason) },
      {
        label: resolveAppResourceText($r('app.string.user_script_runtime_last_bridge_reject')),
        value: this.buildBridgeRejectValue(runtimeState.lastBridgeCapability, runtimeState.lastBridgeRejectReason)
      },
      {
        label: resolveAppResourceText($r('app.string.user_script_runtime_error_message')),
        value: runtimeState.lastErrorMessage.length > 0
          ? runtimeState.lastErrorMessage
          : resolveAppResourceText($r('app.string.user_script_meta_none'))
      }
    ];
  }

  private buildStorageRows(values: UserScriptValueRecord[]): UserScriptDetailRowView[] {
    return [
      { label: resolveAppResourceText($r('app.string.user_script_storage_value_count')), value: `${values.length}` },
      {
        label: resolveAppResourceText($r('app.string.user_script_storage_keys')),
        value: values.length > 0
          ? values.map((record: UserScriptValueRecord) => record.key).join(', ')
          : resolveAppResourceText($r('app.string.user_script_meta_none'))
      }
    ];
  }

  private buildSourcePreview(source: string): string {
    const trimmed = source.trim();
    if (trimmed.length <= 1200) {
      return trimmed;
    }
    return `${trimmed.substring(0, 1200)}\n...`;
  }

  private buildSourceUrl(script: InstalledUserScriptState): string {
    if (script.sourceUrl.length > 0) {
      return script.sourceUrl;
    }
    if (script.downloadUrl.length > 0) {
      return script.downloadUrl;
    }
    if (script.updateUrl.length > 0) {
      return script.updateUrl;
    }
    return script.installSource;
  }

  private formatRuntimeStatus(status: string): string {
    if (status === 'success') {
      return resolveAppResourceText($r('app.string.user_script_runtime_last_success'));
    }
    if (status === 'failed') {
      return resolveAppResourceText($r('app.string.user_script_runtime_last_failure'));
    }
    if (status === 'skipped') {
      return resolveAppResourceText($r('app.string.user_script_runtime_last_skipped'));
    }
    return resolveAppResourceText($r('app.string.user_script_runtime_never_run'));
  }

  private formatInjectionPhase(value: string): string {
    if (value === 'document-start') {
      return 'document-start';
    }
    if (value === 'document-end') {
      return 'document-end';
    }
    if (value === 'main-menu' || value === 'tool-menu' || value === 'context-menu') {
      return value;
    }
    return resolveAppResourceText($r('app.string.user_script_unknown'));
  }

  private buildBridgeRejectValue(capability: string, reason: string): string {
    const normalizedReason = this.formatRuntimeReason(reason);
    const noneLabel = resolveAppResourceText($r('app.string.user_script_meta_none'));
    if (normalizedReason === noneLabel) {
      return noneLabel;
    }
    if (capability.trim().length === 0) {
      return normalizedReason;
    }
    return `${capability.trim()} · ${normalizedReason}`;
  }

  private formatRuntimeReason(reason: string): string {
    const normalized = reason.trim();
    const noneLabel = resolveAppResourceText($r('app.string.user_script_meta_none'));
    if (normalized.length === 0) {
      return noneLabel;
    }
    const labels: Record<string, string> = {
      'private_mode': resolveAppResourceText($r('app.string.user_script_reason_private_mode')),
      'missing_controller': resolveAppResourceText($r('app.string.user_script_reason_missing_controller')),
      'grant-denied': resolveAppResourceText($r('app.string.user_script_reason_grant_denied')),
      'url-not-matched': resolveAppResourceText($r('app.string.user_script_reason_url_not_matched')),
      'invalid-bridge-token': resolveAppResourceText($r('app.string.user_script_reason_invalid_bridge_token')),
      'missing-bridge-auth': resolveAppResourceText($r('app.string.user_script_reason_missing_bridge_auth')),
      'missing-page-url': resolveAppResourceText($r('app.string.user_script_reason_missing_page_url')),
      'capability-mismatch': resolveAppResourceText($r('app.string.user_script_reason_capability_mismatch')),
      'unsupported-capability': resolveAppResourceText($r('app.string.user_script_reason_unsupported_capability')),
      'script-disabled': resolveAppResourceText($r('app.string.user_script_reason_script_disabled'))
    };
    return labels[normalized] ?? normalized;
  }

  private formatTime(value: number): string {
    if (value <= 0) {
      return resolveAppResourceText($r('app.string.user_script_meta_none'));
    }
    return new Date(value).toLocaleString();
  }
}
