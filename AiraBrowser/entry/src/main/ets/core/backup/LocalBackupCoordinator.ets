import { common } from '@kit.AbilityKit';
import { BrowserBoundaryRouteState, isPrivateBoundaryRoute } from '../../common/utils/RouteParamUtils';
import {
  LocalBackupImportResult,
  LocalBackupInspection,
  LocalBackupSelection
} from '../../features/backup/LocalBackupModels';
import { LocalBackupFileService } from '../../services/backup/LocalBackupFileService';
import { LocalBackupService } from '../../services/backup/LocalBackupService';
import { SyncExperienceCoordinator } from '../sync/SyncExperienceCoordinator';
import { resolveAppResourceText } from '../resources/AppResourceText';

export type LocalBackupActionStatus = 'completed' | 'cancelled' | 'failed';

export interface LocalBackupActionOutcome {
  status: LocalBackupActionStatus;
  title: ResourceStr;
  message: ResourceStr;
  inspection?: LocalBackupInspection;
  importResult?: LocalBackupImportResult;
}

export interface LocalBackupSyncExperienceDomain {
  runLocalBackupImport<T>(operation: () => Promise<T>): Promise<T>;
  recordBookmarkMutation(changedAt: number): Promise<void>;
  notifyPersonalizationLocalSettingsChanged(): void;
}

export class LocalBackupCoordinator {
  private readonly backupService: LocalBackupService;
  private readonly fileService: LocalBackupFileService;
  private readonly syncExperienceCoordinator: SyncExperienceCoordinator | LocalBackupSyncExperienceDomain;

  constructor(
    backupService: LocalBackupService,
    syncExperienceCoordinator: SyncExperienceCoordinator | LocalBackupSyncExperienceDomain,
    fileService: LocalBackupFileService = new LocalBackupFileService()
  ) {
    this.backupService = backupService;
    this.syncExperienceCoordinator = syncExperienceCoordinator;
    this.fileService = fileService;
  }

  async exportBackup(
    context: common.UIAbilityContext,
    selection: LocalBackupSelection,
    boundary: BrowserBoundaryRouteState
  ): Promise<LocalBackupActionOutcome> {
    if (!this.isBoundaryAllowed(boundary)) {
      return this.failure($r('app.string.settings_advanced_backup_private_blocked',
        resolveAppResourceText($r('app.string.settings_advanced_backup_private_export'))));
    }
    try {
      const uri = await this.fileService.pickExportUri(context);
      if (uri === undefined) {
        return this.cancelled();
      }
      const payload = await this.backupService.buildExportPayload(selection);
      await this.fileService.writePayload(uri, payload);
      return {
        status: 'completed',
        title: $r('app.string.settings_advanced_backup_export_done_title'),
        message: $r('app.string.settings_advanced_backup_export_done_message')
      };
    } catch (error) {
      return this.failure(this.stringifyError(error));
    }
  }

  async prepareImport(
    context: common.UIAbilityContext,
    boundary: BrowserBoundaryRouteState
  ): Promise<LocalBackupActionOutcome> {
    if (!this.isBoundaryAllowed(boundary)) {
      return this.failure($r('app.string.settings_advanced_backup_private_blocked',
        resolveAppResourceText($r('app.string.settings_advanced_backup_private_import'))));
    }
    try {
      const uri = await this.fileService.pickImportUri(context);
      if (uri === undefined) {
        return this.cancelled();
      }
      const inspection = this.backupService.inspectPayload(await this.fileService.readPayload(uri));
      return {
        status: 'completed',
        title: '',
        message: '',
        inspection: inspection
      };
    } catch (error) {
      return this.failure(this.stringifyError(error));
    }
  }

  async importPrepared(
    inspection: LocalBackupInspection,
    selection: LocalBackupSelection,
    boundary: BrowserBoundaryRouteState
  ): Promise<LocalBackupActionOutcome> {
    if (!this.isBoundaryAllowed(boundary)) {
      return this.failure($r('app.string.settings_advanced_backup_private_blocked',
        resolveAppResourceText($r('app.string.settings_advanced_backup_private_import'))));
    }
    try {
      const result = await this.syncExperienceCoordinator.runLocalBackupImport(
        async (): Promise<LocalBackupImportResult> => {
          const importResult = await this.backupService.importDocument(inspection.document, selection);
          if (selection.bookmarks && inspection.document.sections.bookmarks !== undefined &&
            importResult.bookmarkCount > 0) {
            await this.syncExperienceCoordinator.recordBookmarkMutation(Date.now());
          }
          if (selection.personalization && inspection.document.sections.personalization !== undefined &&
            importResult.personalizationCount > 0) {
            this.syncExperienceCoordinator.notifyPersonalizationLocalSettingsChanged();
          }
          return importResult;
        }
      );
      return {
        status: 'completed',
        title: $r('app.string.settings_advanced_backup_import_done_title'),
        message: this.buildImportSummary(result),
        importResult: result
      };
    } catch (error) {
      return this.failure($r('app.string.settings_advanced_backup_incomplete_suffix',
        this.stringifyError(error)));
    }
  }

  private isBoundaryAllowed(boundary: BrowserBoundaryRouteState): boolean {
    return !isPrivateBoundaryRoute(boundary.dataScope, boundary.privacyMode);
  }

  private buildImportSummary(result: LocalBackupImportResult): ResourceStr {
    const separator = resolveAppResourceText($r('app.string.settings_advanced_backup_summary_separator'));
    const parts: string[] = [];
    if (result.bookmarkCount > 0) {
      parts.push(resolveAppResourceText($r('app.string.settings_advanced_backup_unit_bookmarks', result.bookmarkCount)));
    }
    if (result.historyCount > 0) {
      parts.push(resolveAppResourceText($r('app.string.settings_advanced_backup_unit_history', result.historyCount)));
    }
    if (result.personalizationCount > 0) {
      parts.push(resolveAppResourceText($r('app.string.settings_advanced_backup_unit_personalization', result.personalizationCount)));
    }
    if (result.userScriptCount > 0) {
      parts.push(resolveAppResourceText($r('app.string.settings_advanced_backup_unit_user_scripts', result.userScriptCount)));
    }
    if (result.userScriptValueCount > 0) {
      parts.push(resolveAppResourceText($r('app.string.settings_advanced_backup_unit_user_script_values', result.userScriptValueCount)));
    }
    const restored = parts.length > 0
      ? $r('app.string.settings_advanced_backup_restored', parts.join(separator))
      : $r('app.string.settings_advanced_backup_nothing_to_do');
    if (result.skippedUserScriptCount <= 0) {
      return restored;
    }
    return `${resolveAppResourceText(restored)} ${resolveAppResourceText(
      $r('app.string.settings_advanced_backup_skipped_suffix', result.skippedUserScriptCount))}`;
  }

  private cancelled(): LocalBackupActionOutcome {
    return { status: 'cancelled', title: '', message: '' };
  }

  private failure(message: ResourceStr): LocalBackupActionOutcome {
    return {
      status: 'failed',
      title: $r('app.string.settings_advanced_backup_failure_title'),
      message: message
    };
  }

  private stringifyError(error: Object | undefined): string {
    if (error instanceof Error && error.message.length > 0) {
      return error.message;
    }
    return resolveAppResourceText($r('app.string.settings_advanced_backup_failure_retry'));
  }
}
