export function localizeAboutSettingsCopy(value: ResourceStr): ResourceStr {
  if (typeof value !== 'string') {
    return value;
  }
  switch (value) {
    case '应用名称':
      return $r('app.string.settings_about_app_name');
    case '版本':
      return $r('app.string.user_script_meta_version');
    case '包名':
      return $r('app.string.settings_about_bundle');
    case '更新日志':
      return $r('app.string.settings_about_changelog');
    case '检查更新':
      return $r('app.string.user_script_check_updates');
    case '好评鼓励':
      return $r('app.string.settings_about_rate');
    case '交流QQ群':
      return $r('app.string.settings_qq_group_title');
    case '交流Telegram群':
      return $r('app.string.settings_about_telegram');
    case '源代码仓库':
      return $r('app.string.settings_about_source');
    case '开源许可':
      return $r('app.string.settings_about_license');
    case '第三方开源许可':
      return $r('app.string.settings_about_third_party');
    case '安全问题反馈':
      return $r('app.string.settings_about_security');
    case '用户服务协议':
      return $r('app.string.settings_about_user_agreement');
    case '隐私声明':
      return $r('app.string.settings_about_privacy');
    case 'Aira Pro会员服务协议':
      return $r('app.string.settings_pro_legal_membership_full');
    case 'Aira Pro自动续费服务协议':
      return $r('app.string.settings_pro_legal_renewal_full');
    case '第三方SDK及第三方服务清单':
      return $r('app.string.settings_about_sdk_list');
    case '个人信息收集与权限使用清单':
      return $r('app.string.settings_about_personal_info');
    case '备案号':
      return $r('app.string.settings_about_icp');
    case 'Aira 源代码按 GPL-3.0-only 发布；第三方组件和品牌资产按各自许可使用。':
      return $r('app.string.settings_about_open_source_footer');
    case '相关协议和清单由 Aira 官方公开网页提供。':
      return $r('app.string.settings_about_legal_footer');
    default:
      return value;
  }
}

export function localizeAboutLegalDocumentTitle(documentId: string): ResourceStr {
  if (documentId === 'user_service_agreement') {
    return $r('app.string.settings_pro_legal_user');
  }
  if (documentId === 'privacy_statement') {
    return $r('app.string.settings_pro_legal_privacy');
  }
  if (documentId === 'pro_membership_service_agreement') {
    return $r('app.string.settings_pro_legal_membership_full');
  }
  if (documentId === 'pro_auto_renewal_service_agreement') {
    return $r('app.string.settings_pro_legal_renewal_full');
  }
  if (documentId === 'third_party_sdk_and_services') {
    return $r('app.string.settings_about_sdk_list_full');
  }
  if (documentId === 'personal_info_and_permissions') {
    return $r('app.string.settings_about_personal_info_full');
  }
  return $r('app.string.settings_pro_legal_user');
}

export function localizeCommunityUpdateMessage(outcome: string, versionName: string, fallback: string): ResourceStr {
  if (outcome === 'update_available') {
    return versionName.length > 0 ? $r('app.string.settings_about_update_available', versionName) : fallback;
  }
  if (outcome === 'up_to_date') {
    return $r('app.string.settings_about_up_to_date', versionName);
  }
  if (outcome === 'not_applicable') {
    return $r('app.string.settings_about_update_store');
  }
  if (outcome === 'failed') {
    return $r('app.string.settings_about_update_failed');
  }
  return fallback;
}

export function localizeAboutReviewFailure(message: string): ResourceStr {
  if (message.length === 0 ||
    message === '应用市场暂时无法打开。' ||
    message === '暂时无法打开评分弹窗。' ||
    message.indexOf('打开链接失败：') === 0) {
    return $r('app.string.settings_about_review_failed');
  }
  return message;
}
