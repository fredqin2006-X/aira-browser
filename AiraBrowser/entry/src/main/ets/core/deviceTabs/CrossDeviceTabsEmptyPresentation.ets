import { resolveAppResourceText } from '../resources/AppResourceText';

export type CrossDeviceTabsEmptyKind =
  'none' |
  'sign_in' |
  'pro_required' |
  'pro_expired' |
  'link_disabled' |
  'no_devices' |
  'connect_personal_server' |
  'error';

export type CrossDeviceTabsEmptyAction =
  'none' |
  'sign_in' |
  'open_pro' |
  'enable_link' |
  'open_setup' |
  'open_sync_settings' |
  'open_guide' |
  'refresh';

export interface CrossDeviceTabsEmptyPresentation {
  kind: CrossDeviceTabsEmptyKind;
  title: string;
  message: string;
  primaryAction: CrossDeviceTabsEmptyAction;
  primaryLabel: string;
  secondaryAction: CrossDeviceTabsEmptyAction;
  secondaryLabel: string;
}

export const CROSS_DEVICE_TABS_EMPTY_NONE: CrossDeviceTabsEmptyPresentation = {
  kind: 'none',
  title: '',
  message: '',
  primaryAction: 'none',
  primaryLabel: '',
  secondaryAction: 'none',
  secondaryLabel: ''
};

/**
 * Copy and actions for the cross-device tab's in-place empty page.
 * The presence owner decides which kind applies; this function only names it.
 */
export function buildCrossDeviceTabsEmptyPresentation(
  kind: CrossDeviceTabsEmptyKind,
  detail: string = ''
): CrossDeviceTabsEmptyPresentation {
  if (kind === 'sign_in') {
    return {
      kind: kind,
      title: resolveAppResourceText($r('app.string.device_tabs_sign_in_title')),
      message: resolveAppResourceText($r('app.string.device_tabs_sign_in_message')),
      primaryAction: 'sign_in',
      primaryLabel: resolveAppResourceText($r('app.string.settings_pro_sign_in_title')),
      secondaryAction: 'none',
      secondaryLabel: ''
    };
  }
  if (kind === 'pro_required') {
    return {
      kind: kind,
      title: resolveAppResourceText($r('app.string.device_tabs_pro_required_title')),
      message: resolveAppResourceText($r('app.string.device_tabs_pro_required_message')),
      primaryAction: 'open_pro',
      primaryLabel: resolveAppResourceText($r('app.string.device_tabs_learn_pro')),
      secondaryAction: 'open_guide',
      secondaryLabel: resolveAppResourceText($r('app.string.device_tabs_use_personal_server'))
    };
  }
  if (kind === 'pro_expired') {
    return {
      kind: kind,
      title: resolveAppResourceText($r('app.string.membership_gate_expired_title')),
      message: resolveAppResourceText($r('app.string.device_tabs_pro_expired_message')),
      primaryAction: 'open_pro',
      primaryLabel: resolveAppResourceText($r('app.string.device_tabs_learn_pro')),
      secondaryAction: 'open_guide',
      secondaryLabel: resolveAppResourceText($r('app.string.device_tabs_use_personal_server'))
    };
  }
  if (kind === 'link_disabled') {
    return {
      kind: kind,
      title: resolveAppResourceText($r('app.string.device_tabs_link_disabled_title')),
      message: resolveAppResourceText($r('app.string.device_tabs_link_disabled_message')),
      primaryAction: 'enable_link',
      primaryLabel: resolveAppResourceText($r('app.string.device_tabs_enable_link')),
      secondaryAction: 'none',
      secondaryLabel: ''
    };
  }
  if (kind === 'no_devices') {
    return {
      kind: kind,
      title: resolveAppResourceText($r('app.string.device_tabs_no_computer_title')),
      message: resolveAppResourceText($r('app.string.device_tabs_no_computer_message')),
      primaryAction: 'open_setup',
      primaryLabel: resolveAppResourceText($r('app.string.device_tabs_view_setup')),
      secondaryAction: 'refresh',
      secondaryLabel: resolveAppResourceText($r('app.string.offline_action_refresh'))
    };
  }
  if (kind === 'connect_personal_server') {
    const credentials = detail === 'credentials';
    return {
      kind: kind,
      title: resolveAppResourceText($r('app.string.device_tabs_connect_server_title')),
      message: credentials
        ? resolveAppResourceText($r('app.string.device_tabs_server_credentials'))
        : resolveAppResourceText($r('app.string.device_tabs_server_setup')),
      primaryAction: 'open_sync_settings',
      primaryLabel: resolveAppResourceText($r('app.string.device_tabs_open_sync_settings')),
      secondaryAction: 'none',
      secondaryLabel: ''
    };
  }
  if (kind === 'error') {
    const message = detail.trim().length > 0
      ? detail.trim()
      : resolveAppResourceText($r('app.string.device_tabs_unavailable'));
    return {
      kind: kind,
      title: resolveAppResourceText($r('app.string.device_tabs_unavailable_title')),
      message: message,
      primaryAction: 'refresh',
      primaryLabel: resolveAppResourceText($r('app.string.offline_action_refresh')),
      secondaryAction: 'none',
      secondaryLabel: ''
    };
  }
  return CROSS_DEVICE_TABS_EMPTY_NONE;
}
