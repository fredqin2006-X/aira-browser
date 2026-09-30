/**
 * Maps the privacy-protection page's hardcoded Chinese copy to localized resources.
 * Applied at the settings presentation boundary so the detail view model can stay string-based.
 */
export function localizePrivacyProtectionCopy(value: string): ResourceStr {
  switch (value) {
    case '网页内容过滤':
      return $r('app.string.settings_site_info_content_filter');
    case '已开启':
      return $r('app.string.settings_sync_on');
    case '已关闭':
      return $r('app.string.settings_search_engine_external_off');
    case '需全量模式':
      return $r('app.string.settings_web_full_mode_required');
    case '站点设置':
      return $r('app.string.settings_site_info_site_settings');
    case '外部应用跳转':
      return $r('app.string.settings_site_controls_external_default_title');
    case '防跟踪防护':
      return $r('app.string.settings_site_info_tracking_protection');
    case '标准':
      return $r('app.string.settings_site_info_fingerprint_standard');
    case '阻止':
      return $r('app.string.settings_site_controls_external_default_block');
    case '始终允许':
      return $r('app.string.settings_site_controls_external_default_allow');
    case '跳转前询问':
      return $r('app.string.settings_site_controls_external_default_ask');
    case '重置站点权限':
      return $r('app.string.settings_site_permissions_reset_title');
    case '权限':
      return $r('app.string.settings_site_controls_section_permissions');
    case '维护':
      return $r('app.string.settings_custom_home_maintenance');
    case '隐私防护':
      return $r('app.string.settings_privacy_protection_title');
    case '清除本次私密数据':
      return $r('app.string.settings_privacy_protection_clear_private');
    case '清除浏览数据':
      return $r('app.string.settings_privacy_protection_clear_browsing');
    case '网页防护':
      return $r('app.string.settings_privacy_protection_web_protection');
    case 'Cookie 管理':
      return $r('app.string.settings_privacy_protection_cookie_management');
    case '增强':
      return $r('app.string.settings_privacy_protection_tracking_enhanced');
    case '阻止全部':
      return $r('app.string.settings_privacy_protection_cookie_block_all');
    case '阻止第三方':
      return $r('app.string.settings_privacy_protection_cookie_block_third');
    case '不阻止':
      return $r('app.string.settings_privacy_protection_cookie_allow_all');
    case '增强反跟踪会减少跨网站关联，但不代表完整移除浏览器指纹。':
      return $r('app.string.settings_privacy_protection_web_footer');
    case '权限与隐私数据':
      return $r('app.string.settings_privacy_protection_site_data');
    case '管理站点权限与已保存的站点规则。':
      return $r('app.string.settings_privacy_protection_site_data_footer');
    case '网络保护':
      return $r('app.string.settings_privacy_protection_network');
    case '安全 DNS':
      return $r('app.string.settings_privacy_protection_secure_dns');
    case '安全 DNS 只影响域名解析，不会代理网页流量。':
      return $r('app.string.settings_privacy_protection_network_footer');
    case '密码':
      return $r('app.string.settings_privacy_protection_passwords');
    case '密码管理':
      return $r('app.string.settings_privacy_protection_password_management');
    case '网页密码保险箱、自动填充和保存提示':
      return $r('app.string.settings_privacy_protection_password_helper');
    case '默认允许':
      return $r('app.string.settings_privacy_protection_rule_default_allow');
    case '默认阻止':
      return $r('app.string.settings_privacy_protection_rule_default_block');
    case '每次请求都确认':
      return $r('app.string.settings_privacy_protection_rule_ask_each');
    case '没有单独规则时使用':
      return $r('app.string.settings_privacy_protection_permission_helper');
    case '本次会话站点':
      return $r('app.string.settings_privacy_protection_session_sites');
    case '已保存站点':
      return $r('app.string.settings_privacy_protection_saved_sites');
    case '允许规则':
      return $r('app.string.settings_privacy_protection_allow_rules');
    case '阻止规则':
      return $r('app.string.settings_privacy_protection_block_rules');
    case '已保存权限统计':
      return $r('app.string.settings_privacy_protection_saved_stats');
    case '权限管理':
      return $r('app.string.settings_privacy_protection_permission_management');
    case '清除临时权限':
      return $r('app.string.settings_privacy_protection_clear_temp_permissions');
    case '刷新中...':
      return $r('app.string.settings_privacy_protection_refreshing_icons');
    case '刷新网站图标':
      return $r('app.string.settings_privacy_protection_refresh_icons');
    case '私密会话不刷新常规图标缓存。':
      return $r('app.string.settings_privacy_protection_icons_private_footer');
    case '重新获取书签、历史、快捷方式和离线页面的网站图标。':
      return $r('app.string.settings_privacy_protection_icons_footer');
    case '取消':
      return $r('app.string.settings_privacy_protection_dialog_cancel');
    case '刷新网站图标？':
      return $r('app.string.settings_privacy_protection_refresh_icons_title');
    case '会保留当前图标，并在后台重新获取高清图标。获取失败的网站会继续显示文字图标或旧图标。':
      return $r('app.string.settings_privacy_protection_refresh_icons_message');
    case '开始刷新':
      return $r('app.string.settings_privacy_protection_start_refresh');
    case '正在刷新网站图标...':
      return $r('app.string.settings_privacy_protection_refreshing');
    case '网站图标刷新失败，请稍后再试。':
      return $r('app.string.settings_privacy_protection_refresh_failed');
    case '清除全部浏览数据':
      return $r('app.string.settings_privacy_protection_clear_all_title');
    case '清除数据、Cookie、缓存和站点权限。':
      return $r('app.string.settings_privacy_protection_clear_all_message');
    case '清除本次私密数据，不影响常规资料。':
      return $r('app.string.settings_privacy_protection_clear_private_message');
    case '清除':
      return $r('app.string.settings_privacy_protection_clear_confirm');
    case '仅清除本次私密会话数据，不影响常规浏览资料。':
      return $r('app.string.settings_privacy_protection_clear_dialog_private_message');
    case '时间范围适用于历史记录和最近关闭；Cookie、缓存、站点存储按系统 Web 能力清除全部。':
      return $r('app.string.settings_privacy_protection_clear_dialog_message');
    case '时间范围':
      return $r('app.string.settings_privacy_protection_time_range');
    case '数据类型':
      return $r('app.string.settings_privacy_protection_data_types');
    case '最近 1 小时':
      return $r('app.string.settings_privacy_protection_range_last_hour');
    case '最近 24 小时':
      return $r('app.string.settings_privacy_protection_range_last_day');
    case '最近 7 天':
      return $r('app.string.settings_privacy_protection_range_last_7_days');
    case '全部时间':
      return $r('app.string.settings_privacy_protection_range_all');
    case '浏览数据范围不一致，未执行清理。':
      return $r('app.string.settings_privacy_protection_clear_range_mismatch');
    case '请选择要清除的数据。':
      return $r('app.string.settings_privacy_protection_clear_nothing_selected');
    case '临时权限：清除失败':
      return $r('app.string.settings_privacy_protection_clear_temp_permission_failed');
    case '所选浏览数据已清除。':
      return $r('app.string.settings_privacy_protection_clear_done');
    case '历史记录':
      return $r('app.string.settings_privacy_protection_item_history');
    case '地址栏建议和历史页面中的访问记录':
      return $r('app.string.settings_privacy_protection_item_history_summary');
    case '最近关闭':
      return $r('app.string.settings_privacy_protection_item_recently_closed');
    case '主页和标签页恢复使用的最近关闭记录':
      return $r('app.string.settings_privacy_protection_item_recently_closed_summary');
    case 'Cookie':
      return $r('app.string.settings_privacy_protection_item_cookies');
    case '网站登录状态和会话 Cookie':
      return $r('app.string.settings_privacy_protection_item_cookies_summary');
    case '缓存':
      return $r('app.string.settings_privacy_protection_item_cache');
    case '网页资源缓存':
      return $r('app.string.settings_privacy_protection_item_cache_summary');
    case '站点存储':
      return $r('app.string.settings_privacy_protection_item_site_storage');
    case '网站保存的本地数据':
      return $r('app.string.settings_privacy_protection_item_site_storage_summary');
    case '站点权限':
      return $r('app.string.settings_privacy_protection_item_site_permissions');
    case '已保存的相机、麦克风、位置等权限':
      return $r('app.string.settings_privacy_protection_item_site_permissions_summary');
    case '本次私密 Cookie':
      return $r('app.string.settings_privacy_protection_item_private_cookies');
    case '清除本次私密会话中的全部 Cookie':
      return $r('app.string.settings_privacy_protection_item_private_cookies_summary');
    case '本次私密站点存储':
      return $r('app.string.settings_privacy_protection_item_private_storage');
    case '清除本次私密会话中的站点数据':
      return $r('app.string.settings_privacy_protection_item_private_storage_summary');
    case '本次临时权限':
      return $r('app.string.settings_privacy_protection_item_private_permissions');
    case '清除本次私密会话授权':
      return $r('app.string.settings_privacy_protection_item_private_permissions_summary');
    case '过滤已开启':
      return $r('app.string.settings_privacy_protection_overview_filter_on');
    case '过滤已关闭':
      return $r('app.string.settings_privacy_protection_overview_filter_off');
    case '今天':
      return $r('app.string.settings_privacy_protection_today');
    case '日':
      return $r('app.string.settings_privacy_protection_weekday_short_sun');
    case '一':
      return $r('app.string.settings_privacy_protection_weekday_short_mon');
    case '二':
      return $r('app.string.settings_privacy_protection_weekday_short_tue');
    case '三':
      return $r('app.string.settings_privacy_protection_weekday_short_wed');
    case '四':
      return $r('app.string.settings_privacy_protection_weekday_short_thu');
    case '五':
      return $r('app.string.settings_privacy_protection_weekday_short_fri');
    case '六':
      return $r('app.string.settings_privacy_protection_weekday_short_sat');
    case '周日':
      return $r('app.string.settings_privacy_protection_weekday_detail_sun');
    case '周一':
      return $r('app.string.settings_privacy_protection_weekday_detail_mon');
    case '周二':
      return $r('app.string.settings_privacy_protection_weekday_detail_tue');
    case '周三':
      return $r('app.string.settings_privacy_protection_weekday_detail_wed');
    case '周四':
      return $r('app.string.settings_privacy_protection_weekday_detail_thu');
    case '周五':
      return $r('app.string.settings_privacy_protection_weekday_detail_fri');
    case '周六':
      return $r('app.string.settings_privacy_protection_weekday_detail_sat');
    case '自动优选':
      return $r('app.string.settings_privacy_protection_dns_auto');
    case '自定义 DoH':
      return $r('app.string.settings_privacy_protection_dns_custom');
    case '系统 DNS':
      return $r('app.string.settings_privacy_protection_dns_system');
    case '强制 DoH':
      return $r('app.string.settings_privacy_protection_dns_force_doh');
    case 'DNS 服务':
      return $r('app.string.settings_privacy_protection_dns_service');
    case '解析策略':
      return $r('app.string.settings_privacy_protection_dns_strategy');
    case '开启后不回退系统 DNS，DoH 服务器不可用时网页将无法加载；关闭后会自动回退，域名解析可能是明文。选择系统 DNS 时此开关不生效。':
      return $r('app.string.settings_privacy_protection_dns_strategy_footer');
    case '自定义 DNS':
      return $r('app.string.settings_privacy_protection_dns_custom_section');
    case '还没有自定义 DNS，可从右上角添加。':
      return $r('app.string.settings_privacy_protection_dns_empty');
    case '编辑自定义 DNS':
      return $r('app.string.settings_privacy_protection_dns_edit_title');
    case '保存中...':
      return $r('app.string.settings_privacy_protection_dns_saving');
    case '保存并使用':
      return $r('app.string.settings_privacy_protection_dns_save_use');
    case '名称':
      return $r('app.string.settings_privacy_protection_dns_name');
    case '例如：家庭 DNS / 公司 DNS':
      return $r('app.string.settings_privacy_protection_dns_name_placeholder');
    case 'DoH 地址':
      return $r('app.string.settings_privacy_protection_dns_endpoint');
    case '删除中...':
      return $r('app.string.settings_privacy_protection_dns_deleting');
    case '删除 DNS':
      return $r('app.string.settings_privacy_protection_dns_delete');
    case '这个 DNS':
      return $r('app.string.settings_privacy_protection_dns_this');
    case '删除自定义 DNS':
      return $r('app.string.settings_privacy_protection_dns_delete_title');
    case '这个自定义 DNS 已不存在。':
      return $r('app.string.settings_privacy_protection_dns_not_exist');
    case '保存失败，请稍后重试。':
      return $r('app.string.settings_privacy_protection_dns_save_failed');
    case '删除失败，请稍后重试。':
      return $r('app.string.settings_privacy_protection_dns_delete_failed');
    case '当前模式下无法保存设备 DNS 设置。':
      return $r('app.string.settings_privacy_protection_dns_no_device_save');
    case '当前模式下无法删除设备 DNS 设置。':
      return $r('app.string.settings_privacy_protection_dns_no_device_delete');
    case '请输入 DNS 名称。':
      return $r('app.string.settings_privacy_protection_dns_name_required');
    case 'DNS 名称不能超过 80 个字符。':
      return $r('app.string.settings_privacy_protection_dns_name_too_long');
    case '最多可保存 32 个自定义 DNS。':
      return $r('app.string.settings_privacy_protection_dns_name_limit');
    case '已有同名的自定义 DNS。':
      return $r('app.string.settings_privacy_protection_dns_name_duplicate');
    case '这个 DoH 地址已经保存。':
      return $r('app.string.settings_privacy_protection_dns_endpoint_duplicate');
    case '请输入 HTTPS DoH 地址。':
      return $r('app.string.settings_privacy_protection_dns_endpoint_required');
    case '仅支持 HTTPS 地址。':
      return $r('app.string.settings_privacy_protection_dns_endpoint_https');
    case '请输入有效的 HTTPS DoH 地址。':
      return $r('app.string.settings_privacy_protection_dns_endpoint_invalid');
    case '网页安全':
      return $r('app.string.settings_privacy_protection_web_security');
    case '始终优先使用 HTTPS':
      return $r('app.string.settings_privacy_protection_https_first');
    case '优先使用安全连接；网站不支持时再使用 HTTP。':
      return $r('app.string.settings_privacy_protection_https_first_footer');
    case '网站安全提醒':
      return $r('app.string.settings_privacy_protection_safe_browsing');
    case '开启后，Aira 会借助华为安全检测识别可疑网站，并在页面顶部提醒你。为完成检测，你访问的网址会发送给华为。':
      return $r('app.string.settings_privacy_protection_safe_browsing_footer');
    case '允许 JavaScript':
      return $r('app.string.settings_privacy_protection_javascript');
    case '网站通常需要 JavaScript 才能正常登录、支付或播放视频；你可以为特定网站设置例外。':
      return $r('app.string.settings_privacy_protection_javascript_footer');
    case 'JavaScript 网站例外':
      return $r('app.string.settings_privacy_protection_javascript_exceptions');
    case '关闭 JavaScript？':
      return $r('app.string.settings_privacy_protection_javascript_off_title');
    case '大多数网站依赖 JavaScript。关闭后，登录、支付、视频和交互内容可能无法正常使用。':
      return $r('app.string.settings_privacy_protection_javascript_off_message');
    case '仍要关闭':
      return $r('app.string.settings_privacy_protection_javascript_off_confirm');
    case '当前策略':
      return $r('app.string.settings_privacy_protection_tracking_current');
    case '网页客户端提示':
      return $r('app.string.settings_privacy_protection_tracking_client_hints');
    case '第三方 Cookie':
      return $r('app.string.settings_privacy_protection_tracking_cookie');
    case '网页标识':
      return $r('app.string.settings_privacy_protection_tracking_identity');
    case '已收紧':
      return $r('app.string.settings_privacy_protection_tracking_tightened');
    case '未完全生效':
      return $r('app.string.settings_privacy_protection_tracking_not_applied');
    case '已拦截':
      return $r('app.string.settings_privacy_protection_tracking_blocked');
    case '保持一致':
      return $r('app.string.settings_privacy_protection_tracking_consistent');
    case '兼容模式':
      return $r('app.string.settings_privacy_protection_tracking_compatible');
    case '增强反跟踪':
      return $r('app.string.settings_privacy_protection_tracking_enhanced_option');
    case '开启增强反跟踪？':
      return $r('app.string.settings_privacy_protection_tracking_enhanced_title');
    case '将收紧网页客户端提示并拦截第三方 Cookie。少数登录、支付或嵌入内容可能受影响；现有网页重新加载后完整生效。':
      return $r('app.string.settings_privacy_protection_tracking_enhanced_message');
    case '减少跨网站关联：收紧网页客户端提示、拦截第三方 Cookie，并保持网页标识一致。现有网页重新加载后完整生效。':
      return $r('app.string.settings_privacy_protection_tracking_footer_enhanced');
    case '使用当前网页兼容性策略，第三方 Cookie 和网页客户端提示由各自设置控制。':
      return $r('app.string.settings_privacy_protection_tracking_footer_standard');
    case '增强反跟踪不会伪装 Canvas、WebGL、字体、时区或屏幕渲染，也不是匿名度评分。':
      return $r('app.string.settings_privacy_protection_tracking_limit_applied');
    case '防跟踪策略已应用。':
      return $r('app.string.settings_privacy_protection_tracking_applied');
    case '部分防跟踪策略未能应用，请重启 Aira 后重试。':
      return $r('app.string.settings_privacy_protection_tracking_partial');
    case '仅阻止第三方 Cookie':
      return $r('app.string.settings_privacy_protection_cookie_block_third_option');
    case '阻止所有 Cookie':
      return $r('app.string.settings_privacy_protection_cookie_block_all_option');
    case '当前私密会话沿用全局 Cookie 策略，请在常规设置中修改。':
      return $r('app.string.settings_privacy_protection_cookie_footer_locked');
    case '增强反跟踪已自动拦截第三方 Cookie。关闭增强反跟踪后，可选择“不阻止”。':
      return $r('app.string.settings_privacy_protection_cookie_footer_enhanced');
    case '阻止所有 Cookie 可能导致登录、购物车等网页功能无法正常使用。':
      return $r('app.string.settings_privacy_protection_cookie_footer_block_all');
    case '阻止第三方 Cookie 可减少跨网站跟踪，同时兼顾大多数网页的正常使用。':
      return $r('app.string.settings_privacy_protection_cookie_footer_block_third');
    case '官方能力':
      return $r('app.string.settings_privacy_protection_password_official');
    case '网页密码保险箱':
      return $r('app.string.settings_privacy_protection_password_vault');
    case '使用系统密码能力':
      return $r('app.string.settings_privacy_protection_password_vault_detail');
    case '普通标签页':
      return $r('app.string.settings_privacy_protection_password_regular');
    case '自动填充已有密码':
      return $r('app.string.settings_privacy_protection_password_autofill');
    case '由系统验证后填充':
      return $r('app.string.settings_privacy_protection_password_autofill_detail');
    case '提示保存新密码':
      return $r('app.string.settings_privacy_protection_password_save_prompt');
    case '登录后询问保存':
      return $r('app.string.settings_privacy_protection_password_save_prompt_detail');
    case '普通标签页规则':
      return $r('app.string.settings_privacy_protection_password_regular_rules');
    case '当前规则':
      return $r('app.string.settings_privacy_protection_password_current_rule');
    case '私密标签页':
      return $r('app.string.settings_privacy_protection_password_private');
    case '一次性填充已有密码':
      return $r('app.string.settings_privacy_protection_password_private_autofill');
    case '不保存新密码':
      return $r('app.string.settings_privacy_protection_password_private_no_save');
    case '私密标签页规则':
      return $r('app.string.settings_privacy_protection_password_private_rules');
    case '保存新密码':
      return $r('app.string.settings_privacy_protection_password_save_new');
    case '始终关闭':
      return $r('app.string.settings_privacy_protection_password_always_off');
    case '保护':
      return $r('app.string.settings_privacy_protection_adblock_protection');
    case '按你启用的规则过滤网页内容':
      return $r('app.string.settings_privacy_protection_adblock_subtitle');
    case '过滤规则':
      return $r('app.string.settings_privacy_protection_adblock_rules');
    case '管理第三方和自定义过滤规则':
      return $r('app.string.settings_privacy_protection_adblock_rules_detail');
    case '页面元素清理':
      return $r('app.string.settings_privacy_protection_adblock_elements');
    case '管理':
      return $r('app.string.settings_privacy_protection_adblock_manage');
    case '查看和恢复你手动隐藏的网页元素':
      return $r('app.string.settings_privacy_protection_adblock_hidden_detail');
    case '清空统计':
      return $r('app.string.settings_privacy_protection_adblock_clear_stats');
    case '站点例外':
      return $r('app.string.settings_privacy_protection_adblock_exceptions');
    case '暂无站点例外':
      return $r('app.string.settings_privacy_protection_adblock_no_exceptions');
    case '移除':
      return $r('app.string.settings_privacy_protection_adblock_remove');
    case '清空拦截统计':
      return $r('app.string.settings_privacy_protection_adblock_clear_title');
    case '清空后不会影响网页内容过滤规则和站点例外。':
      return $r('app.string.settings_privacy_protection_adblock_clear_message');
    case '清空':
      return $r('app.string.settings_privacy_protection_adblock_clear_confirm');
    default:
      return value;
  }
}
