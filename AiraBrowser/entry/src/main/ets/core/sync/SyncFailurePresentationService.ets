import { HuaweiCloudSyncErrorMessageService } from '../../services/sync/HuaweiCloudSyncErrorMessageService';
import {
  AiraBookmarkSyncFailure,
  AiraBookmarkSyncFailureStage,
  AiraSyncRemoteKind
} from '../../common/models/AiraSyncModels';

const HUAWEI_SPACE_PERSONALIZATION_PROGRESS_CODE_ONE: string =
  '华为云空间个性化同步未完成（进度码 1）';
const HUAWEI_SPACE_PERSONALIZATION_SYSTEM_UPDATE_GUIDANCE: string =
  '请先将系统更新到最新版本并重启，然后再次同步。';

export interface SyncFailurePresentationInput {
  serviceName: string;
  operationName: string;
  errorMessage: string;
}

export interface SyncFailurePresentation {
  title: ResourceStr;
  summary: ResourceStr;
  diagnostics: string;
  details: SyncFailureDetailItem[];
}

export interface SyncFailureDetailItem {
  label: string;
  value: string;
}

export interface SyncBookmarkFailurePresentationInput {
  remoteKind: AiraSyncRemoteKind;
  operationName: string;
  failure?: AiraBookmarkSyncFailure;
}

interface SyncHttpFailure {
  provider: string;
  action: string;
  path: string;
  status: number;
}

export class SyncFailurePresentationService {
  private huaweiCloudErrorMessageService: HuaweiCloudSyncErrorMessageService = new HuaweiCloudSyncErrorMessageService();

  buildBookmarkFailureMessage(input: SyncBookmarkFailurePresentationInput): string {
    const failure = input.failure ?? {
      code: 'BKM-UNKNOWN-001',
      stage: 'unknown' as AiraBookmarkSyncFailureStage,
      safeDetail: '书签同步在未识别的阶段中断，请重试并向客服提供错误码。'
    };
    const operationName = input.operationName.trim().length > 0 ? input.operationName.trim() : '书签同步';
    const providerLabel = this.resolveBookmarkProviderLabel(input.remoteKind);
    return `${operationName}未完成（同步源：${providerLabel}；阶段：${this.resolveBookmarkStageLabel(failure.stage)}；` +
      `错误码：${failure.code}）。${failure.safeDetail}`;
  }

  buildBookmarkFailureResource(input: SyncBookmarkFailurePresentationInput): ResourceStr {
    const failure = input.failure;
    const code = failure !== undefined && failure.code.trim().length > 0 ? failure.code.trim() : 'BKM-UNKNOWN-001';
    const detail = failure !== undefined ? failure.safeDetail.trim() : '';
    if (detail === '当前书签同步协议已停止服务，请升级鸿蒙 App 或 Aira-sync 扩展后再试。本机和云端书签均未被覆盖。') {
      return $r('app.string.settings_sync_bookmark_fail_protocol', code);
    }
    if (detail === '检测到需要确认的书签冲突，已保留本机和云端内容。请按页面提示处理。') {
      return $r('app.string.settings_sync_bookmark_fail_conflict', code);
    }
    const stage = failure !== undefined ? failure.stage : 'unknown';
    if (input.remoteKind === 'aira_cloud') {
      return this.bookmarkFailureCloud(stage, detail, code);
    }
    if (input.remoteKind === 'huawei_space') {
      return this.bookmarkFailureHuawei(stage, detail, code);
    }
    if (input.remoteKind === 'webdav') {
      return this.bookmarkFailureWebdav(stage, detail, code);
    }
    if (input.remoteKind === 'self_hosted') {
      return this.bookmarkFailureSelfHost(stage, detail, code);
    }
    return this.bookmarkFailureUnset(stage, detail, code);
  }

  private bookmarkFailureCloud(stage: string, detail: string, code: string): ResourceStr {
    if (stage === 'authentication') {
      if (detail.length === 0 || detail === '同步账号或同步源配置尚未通过校验，请重新确认账号状态和同步设置。') {
        return $r('app.string.settings_sync_bookmark_fail_cloud_auth', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_cloud_auth_raw', code, detail);
    }
    if (stage === 'network') {
      if (detail.length === 0 || detail === '网络请求未完成，请检查网络后重试。') {
        return $r('app.string.settings_sync_bookmark_fail_cloud_network', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_cloud_network_raw', code, detail);
    }
    if (stage === 'remote_read_validation') {
      if (detail.length === 0 || detail === '无法读取或校验同步源中的书签快照，已停止后续写入以保护书签。') {
        return $r('app.string.settings_sync_bookmark_fail_cloud_remote_read', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_cloud_remote_read_raw', code, detail);
    }
    if (stage === 'local_snapshot') {
      if (detail.length === 0 || detail === '无法生成或读取本机书签快照，尚未向同步源写入数据。') {
        return $r('app.string.settings_sync_bookmark_fail_cloud_local_snapshot', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_cloud_local_snapshot_raw', code, detail);
    }
    if (stage === 'merge') {
      if (detail.length === 0 || detail === '书签合并未完成，已保留本机和同步源中的现有内容。') {
        return $r('app.string.settings_sync_bookmark_fail_cloud_merge', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_cloud_merge_raw', code, detail);
    }
    if (stage === 'remote_commit') {
      if (detail.length === 0 || detail === '书签提交到同步源时未完成，本机内容和待同步状态已保留。') {
        return $r('app.string.settings_sync_bookmark_fail_cloud_remote_commit', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_cloud_remote_commit_raw', code, detail);
    }
    if (stage === 'remote_confirmation') {
      if (detail.length === 0 || detail === '同步源未能确认完整提交，本次同步不会标记为成功。') {
        return $r('app.string.settings_sync_bookmark_fail_cloud_remote_confirm', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_cloud_remote_confirm_raw', code, detail);
    }
    if (stage === 'local_apply') {
      if (detail.length === 0 || detail === '合并结果未能完整写入并校验到本机，本次同步不会标记为成功。') {
        return $r('app.string.settings_sync_bookmark_fail_cloud_local_apply', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_cloud_local_apply_raw', code, detail);
    }
    if (stage === 'unknown') {
      if (detail.length === 0 || detail === '书签同步在未识别的阶段中断，请重试并向客服提供错误码。') {
        return $r('app.string.settings_sync_bookmark_fail_cloud_unknown', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_cloud_unknown_raw', code, detail);
    }
    return $r('app.string.settings_sync_bookmark_fail_cloud_unknown_raw', code, detail);
  }

  private bookmarkFailureHuawei(stage: string, detail: string, code: string): ResourceStr {
    if (stage === 'authentication') {
      if (detail.length === 0 || detail === '同步账号或同步源配置尚未通过校验，请重新确认账号状态和同步设置。') {
        return $r('app.string.settings_sync_bookmark_fail_huawei_auth', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_huawei_auth_raw', code, detail);
    }
    if (stage === 'network') {
      if (detail.length === 0 || detail === '网络请求未完成，请检查网络后重试。') {
        return $r('app.string.settings_sync_bookmark_fail_huawei_network', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_huawei_network_raw', code, detail);
    }
    if (stage === 'remote_read_validation') {
      if (detail.length === 0 || detail === '无法读取或校验同步源中的书签快照，已停止后续写入以保护书签。') {
        return $r('app.string.settings_sync_bookmark_fail_huawei_remote_read', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_huawei_remote_read_raw', code, detail);
    }
    if (stage === 'local_snapshot') {
      if (detail.length === 0 || detail === '无法生成或读取本机书签快照，尚未向同步源写入数据。') {
        return $r('app.string.settings_sync_bookmark_fail_huawei_local_snapshot', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_huawei_local_snapshot_raw', code, detail);
    }
    if (stage === 'merge') {
      if (detail.length === 0 || detail === '书签合并未完成，已保留本机和同步源中的现有内容。') {
        return $r('app.string.settings_sync_bookmark_fail_huawei_merge', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_huawei_merge_raw', code, detail);
    }
    if (stage === 'remote_commit') {
      if (detail.length === 0 || detail === '书签提交到同步源时未完成，本机内容和待同步状态已保留。') {
        return $r('app.string.settings_sync_bookmark_fail_huawei_remote_commit', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_huawei_remote_commit_raw', code, detail);
    }
    if (stage === 'remote_confirmation') {
      if (detail.length === 0 || detail === '同步源未能确认完整提交，本次同步不会标记为成功。') {
        return $r('app.string.settings_sync_bookmark_fail_huawei_remote_confirm', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_huawei_remote_confirm_raw', code, detail);
    }
    if (stage === 'local_apply') {
      if (detail.length === 0 || detail === '合并结果未能完整写入并校验到本机，本次同步不会标记为成功。') {
        return $r('app.string.settings_sync_bookmark_fail_huawei_local_apply', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_huawei_local_apply_raw', code, detail);
    }
    if (stage === 'unknown') {
      if (detail.length === 0 || detail === '书签同步在未识别的阶段中断，请重试并向客服提供错误码。') {
        return $r('app.string.settings_sync_bookmark_fail_huawei_unknown', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_huawei_unknown_raw', code, detail);
    }
    return $r('app.string.settings_sync_bookmark_fail_huawei_unknown_raw', code, detail);
  }

  private bookmarkFailureWebdav(stage: string, detail: string, code: string): ResourceStr {
    if (stage === 'authentication') {
      if (detail.length === 0 || detail === '同步账号或同步源配置尚未通过校验，请重新确认账号状态和同步设置。') {
        return $r('app.string.settings_sync_bookmark_fail_webdav_auth', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_webdav_auth_raw', code, detail);
    }
    if (stage === 'network') {
      if (detail.length === 0 || detail === '网络请求未完成，请检查网络后重试。') {
        return $r('app.string.settings_sync_bookmark_fail_webdav_network', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_webdav_network_raw', code, detail);
    }
    if (stage === 'remote_read_validation') {
      if (detail.length === 0 || detail === '无法读取或校验同步源中的书签快照，已停止后续写入以保护书签。') {
        return $r('app.string.settings_sync_bookmark_fail_webdav_remote_read', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_webdav_remote_read_raw', code, detail);
    }
    if (stage === 'local_snapshot') {
      if (detail.length === 0 || detail === '无法生成或读取本机书签快照，尚未向同步源写入数据。') {
        return $r('app.string.settings_sync_bookmark_fail_webdav_local_snapshot', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_webdav_local_snapshot_raw', code, detail);
    }
    if (stage === 'merge') {
      if (detail.length === 0 || detail === '书签合并未完成，已保留本机和同步源中的现有内容。') {
        return $r('app.string.settings_sync_bookmark_fail_webdav_merge', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_webdav_merge_raw', code, detail);
    }
    if (stage === 'remote_commit') {
      if (detail.length === 0 || detail === '书签提交到同步源时未完成，本机内容和待同步状态已保留。') {
        return $r('app.string.settings_sync_bookmark_fail_webdav_remote_commit', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_webdav_remote_commit_raw', code, detail);
    }
    if (stage === 'remote_confirmation') {
      if (detail.length === 0 || detail === '同步源未能确认完整提交，本次同步不会标记为成功。') {
        return $r('app.string.settings_sync_bookmark_fail_webdav_remote_confirm', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_webdav_remote_confirm_raw', code, detail);
    }
    if (stage === 'local_apply') {
      if (detail.length === 0 || detail === '合并结果未能完整写入并校验到本机，本次同步不会标记为成功。') {
        return $r('app.string.settings_sync_bookmark_fail_webdav_local_apply', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_webdav_local_apply_raw', code, detail);
    }
    if (stage === 'unknown') {
      if (detail.length === 0 || detail === '书签同步在未识别的阶段中断，请重试并向客服提供错误码。') {
        return $r('app.string.settings_sync_bookmark_fail_webdav_unknown', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_webdav_unknown_raw', code, detail);
    }
    return $r('app.string.settings_sync_bookmark_fail_webdav_unknown_raw', code, detail);
  }

  private bookmarkFailureSelfHost(stage: string, detail: string, code: string): ResourceStr {
    if (stage === 'authentication') {
      if (detail.length === 0 || detail === '同步账号或同步源配置尚未通过校验，请重新确认账号状态和同步设置。') {
        return $r('app.string.settings_sync_bookmark_fail_self_host_auth', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_self_host_auth_raw', code, detail);
    }
    if (stage === 'network') {
      if (detail.length === 0 || detail === '网络请求未完成，请检查网络后重试。') {
        return $r('app.string.settings_sync_bookmark_fail_self_host_network', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_self_host_network_raw', code, detail);
    }
    if (stage === 'remote_read_validation') {
      if (detail.length === 0 || detail === '无法读取或校验同步源中的书签快照，已停止后续写入以保护书签。') {
        return $r('app.string.settings_sync_bookmark_fail_self_host_remote_read', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_self_host_remote_read_raw', code, detail);
    }
    if (stage === 'local_snapshot') {
      if (detail.length === 0 || detail === '无法生成或读取本机书签快照，尚未向同步源写入数据。') {
        return $r('app.string.settings_sync_bookmark_fail_self_host_local_snapshot', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_self_host_local_snapshot_raw', code, detail);
    }
    if (stage === 'merge') {
      if (detail.length === 0 || detail === '书签合并未完成，已保留本机和同步源中的现有内容。') {
        return $r('app.string.settings_sync_bookmark_fail_self_host_merge', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_self_host_merge_raw', code, detail);
    }
    if (stage === 'remote_commit') {
      if (detail.length === 0 || detail === '书签提交到同步源时未完成，本机内容和待同步状态已保留。') {
        return $r('app.string.settings_sync_bookmark_fail_self_host_remote_commit', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_self_host_remote_commit_raw', code, detail);
    }
    if (stage === 'remote_confirmation') {
      if (detail.length === 0 || detail === '同步源未能确认完整提交，本次同步不会标记为成功。') {
        return $r('app.string.settings_sync_bookmark_fail_self_host_remote_confirm', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_self_host_remote_confirm_raw', code, detail);
    }
    if (stage === 'local_apply') {
      if (detail.length === 0 || detail === '合并结果未能完整写入并校验到本机，本次同步不会标记为成功。') {
        return $r('app.string.settings_sync_bookmark_fail_self_host_local_apply', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_self_host_local_apply_raw', code, detail);
    }
    if (stage === 'unknown') {
      if (detail.length === 0 || detail === '书签同步在未识别的阶段中断，请重试并向客服提供错误码。') {
        return $r('app.string.settings_sync_bookmark_fail_self_host_unknown', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_self_host_unknown_raw', code, detail);
    }
    return $r('app.string.settings_sync_bookmark_fail_self_host_unknown_raw', code, detail);
  }

  private bookmarkFailureUnset(stage: string, detail: string, code: string): ResourceStr {
    if (stage === 'authentication') {
      if (detail.length === 0 || detail === '同步账号或同步源配置尚未通过校验，请重新确认账号状态和同步设置。') {
        return $r('app.string.settings_sync_bookmark_fail_unset_auth', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_unset_auth_raw', code, detail);
    }
    if (stage === 'network') {
      if (detail.length === 0 || detail === '网络请求未完成，请检查网络后重试。') {
        return $r('app.string.settings_sync_bookmark_fail_unset_network', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_unset_network_raw', code, detail);
    }
    if (stage === 'remote_read_validation') {
      if (detail.length === 0 || detail === '无法读取或校验同步源中的书签快照，已停止后续写入以保护书签。') {
        return $r('app.string.settings_sync_bookmark_fail_unset_remote_read', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_unset_remote_read_raw', code, detail);
    }
    if (stage === 'local_snapshot') {
      if (detail.length === 0 || detail === '无法生成或读取本机书签快照，尚未向同步源写入数据。') {
        return $r('app.string.settings_sync_bookmark_fail_unset_local_snapshot', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_unset_local_snapshot_raw', code, detail);
    }
    if (stage === 'merge') {
      if (detail.length === 0 || detail === '书签合并未完成，已保留本机和同步源中的现有内容。') {
        return $r('app.string.settings_sync_bookmark_fail_unset_merge', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_unset_merge_raw', code, detail);
    }
    if (stage === 'remote_commit') {
      if (detail.length === 0 || detail === '书签提交到同步源时未完成，本机内容和待同步状态已保留。') {
        return $r('app.string.settings_sync_bookmark_fail_unset_remote_commit', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_unset_remote_commit_raw', code, detail);
    }
    if (stage === 'remote_confirmation') {
      if (detail.length === 0 || detail === '同步源未能确认完整提交，本次同步不会标记为成功。') {
        return $r('app.string.settings_sync_bookmark_fail_unset_remote_confirm', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_unset_remote_confirm_raw', code, detail);
    }
    if (stage === 'local_apply') {
      if (detail.length === 0 || detail === '合并结果未能完整写入并校验到本机，本次同步不会标记为成功。') {
        return $r('app.string.settings_sync_bookmark_fail_unset_local_apply', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_unset_local_apply_raw', code, detail);
    }
    if (stage === 'unknown') {
      if (detail.length === 0 || detail === '书签同步在未识别的阶段中断，请重试并向客服提供错误码。') {
        return $r('app.string.settings_sync_bookmark_fail_unset_unknown', code);
      }
      return $r('app.string.settings_sync_bookmark_fail_unset_unknown_raw', code, detail);
    }
    return $r('app.string.settings_sync_bookmark_fail_unset_unknown_raw', code, detail);
  }


  localizeKnownProviderMessage(message: string): ResourceStr {
    if (message === '请先完成同步方式配置。') {
      return $r('app.string.settings_sync_provider_configure_first');
    }
    if (message === '当前设备已使用此同步方式。') {
      return $r('app.string.settings_sync_provider_already_using');
    }
    if (message === '会先合并已开启且目标支持的同步内容，完成后只修改当前设备的同步方式。') {
      return $r('app.string.settings_sync_provider_merge_first');
    }
    if (message === '书签同步已暂停。') {
      return $r('app.string.settings_sync_bookmarks_paused_sentence');
    }
    if (message === '书签会在后台同步。离开此页面、断网或下次打开应用都会继续，直到完成。') {
      return $r('app.string.settings_sync_bookmarks_background');
    }
    return this.localizeBookmarkSummary(message);
  }

  localizeBookmarkSummary(summary: string): ResourceStr {
    const text = summary.trim();
    if (text === '远端为空，使用本地快照作为首次同步结果。') {
      return $r('app.string.settings_sync_summary_remote_empty');
    }
    if (text === '首次同步已保留本机和云端的全部可见书签；无共享基线的删除记录不会覆盖可见内容。') {
      return $r('app.string.settings_sync_summary_first_kept');
    }
    const conflicts = /^发现 ([0-9]+) 个双向冲突，已阻止自动合并。$/.exec(text);
    if (conflicts !== null) {
      return $r('app.string.settings_sync_summary_conflicts', Number(conflicts[1]));
    }
    const merged = /^已合并 ([0-9]+) 个本地变化和 ([0-9]+) 个远端变化。$/.exec(text);
    if (merged !== null) {
      return $r('app.string.settings_sync_summary_merged', Number(merged[1]), Number(merged[2]));
    }
    const applied = /^已同步写入 ([0-9]+) 个文件夹、([0-9]+) 个书签，删除 ([0-9]+) 个本地书签节点。$/.exec(text);
    if (applied !== null) {
      return $r('app.string.settings_sync_summary_applied', Number(applied[1]), Number(applied[2]), Number(applied[3]));
    }
    const updated = /^已使用云端快照更新 ([0-9]+) 个文件夹和 ([0-9]+) 个书签。$/.exec(text);
    if (updated !== null) {
      return $r('app.string.settings_sync_summary_cloud_updated', Number(updated[1]), Number(updated[2]));
    }
    return text;
  }

  localizeProviderMessageLines(message: string): ResourceStr[] {
    const parts = message.split('\n');
    const lines: ResourceStr[] = [];
    for (let index = 0; index < parts.length; index += 1) {
      const line = parts[index].trim();
      if (line.length > 0) {
        lines.push(this.localizeProviderLine(line));
      }
    }
    return lines;
  }

  matchKnownProviderLine(line: string): ResourceStr | undefined {
    const text = line.trim();
    if (text.length === 0) {
      return undefined;
    }
    const known = this.localizeKnownProviderMessage(text);
    if (typeof known !== 'string') {
      return known;
    }
    if (text.indexOf('常用设置：') === 0) {
      return this.matchPersonalizationSentence(text.substring('常用设置：'.length).trim(), true);
    }
    if (text.indexOf('历史记录：') === 0) {
      return this.matchHistorySentence(text.substring('历史记录：'.length).trim());
    }
    if (text.indexOf('主页收藏、小说书架和常用设置：') === 0) {
      const body = text.substring('主页收藏、小说书架和常用设置：'.length).trim();
      return body === '主页收藏、小说书架和常用设置会在后台同步。'
        ? $r('app.string.settings_sync_personalization_background')
        : undefined;
    }
    const history = this.matchHistorySentence(text);
    if (history !== undefined) {
      return history;
    }
    return this.matchPersonalizationSentence(text, false);
  }

  localizeProviderLine(line: string): ResourceStr {
    const text = line.trim();
    if (text.length === 0) {
      return $r('app.string.settings_sync_provider_raw', '');
    }
    const known = this.localizeKnownProviderMessage(text);
    if (typeof known !== 'string' || known !== text) {
      return known;
    }
    if (text.indexOf('常用设置：') === 0) {
      return this.localizePersonalizationLine(text.substring('常用设置：'.length).trim(), true);
    }
    if (text.indexOf('历史记录：') === 0) {
      return this.localizeHistoryLine(text.substring('历史记录：'.length).trim(), true);
    }
    if (text.indexOf('主页收藏、小说书架和常用设置：') === 0) {
      return this.localizeContentLine(text.substring('主页收藏、小说书架和常用设置：'.length).trim());
    }
    const history = this.matchHistorySentence(text);
    if (history !== undefined) {
      return history;
    }
    const personalization = this.matchPersonalizationSentence(text, false);
    if (personalization !== undefined) {
      return personalization;
    }
    return $r('app.string.settings_sync_provider_raw', text);
  }

  localizePrefixedHistoryLine(message: string): ResourceStr {
    return this.localizeHistoryLine(message.trim(), true);
  }

  localizePrefixedContentLine(message: string): ResourceStr {
    return this.localizeContentLine(message.trim());
  }

  private localizePersonalizationLine(text: string, prefixed: boolean): ResourceStr {
    const matched = this.matchPersonalizationSentence(text, prefixed);
    if (matched !== undefined) {
      return matched;
    }
    return prefixed
      ? $r('app.string.settings_sync_line_personalization_raw', text)
      : $r('app.string.settings_sync_provider_raw', text);
  }

  private localizeHistoryLine(text: string, prefixed: boolean): ResourceStr {
    const matched = this.matchHistorySentence(text);
    if (matched !== undefined) {
      return matched;
    }
    return prefixed
      ? $r('app.string.settings_sync_line_history_raw', text)
      : $r('app.string.settings_sync_provider_raw', text);
  }

  private localizeContentLine(text: string): ResourceStr {
    if (text === '主页收藏、小说书架和常用设置会在后台同步。') {
      return $r('app.string.settings_sync_personalization_background');
    }
    return $r('app.string.settings_sync_line_content_raw', text);
  }

  private matchHistorySentence(text: string): ResourceStr | undefined {
    if (text === '历史记录已完成增量同步。') {
      return $r('app.string.settings_sync_history_incremental');
    }
    if (text === '历史记录已经是最新。') {
      return $r('app.string.settings_sync_history_current');
    }
    if (text === '历史记录已完成华为云空间增量同步。') {
      return $r('app.string.settings_sync_history_huawei_incremental');
    }
    if (text === '当前 WebDAV 同步方式不支持历史记录同步。') {
      return $r('app.string.settings_sync_history_webdav_unsupported');
    }
    if (text === '请先登录华为账号再同步历史记录。') {
      return $r('app.string.settings_sync_history_login_required');
    }
    if (text === '历史记录增量过多，本轮未能在安全上限内完成，请稍后继续同步。') {
      return $r('app.string.settings_sync_history_too_many');
    }
    if (text === '历史记录初始化页数超过安全上限，请稍后继续。') {
      return $r('app.string.settings_sync_history_page_limit');
    }
    if (text === '账号已切换，本轮历史记录同步已停止。') {
      return $r('app.string.settings_sync_history_account_switched');
    }
    if (text === '华为云空间历史记录读取失败。') {
      return $r('app.string.settings_sync_history_huawei_read_failed');
    }
    if (text === '本机历史记录初始化超过安全上限，请稍后继续同步。') {
      return $r('app.string.settings_sync_history_local_limit');
    }
    if (text === '原同步方式的历史记录暂时无法取回。') {
      return $r('app.string.settings_sync_history_source_unavailable');
    }
    if (text === '原同步方式的历史记录未能完整取回，已使用本机已有记录与目标合并。未取回的记录仍保留在原同步方式。') {
      return $r('app.string.settings_sync_history_source_partial');
    }
    return undefined;
  }

  private matchPersonalizationSentence(text: string, prefixed: boolean): ResourceStr | undefined {
    const restoredBackup = /^已恢复 ([0-9]+) 项并完成同步。 ([0-9]+) 个附加备份位置暂未写入。$/.exec(text);
    if (restoredBackup !== null) {
      return prefixed
        ? $r('app.string.settings_sync_pref_restored_backup', Number(restoredBackup[1]), Number(restoredBackup[2]))
        : $r('app.string.settings_sync_personalization_restored_backup', Number(restoredBackup[1]), Number(restoredBackup[2]));
    }
    const restored = /^已恢复 ([0-9]+) 项并完成同步。$/.exec(text);
    if (restored !== null) {
      return prefixed
        ? $r('app.string.settings_sync_pref_restored', Number(restored[1]))
        : $r('app.string.settings_sync_personalization_restored', Number(restored[1]));
    }
    if (text === '个性化设置已同步。') {
      return prefixed
        ? $r('app.string.settings_sync_pref_settings_synced')
        : $r('app.string.settings_sync_personalization_settings_synced');
    }
    if (text === '个性化设置已是最新。') {
      return prefixed
        ? $r('app.string.settings_sync_pref_settings_current')
        : $r('app.string.settings_sync_personalization_settings_current');
    }
    if (text === '个性化设置和小说书架已同步。') {
      return prefixed
        ? $r('app.string.settings_sync_pref_both_synced')
        : $r('app.string.settings_sync_personalization_both_synced');
    }
    if (text === '个性化设置和小说书架已是最新。') {
      return prefixed
        ? $r('app.string.settings_sync_pref_both_current')
        : $r('app.string.settings_sync_personalization_both_current');
    }
    if (text === '小说书架已同步。') {
      return prefixed
        ? $r('app.string.settings_sync_pref_shelf_synced')
        : $r('app.string.settings_sync_personalization_shelf_synced');
    }
    if (text === '小说书架已是最新。') {
      return prefixed
        ? $r('app.string.settings_sync_pref_shelf_current')
        : $r('app.string.settings_sync_personalization_shelf_current');
    }
    if (text === '主页收藏、小说书架和常用设置会在后台同步。') {
      return prefixed
        ? $r('app.string.settings_sync_pref_background')
        : $r('app.string.settings_sync_personalization_background');
    }
    return undefined;
  }

  buildHuaweiSpacePersonalizationSystemUpdateGuidance(errorMessage: string): string {
    return errorMessage.indexOf(HUAWEI_SPACE_PERSONALIZATION_PROGRESS_CODE_ONE) >= 0
      ? HUAWEI_SPACE_PERSONALIZATION_SYSTEM_UPDATE_GUIDANCE
      : '';
  }

  build(input: SyncFailurePresentationInput): SyncFailurePresentation {
    const rawMessage = input.errorMessage.trim();
    const parsedMessage = this.stripFailurePrefix(rawMessage);
    const huaweiCloudPermissionFailure = this.buildHuaweiCloudPermissionFailure(input, parsedMessage, rawMessage);
    if (huaweiCloudPermissionFailure !== null) {
      return huaweiCloudPermissionFailure;
    }
    const httpFailure = this.parseHttpFailure(parsedMessage);
    if (httpFailure !== null) {
      return this.buildHttpFailure(input, httpFailure, rawMessage);
    }

    const fallbackMessage = this.resolveFallbackSummary(parsedMessage, input);
    const diagnostics = this.buildDiagnostics(input, rawMessage.length > 0 ? rawMessage : '未知错误', '');
    return {
      title: $r('app.string.settings_sync_failed'),
      summary: fallbackMessage,
      diagnostics: diagnostics,
      details: [
        { label: '同步方式', value: input.serviceName },
        { label: '操作', value: input.operationName }
      ]
    };
  }

  private buildHttpFailure(
    input: SyncFailurePresentationInput,
    failure: SyncHttpFailure,
    rawMessage: string
  ): SyncFailurePresentation {
    const explanation = this.resolveHttpExplanation(failure.status, failure.provider);
    const details: SyncFailureDetailItem[] = [
      { label: '同步方式', value: input.serviceName },
      { label: '操作', value: input.operationName },
      { label: '请求路径', value: failure.path.length > 0 ? failure.path : '未提供' },
      { label: 'HTTP 状态码', value: `${failure.status}` }
    ];
    const technicalDetails = this.buildTechnicalDetails(details);

    return {
      title: $r('app.string.settings_sync_failed'),
      summary: explanation,
      diagnostics: this.buildDiagnostics(input, rawMessage, technicalDetails),
      details: details
    };
  }

  private parseHttpFailure(message: string): SyncHttpFailure | null {
    const requestFailure = /^(WebDAV|云同步) 请求失败：(.+)，HTTP ([0-9]+)$/.exec(message);
    if (requestFailure !== null) {
      return {
        provider: requestFailure[1],
        action: '请求失败',
        path: requestFailure[2],
        status: Number(requestFailure[3])
      };
    }

    const connectionFailure = /^(WebDAV|云同步) 连接失败：HTTP ([0-9]+)$/.exec(message);
    if (connectionFailure !== null) {
      return {
        provider: connectionFailure[1],
        action: '连接失败',
        path: '',
        status: Number(connectionFailure[2])
      };
    }

    const directoryFailure = /^(WebDAV) 创建目录失败：(.+)，HTTP ([0-9]+)$/.exec(message);
    if (directoryFailure !== null) {
      return {
        provider: directoryFailure[1],
        action: '创建目录失败',
        path: directoryFailure[2],
        status: Number(directoryFailure[3])
      };
    }

    return null;
  }

  private stripFailurePrefix(message: string): string {
    let current = message.trim();
    while (true) {
      const parts = /^(.*?)(?:：|:)\s*(.+)$/.exec(current);
      if (parts === null) {
        return current;
      }
      const prefix = parts[1].trim();
      const suffix = parts[2].trim();
      if (suffix.length === 0 || !this.isLikelyFailurePrefix(prefix)) {
        return current;
      }
      current = suffix;
    }
  }

  private isLikelyFailurePrefix(prefix: string): boolean {
    return prefix.indexOf('失败') >= 0 ||
      prefix.indexOf('错误') >= 0 ||
      prefix.indexOf('异常') >= 0 ||
      prefix.indexOf('超时') >= 0 ||
      prefix.indexOf('无效') >= 0 ||
      prefix.indexOf('未能') >= 0 ||
      prefix.indexOf('无法') >= 0;
  }

  private resolveFallbackSummary(message: string, input: SyncFailurePresentationInput): ResourceStr {
    const normalized = message.trim();
    if (normalized.length === 0) {
      return $r('app.string.settings_sync_advanced_unknown_error');
    }
    const lowerMessage = normalized.toLowerCase();
    if (lowerMessage.indexOf('operation timeout') >= 0 ||
      lowerMessage.indexOf('timeout') >= 0 ||
      lowerMessage.indexOf('timed out') >= 0) {
      return this.resolveTimeoutSummary(input);
    }
    if (lowerMessage.indexOf('socket hang up') >= 0 ||
      lowerMessage.indexOf('connection reset') >= 0 ||
      lowerMessage.indexOf('connection aborted') >= 0) {
      return this.resolveInterruptedMessage(input.serviceName);
    }
    const firstLine = normalized.split('\n')[0].trim();
    if (firstLine.length === 0) {
      return $r('app.string.settings_sync_advanced_unknown_error');
    }
    return this.localizeKnownFailureSummary(firstLine);
  }

  private resolveTimeoutSummary(input: SyncFailurePresentationInput): ResourceStr {
    if (this.isCloudBookmarkSyncService(input.serviceName)) {
      if (input.operationName.indexOf('检查') >= 0) {
        return $r('app.string.settings_sync_fail_timeout_check');
      }
      if (input.serviceName.indexOf('华为') >= 0) {
        return $r('app.string.settings_sync_fail_timeout_huawei');
      }
      return $r('app.string.settings_sync_fail_timeout_cloud');
    }
    return this.resolveServiceTimeoutMessage(input.serviceName);
  }

  private resolveInterruptedMessage(serviceName: string): ResourceStr {
    if (serviceName.indexOf('华为') >= 0) {
      return $r('app.string.settings_sync_fail_interrupted_huawei');
    }
    if (serviceName.indexOf('WebDAV') >= 0) {
      return $r('app.string.settings_sync_fail_interrupted_webdav');
    }
    if (serviceName.indexOf('私有化') >= 0) {
      return $r('app.string.settings_sync_fail_interrupted_self_host');
    }
    if (serviceName.indexOf('云同步') >= 0 || serviceName.indexOf('Cloud') >= 0) {
      return $r('app.string.settings_sync_fail_interrupted_cloud');
    }
    return $r('app.string.settings_sync_fail_interrupted_service');
  }

  private resolveServiceTimeoutMessage(serviceName: string): ResourceStr {
    if (serviceName.indexOf('WebDAV') >= 0) {
      return $r('app.string.settings_sync_fail_timeout_webdav');
    }
    if (serviceName.indexOf('私有化') >= 0) {
      return $r('app.string.settings_sync_fail_timeout_self_host');
    }
    return $r('app.string.settings_sync_fail_timeout_service');
  }

  private resolveHttpExplanation(status: number, provider: string): ResourceStr {
    const webdav = provider === 'WebDAV';
    if (status === 401 || status === 403) {
      return webdav
        ? $r('app.string.settings_sync_fail_http_denied_webdav')
        : $r('app.string.settings_sync_fail_http_denied_cloud');
    }
    if (status === 404) {
      return webdav
        ? $r('app.string.settings_sync_fail_http_missing_webdav')
        : $r('app.string.settings_sync_fail_http_missing_cloud');
    }
    if (status === 409) {
      return webdav
        ? $r('app.string.settings_sync_fail_http_conflict_webdav')
        : $r('app.string.settings_sync_fail_http_conflict_cloud');
    }
    if (status === 423) {
      return webdav
        ? $r('app.string.settings_sync_fail_http_locked_webdav')
        : $r('app.string.settings_sync_fail_http_locked_cloud');
    }
    if (status === 429) {
      return webdav
        ? $r('app.string.settings_sync_fail_http_rate_webdav')
        : $r('app.string.settings_sync_fail_http_rate_cloud');
    }
    if (status === 500) {
      return webdav
        ? $r('app.string.settings_sync_fail_http_server_webdav')
        : $r('app.string.settings_sync_fail_http_server_cloud');
    }
    if (status === 502 || status === 504) {
      return webdav
        ? $r('app.string.settings_sync_fail_http_gateway_webdav')
        : $r('app.string.settings_sync_fail_http_gateway_cloud');
    }
    if (status === 503) {
      return webdav
        ? $r('app.string.settings_sync_fail_http_unavailable_webdav')
        : $r('app.string.settings_sync_fail_http_unavailable_cloud');
    }
    return webdav
      ? $r('app.string.settings_sync_fail_http_status_webdav', status)
      : $r('app.string.settings_sync_fail_http_status_cloud', status);
  }

  private localizeKnownFailureSummary(message: string): ResourceStr {
    if (message === '未知错误') {
      return $r('app.string.settings_sync_advanced_unknown_error');
    }
    if (message === '请先选择同步来源。') {
      return $r('app.string.settings_sync_fail_choose_source');
    }
    if (message === '华为云空间结构化同步拒绝了这次请求。请确认已登录华为账号、系统云空间同步已开启、云侧容器和记录类型已部署，并且云空间容量可用。') {
      return $r('app.string.settings_sync_fail_huawei_denied');
    }
    if (message === 'Aira 云同步拒绝了这次请求。请确认华为账号仍有效，并稍后重试。') {
      return $r('app.string.settings_sync_fail_cloud_denied');
    }
    if (message === '华为云空间结构化同步的云侧记录类型未就绪。请确认 AppGallery Connect 已部署与本机 RDB 表一致的容器和 Record Types。') {
      return $r('app.string.settings_sync_fail_huawei_missing_type');
    }
    if (message === 'Aira 云同步返回了无法识别的数据结构，请稍后重试。') {
      return $r('app.string.settings_sync_fail_cloud_unrecognized');
    }
    return message;
  }

  private buildHuaweiCloudPermissionFailure(
    input: SyncFailurePresentationInput,
    parsedMessage: string,
    rawMessage: string
  ): SyncFailurePresentation | null {
    if (!this.isCloudBookmarkSyncService(input.serviceName)) {
      return null;
    }
    const message = this.huaweiCloudErrorMessageService.build(
      parsedMessage,
      this.resolveHuaweiCloudErrorContext(input.serviceName)
    );
    if (message.userMessage === message.technicalMessage) {
      return null;
    }
    const details: SyncFailureDetailItem[] = [
      { label: '同步方式', value: input.serviceName },
      { label: '操作', value: input.operationName },
      { label: '技术信息', value: message.technicalMessage }
    ];
    return {
      title: $r('app.string.settings_sync_failed'),
      summary: this.localizeKnownFailureSummary(message.userMessage),
      diagnostics: this.buildDiagnostics(input, rawMessage.length > 0 ? rawMessage : message.technicalMessage,
        this.buildTechnicalDetails(details)),
      details: details
    };
  }

  private isCloudBookmarkSyncService(serviceName: string): boolean {
    return serviceName.indexOf('Aira 云同步') >= 0 ||
      serviceName.indexOf('云同步') >= 0 ||
      serviceName.indexOf('华为') >= 0 ||
      serviceName.indexOf('Cloud') >= 0;
  }

  private resolveBookmarkStageLabel(stage: AiraBookmarkSyncFailureStage): string {
    if (stage === 'authentication') {
      return '账号与配置校验';
    }
    if (stage === 'network') {
      return '网络请求';
    }
    if (stage === 'remote_read_validation') {
      return '读取与校验云端快照';
    }
    if (stage === 'local_snapshot') {
      return '生成本机快照';
    }
    if (stage === 'merge') {
      return '合并书签';
    }
    if (stage === 'remote_commit') {
      return '提交云端快照';
    }
    if (stage === 'remote_confirmation') {
      return '确认云端提交';
    }
    if (stage === 'local_apply') {
      return '写入与校验本机书签';
    }
    return '未识别阶段';
  }

  private resolveBookmarkProviderLabel(remoteKind: AiraSyncRemoteKind): string {
    if (remoteKind === 'aira_cloud') {
      return 'Aira 云';
    }
    if (remoteKind === 'huawei_space') {
      return '华为云空间';
    }
    if (remoteKind === 'webdav') {
      return 'WebDAV';
    }
    return '未配置';
  }

  private resolveHuaweiCloudErrorContext(serviceName: string): 'aira_cloud' | 'huawei_space' {
    return serviceName.indexOf('华为云空间') >= 0 ? 'huawei_space' : 'aira_cloud';
  }

  private buildDiagnostics(input: SyncFailurePresentationInput, rawMessage: string, technicalDetails: string): string {
    const lines: string[] = [
      `同步方式：${input.serviceName}`,
      `操作：${input.operationName}`,
      `原始错误：${rawMessage}`
    ];
    if (technicalDetails.length > 0) {
      lines.push('');
      lines.push(technicalDetails);
    }
    return lines.join('\n');
  }

  private buildTechnicalDetails(details: SyncFailureDetailItem[]): string {
    const lines: string[] = ['技术详情'];
    for (let index = 0; index < details.length; index += 1) {
      const detail = details[index];
      lines.push(`${detail.label}：${detail.value}`);
    }
    return lines.join('\n');
  }
}
