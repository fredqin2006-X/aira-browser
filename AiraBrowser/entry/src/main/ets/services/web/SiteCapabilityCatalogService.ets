import { Permissions } from '@kit.AbilityKit';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';
import {
  ExternalNavigationAppOpenPolicy,
  SitePermissionKind,
  SitePermissionRule
} from '../../common/models/BrowserModels';

export type SiteCapabilityId =
  'camera' |
  'microphone' |
  'location' |
  'sensor' |
  'clipboard' |
  'open_app';

export type SiteCustomizationCapabilityFilterId =
  'external_actions' |
  'desktop_site' |
  'private_site' |
  'javascript';

export type SiteCapabilityGroup =
  'device_permission' |
  'navigation_policy';

export interface SiteCapabilityDefinition {
  id: SiteCapabilityId;
  group: SiteCapabilityGroup;
  title: string;
  objectLabel: string;
  summaryLabel: string;
  canSetDefault: boolean;
  canSetSiteRule: boolean;
  requiresSystemPermission: boolean;
}

export interface SitePermissionRuleOption {
  value: SitePermissionRule;
  label: string;
  helperText: string;
}

export interface ExternalNavigationPolicyOption {
  value: ExternalNavigationAppOpenPolicy;
  label: string;
  helperText: string;
}

export interface SiteProtectedResourceResolution {
  resources: string[];
  kinds: SitePermissionKind[];
  unsupportedResources: string[];
}

export class SiteCapabilityCatalogService {
  listDevicePermissionKinds(): SitePermissionKind[] {
    return ['location', 'camera', 'microphone', 'sensor', 'clipboard'];
  }

  getDevicePermissionDefinition(kind: SitePermissionKind): SiteCapabilityDefinition {
    if (kind === 'camera') {
      return {
        id: 'camera',
        group: 'device_permission',
        title: resolveAppResourceText($r('app.string.settings_site_capability_camera')),
        objectLabel: resolveAppResourceText($r('app.string.settings_site_capability_camera')),
        summaryLabel: resolveAppResourceText($r('app.string.settings_site_capability_camera')),
        canSetDefault: true,
        canSetSiteRule: true,
        requiresSystemPermission: true
      };
    }
    if (kind === 'microphone') {
      return {
        id: 'microphone',
        group: 'device_permission',
        title: resolveAppResourceText($r('app.string.settings_site_capability_microphone')),
        objectLabel: resolveAppResourceText($r('app.string.settings_site_capability_microphone')),
        summaryLabel: resolveAppResourceText($r('app.string.settings_site_capability_microphone')),
        canSetDefault: true,
        canSetSiteRule: true,
        requiresSystemPermission: true
      };
    }
    if (kind === 'location') {
      return {
        id: 'location',
        group: 'device_permission',
        title: resolveAppResourceText($r('app.string.settings_site_capability_location')),
        objectLabel: resolveAppResourceText($r('app.string.settings_site_capability_location_object')),
        summaryLabel: resolveAppResourceText($r('app.string.settings_site_capability_location_summary')),
        canSetDefault: true,
        canSetSiteRule: true,
        requiresSystemPermission: true
      };
    }
    if (kind === 'clipboard') {
      return {
        id: 'clipboard',
        group: 'device_permission',
        title: resolveAppResourceText($r('app.string.settings_site_capability_clipboard')),
        objectLabel: resolveAppResourceText($r('app.string.settings_site_capability_clipboard')),
        summaryLabel: resolveAppResourceText($r('app.string.settings_site_capability_clipboard')),
        canSetDefault: true,
        canSetSiteRule: true,
        requiresSystemPermission: true
      };
    }
    return {
      id: 'sensor',
      group: 'device_permission',
      title: resolveAppResourceText($r('app.string.settings_site_capability_sensor')),
      objectLabel: resolveAppResourceText($r('app.string.settings_site_capability_sensor')),
      summaryLabel: resolveAppResourceText($r('app.string.settings_site_capability_sensor')),
      canSetDefault: true,
      canSetSiteRule: true,
      requiresSystemPermission: true
    };
  }

  getOpenAppDefinition(): SiteCapabilityDefinition {
    return {
      id: 'open_app',
      group: 'navigation_policy',
      title: resolveAppResourceText($r('app.string.settings_site_capability_open_app')),
      objectLabel: resolveAppResourceText($r('app.string.settings_site_capability_open_app_object')),
      summaryLabel: resolveAppResourceText($r('app.string.settings_site_capability_open_app')),
      canSetDefault: true,
      canSetSiteRule: true,
      requiresSystemPermission: false
    };
  }

  resolvePermissionKind(value: string): SitePermissionKind {
    if (value === 'microphone' || value === 'location' || value === 'sensor' || value === 'clipboard') {
      return value;
    }
    return 'camera';
  }

  getPermissionTitle(kind: SitePermissionKind): string {
    return this.getDevicePermissionDefinition(kind).title;
  }

  getPermissionObjectLabel(kind: SitePermissionKind): string {
    return this.getDevicePermissionDefinition(kind).objectLabel;
  }

  getPermissionSummaryLabel(kind: SitePermissionKind): string {
    return this.getDevicePermissionDefinition(kind).summaryLabel;
  }

  getPermissionKindsLabel(kinds: SitePermissionKind[]): string {
    return kinds
      .map((kind: SitePermissionKind) => this.getPermissionTitle(kind))
      .join(resolveAppResourceText($r('app.string.settings_site_capability_kinds_join')));
  }

  getPermissionRuleLabel(rule: SitePermissionRule): string {
    if (rule === 'allow') {
      return resolveAppResourceText($r('app.string.settings_site_capability_rule_allow'));
    }
    if (rule === 'block') {
      return resolveAppResourceText($r('app.string.settings_site_capability_rule_block'));
    }
    return resolveAppResourceText($r('app.string.settings_site_capability_rule_ask'));
  }

  getPermissionRuleDescription(kind: SitePermissionKind, rule: SitePermissionRule): string {
    if (rule === 'allow') {
      return resolveAppResourceText($r('app.string.settings_site_capability_rule_desc_allow'));
    }
    if (rule === 'block') {
      return resolveAppResourceText($r('app.string.settings_site_capability_rule_desc_block'));
    }
    return resolveAppResourceText($r('app.string.settings_site_capability_rule_desc_ask'));
  }

  buildSitePermissionOptions(kind: SitePermissionKind): SitePermissionRuleOption[] {
    const objectLabel = this.getPermissionObjectLabel(kind);
    return [
      {
        value: 'ask',
        label: resolveAppResourceText($r('app.string.settings_site_capability_rule_ask')),
        helperText: resolveAppResourceText(
          $r('app.string.settings_site_capability_option_ask_helper'), objectLabel)
      },
      {
        value: 'allow',
        label: resolveAppResourceText($r('app.string.settings_site_capability_rule_allow')),
        helperText: resolveAppResourceText(
          $r('app.string.settings_site_capability_option_allow_helper'), objectLabel)
      },
      {
        value: 'block',
        label: resolveAppResourceText($r('app.string.settings_site_capability_rule_block')),
        helperText: resolveAppResourceText(
          $r('app.string.settings_site_capability_option_block_helper'), objectLabel)
      }
    ];
  }

  buildDefaultPermissionOptions(): SitePermissionRuleOption[] {
    return [
      {
        value: 'ask',
        label: resolveAppResourceText($r('app.string.settings_site_capability_rule_ask')),
        helperText: resolveAppResourceText($r('app.string.settings_site_capability_default_ask_helper'))
      },
      {
        value: 'allow',
        label: resolveAppResourceText($r('app.string.settings_site_capability_rule_allow')),
        helperText: resolveAppResourceText($r('app.string.settings_site_capability_default_allow_helper'))
      },
      {
        value: 'block',
        label: resolveAppResourceText($r('app.string.settings_site_capability_rule_block')),
        helperText: resolveAppResourceText($r('app.string.settings_site_capability_default_block_helper'))
      }
    ];
  }

  buildExternalNavigationOptions(): ExternalNavigationPolicyOption[] {
    return [
      {
        value: 'ask',
        label: resolveAppResourceText($r('app.string.settings_site_capability_external_follow_default')),
        helperText: resolveAppResourceText($r('app.string.settings_site_capability_external_follow_default_helper'))
      },
      {
        value: 'allow',
        label: resolveAppResourceText($r('app.string.settings_site_capability_rule_allow')),
        helperText: resolveAppResourceText($r('app.string.settings_site_capability_external_allow_helper'))
      },
      {
        value: 'block',
        label: resolveAppResourceText($r('app.string.settings_site_capability_rule_block')),
        helperText: resolveAppResourceText($r('app.string.settings_site_capability_external_block_helper'))
      }
    ];
  }

  getExternalNavigationPolicyLabel(policy: ExternalNavigationAppOpenPolicy): string {
    if (policy === 'allow') {
      return resolveAppResourceText($r('app.string.settings_site_capability_rule_allow'));
    }
    if (policy === 'block') {
      return resolveAppResourceText($r('app.string.settings_site_capability_rule_block'));
    }
    return resolveAppResourceText($r('app.string.settings_site_capability_rule_ask'));
  }

  resolveSitePermissionKinds(resources: string[]): SitePermissionKind[] {
    return this.resolveProtectedResources(resources).kinds;
  }

  resolveProtectedResources(resources: string[]): SiteProtectedResourceResolution {
    const supportedResources: string[] = [];
    const kinds: SitePermissionKind[] = [];
    const unsupportedResources: string[] = [];
    resources.forEach((resource: string) => {
      if (resource === 'TYPE_VIDEO_CAPTURE') {
        if (!kinds.includes('camera')) {
          kinds.push('camera');
        }
        supportedResources.push(resource);
        return;
      }
      if (resource === 'TYPE_AUDIO_CAPTURE') {
        if (!kinds.includes('microphone')) {
          kinds.push('microphone');
        }
        supportedResources.push(resource);
        return;
      }
      if (resource === 'TYPE_SENSOR') {
        if (!kinds.includes('sensor')) {
          kinds.push('sensor');
        }
        supportedResources.push(resource);
        return;
      }
      unsupportedResources.push(resource);
    });
    return {
      resources: supportedResources,
      kinds: kinds,
      unsupportedResources: unsupportedResources
    };
  }

  resolveSystemPermissions(kinds: SitePermissionKind[]): Permissions[] {
    const permissions: Permissions[] = [];
    if (kinds.includes('camera')) {
      permissions.push('ohos.permission.CAMERA');
    }
    if (kinds.includes('microphone')) {
      permissions.push('ohos.permission.MICROPHONE');
    }
    if (kinds.includes('location')) {
      permissions.push('ohos.permission.APPROXIMATELY_LOCATION');
      permissions.push('ohos.permission.LOCATION');
    }
    if (kinds.includes('sensor')) {
      permissions.push('ohos.permission.ACCELEROMETER');
    }
    if (kinds.includes('clipboard')) {
      permissions.push('ohos.permission.READ_PASTEBOARD');
    }
    return permissions;
  }
}
