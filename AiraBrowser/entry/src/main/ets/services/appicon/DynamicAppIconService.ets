import { appInfoManager } from '@kit.AppGalleryKit';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';
import { BusinessError } from '@kit.BasicServicesKit';

export interface DynamicAppIconOption {
  iconId: string;
  iconUrl: string;
  enabled: boolean;
}

export type DynamicAppIconAvailability =
  'available' |
  'empty' |
  'service_unavailable' |
  'internal_error';

export interface DynamicAppIconQueryResult {
  availability: DynamicAppIconAvailability;
  icons: DynamicAppIconOption[];
  code: number;
  message: ResourceStr;
}

export type DynamicAppIconMutationKind = 'select' | 'restore_default';

export interface DynamicAppIconMutationResult {
  ok: boolean;
  kind: DynamicAppIconMutationKind;
  code: number;
  message: string;
}

const DYNAMIC_ICON_SERVICE_CONNECT_FAILED_CODE: number = 1006800001;
const DYNAMIC_ICON_INTERNAL_ERROR_CODE: number = 1006800009;
const DYNAMIC_ICON_NO_DATA_CODE: number = 1006800010;
const DYNAMIC_ICON_SELECT_FAILED_CODE: number = 1006800011;
const DYNAMIC_ICON_DISABLE_FAILED_CODE: number = 1006800012;
const DYNAMIC_ICON_CUSTOM_THEME_CONFLICT_CODE: number = 1006800013;

export class DynamicAppIconService {
  async queryIcons(): Promise<DynamicAppIconQueryResult> {
    try {
      const icons = await appInfoManager.queryDynamicIcons();
      const mappedIcons = icons.map((icon: appInfoManager.DynamicIconInfo): DynamicAppIconOption => {
        return {
          iconId: icon.iconId,
          iconUrl: icon.iconUrl,
          enabled: icon.enabled
        };
      });
      return {
        availability: mappedIcons.length > 0 ? 'available' : 'empty',
        icons: mappedIcons,
        code: 0,
        message: mappedIcons.length > 0 ? '' : resolveAppResourceText($r('app.string.settings_app_icon_12'))
      };
    } catch (error) {
      return this.buildQueryFailure(error as BusinessError);
    }
  }

  async selectIcon(iconId: string): Promise<DynamicAppIconMutationResult> {
    const normalizedIconId = iconId.trim();
    if (normalizedIconId.length <= 0) {
      return {
        ok: false,
        kind: 'select',
        code: 401,
        message: resolveAppResourceText($r('app.string.app_icon_invalid'))
      };
    }
    try {
      await appInfoManager.selectDynamicIcon(normalizedIconId);
      return {
        ok: true,
        kind: 'select',
        code: 0,
        message: resolveAppResourceText($r('app.string.app_icon_updated'))
      };
    } catch (error) {
      return this.buildMutationFailure('select', error as BusinessError);
    }
  }

  async restoreDefaultIcon(): Promise<DynamicAppIconMutationResult> {
    try {
      await appInfoManager.disableDynamicIcon();
      return {
        ok: true,
        kind: 'restore_default',
        code: 0,
        message: resolveAppResourceText($r('app.string.app_icon_restored'))
      };
    } catch (error) {
      return this.buildMutationFailure('restore_default', error as BusinessError);
    }
  }

  private buildQueryFailure(error: BusinessError): DynamicAppIconQueryResult {
    const code = Number(error?.code ?? 0);
    if (code === DYNAMIC_ICON_NO_DATA_CODE) {
      return {
        availability: 'empty',
        icons: [],
        code: code,
        message: resolveAppResourceText($r('app.string.settings_app_icon_12'))
      };
    }
    if (code === DYNAMIC_ICON_SERVICE_CONNECT_FAILED_CODE) {
      return {
        availability: 'service_unavailable',
        icons: [],
        code: code,
        message: resolveAppResourceText($r('app.string.settings_app_icon_01'))
      };
    }
    if (code === DYNAMIC_ICON_INTERNAL_ERROR_CODE) {
      return {
        availability: 'internal_error',
        icons: [],
        code: code,
        message: resolveAppResourceText($r('app.string.app_icon_read_failed'))
      };
    }
    return {
      availability: 'service_unavailable',
      icons: [],
      code: code,
      message: resolveAppResourceText($r('app.string.app_icon_read_unavailable'))
    };
  }

  private buildMutationFailure(
    kind: DynamicAppIconMutationKind,
    error: BusinessError
  ): DynamicAppIconMutationResult {
    const code = Number(error?.code ?? 0);
    return {
      ok: false,
      kind: kind,
      code: code,
      message: this.resolveMutationFailureMessage(kind, code)
    };
  }

  private resolveMutationFailureMessage(kind: DynamicAppIconMutationKind, code: number): string {
    if (code === DYNAMIC_ICON_CUSTOM_THEME_CONFLICT_CODE) {
      return resolveAppResourceText($r('app.string.app_icon_theme_conflict'));
    }
    if (kind === 'select' && code === DYNAMIC_ICON_SELECT_FAILED_CODE) {
      return resolveAppResourceText($r('app.string.app_icon_select_retry'));
    }
    if (kind === 'restore_default' && code === DYNAMIC_ICON_DISABLE_FAILED_CODE) {
      return resolveAppResourceText($r('app.string.app_icon_restore_retry'));
    }
    if (code === DYNAMIC_ICON_INTERNAL_ERROR_CODE) {
      return resolveAppResourceText($r('app.string.app_icon_service_error'));
    }
    return kind === 'select'
      ? resolveAppResourceText($r('app.string.app_icon_select_failed'))
      : resolveAppResourceText($r('app.string.app_icon_restore_failed'));
  }
}
