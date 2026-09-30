/**
 * Maps the advanced-settings page (and its app-service-mode subpage) hardcoded Chinese
 * copy to localized resources. Applied at the settings presentation boundary so the
 * detail view model can stay string-based.
 */
export function localizeAdvancedSettingsCopy(value: ResourceStr): ResourceStr {
  if (typeof value !== 'string') {
    return value;
  }
  switch (value) {
    // Advanced settings
    case '高级设置':
      return $r('app.string.settings_advanced_title');
    case '标签页运行策略':
      return $r('app.string.settings_advanced_tab_runtime_section');
    case '后台标签页资源管理':
      return $r('app.string.settings_advanced_retention_row');
    case '私密中不改全局设置。':
      return $r('app.string.settings_advanced_retention_locked_footer');
    case '这里设置平时的保活偏好。系统内存紧张时，Aira 会临时降低后台保活数量。':
      return $r('app.string.settings_advanced_retention_footer');
    case '本地数据':
      return $r('app.string.settings_advanced_local_data_section');
    case '本地备份':
      return $r('app.string.settings_advanced_local_backup_row');
    case '服务模式':
      return $r('app.string.settings_advanced_service_mode_section');
    case '全量模式或基本模式':
      return $r('app.string.settings_advanced_service_mode_summary');
    // Retention profiles (shared by the list row and the subpage)
    case '省电优先':
      return $r('app.string.settings_advanced_retention_memory_saver');
    case '均衡':
      return $r('app.string.settings_advanced_retention_balanced');
    case '多标签性能':
      return $r('app.string.settings_advanced_retention_keep_more_tabs');
    case '更快释放后台标签页':
      return $r('app.string.settings_advanced_retention_memory_saver_short');
    case '日常推荐':
      return $r('app.string.settings_advanced_retention_balanced_short');
    case '保留更多后台标签页':
      return $r('app.string.settings_advanced_retention_keep_more_tabs_short');
    // App service mode subpage
    case '应用服务模式':
      return $r('app.string.settings_advanced_service_mode_title');
    case '全量模式':
      return $r('app.string.settings_advanced_service_mode_full');
    case '基本模式':
      return $r('app.string.settings_advanced_service_mode_basic');
    case '账号登录、云同步、远程建议、壁纸、翻译、会员、脚本、网页内容过滤和视频增强可用。':
      return $r('app.string.settings_advanced_service_mode_full_desc');
    case '仅保留基础浏览和本地数据能力，大部分增强功能不可用。':
      return $r('app.string.settings_advanced_service_mode_basic_desc');
    case '当前会话不可修改设备设置':
      return $r('app.string.settings_advanced_service_mode_basic_locked_session');
    case '私密会话不能停用同步':
      return $r('app.string.settings_advanced_service_mode_basic_locked_sync');
    case '切换到基本模式会关闭账号登录、同步、会员、翻译、脚本、网页内容过滤、壁纸、远程建议和实验功能；已保存的数据不会被删除。':
      return $r('app.string.settings_advanced_service_mode_footer');
    default:
      return value;
  }
}
