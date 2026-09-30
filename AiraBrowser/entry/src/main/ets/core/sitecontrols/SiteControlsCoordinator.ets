import {
  BrowserProfileId,
  DEFAULT_BROWSER_PROFILE_ID,
  ExternalNavigationAppOpenPolicy,
  ExternalNavigationSiteRule,
  SitePermissionDefaultSettings,
  SitePermissionKind,
  SitePermissionRule,
  SitePermissionSettings
} from '../../common/models/BrowserModels';
import { PreferencesRepository } from '../../data/preferences/PreferencesRepository';
import { SiteCapabilityCatalogService, SiteCapabilityId } from '../../services/web/SiteCapabilityCatalogService';
import { resolveAppResourceText } from '../resources/AppResourceText';
import { SiteIdentityService } from '../../services/web/SiteIdentityService';

export type SiteControlRuleSource = 'default' | 'site';
export type SiteControlsFilterId = 'all' | SiteCapabilityId;

export interface SiteControlCapabilityState {
  id: SiteCapabilityId;
  group: string;
  title: string;
  valueLabel: string;
  rule: string;
  source: SiteControlRuleSource;
  hasSiteRule: boolean;
  updatedAt: number;
}

export interface SiteControlsState {
  host: string;
  origin: string;
  profileId: BrowserProfileId;
  capabilities: SiteControlCapabilityState[];
  devicePermissions: SiteControlCapabilityState[];
  hasAnySiteRules: boolean;
  summary: string;
  updatedAt: number;
}

export interface SiteControlsDefaultCapabilityState {
  id: SitePermissionKind;
  title: string;
  rule: SitePermissionRule;
  valueLabel: string;
}

export interface SiteControlsOverviewState {
  profileId: BrowserProfileId;
  savedOriginCount: number;
  allowRuleCount: number;
  blockRuleCount: number;
  askRuleCount: number;
  defaults: SitePermissionDefaultSettings;
  defaultCapabilities: SiteControlsDefaultCapabilityState[];
  canClearPermissions: boolean;
  summaryLine: string;
}

export interface SiteControlsListRowState {
  id: string;
  host: string;
  origin: string;
  title: string;
  value: string;
  helperText: string;
  updatedAt: number;
}

export interface SiteControlsFilterOptionState {
  id: SiteControlsFilterId;
  title: string;
  count: number;
  isSelected: boolean;
}

export interface SiteControlsListState {
  query: string;
  totalCount: number;
  filteredCount: number;
  filterOptions: SiteControlsFilterOptionState[];
  rows: SiteControlsListRowState[];
  hasRows: boolean;
  hasFilteredRows: boolean;
  summaryLine: string;
  listTitle: string;
  emptyTitle: string;
  emptyMessage: string;
}

export interface SiteControlsCapabilityDefaultState {
  title: string;
  valueLabel: string;
  isEnabled: boolean;
}

interface SiteControlsAggregate {
  host: string;
  origin: string;
  permissionSettings: SitePermissionSettings[];
  externalNavigationRule?: ExternalNavigationSiteRule;
  updatedAt: number;
}

export class SiteControlsCoordinator {
  private preferencesRepository: PreferencesRepository;
  private capabilityCatalog: SiteCapabilityCatalogService = new SiteCapabilityCatalogService();
  private siteIdentityService: SiteIdentityService = new SiteIdentityService();

  constructor(preferencesRepository: PreferencesRepository) {
    this.preferencesRepository = preferencesRepository;
  }

  buildState(
    host: string,
    origin: string = '',
    profileId: BrowserProfileId = DEFAULT_BROWSER_PROFILE_ID
  ): SiteControlsState {
    const normalizedHost = this.normalizeHostKey(host);
    const normalizedOrigin = this.normalizeOriginKey(origin);
    const permissionSettings = this.findPermissionSettings(normalizedHost, normalizedOrigin, profileId);
    const latestPermissionSettings = permissionSettings.length > 0
      ? this.pickLatestPermissionSettings(permissionSettings)
      : undefined;
    const externalNavigationRule = this.findExternalNavigationRule(normalizedHost, normalizedOrigin, profileId);
    const devicePermissions = this.buildDevicePermissionStates(
      latestPermissionSettings,
      permissionSettings.length > 0
    );
    const navigationPolicies = [
      this.buildOpenAppState(externalNavigationRule)
    ];
    const capabilities = devicePermissions.concat(navigationPolicies);
    const updatedAt = capabilities.reduce((latest: number, item: SiteControlCapabilityState) => {
      return Math.max(latest, item.updatedAt);
    }, 0);
    const resolvedOrigin = latestPermissionSettings?.primaryOrigin ??
      externalNavigationRule?.primaryOrigin ?? normalizedOrigin;
    return {
      host: normalizedHost,
      origin: resolvedOrigin,
      profileId: profileId,
      capabilities: capabilities,
      devicePermissions: devicePermissions,
      hasAnySiteRules: capabilities.some((item: SiteControlCapabilityState) => item.hasSiteRule),
      summary: this.buildSummary(capabilities),
      updatedAt: updatedAt
    };
  }

  buildOverview(
    profileId: BrowserProfileId = DEFAULT_BROWSER_PROFILE_ID
  ): SiteControlsOverviewState {
    const normalizedProfileId = this.normalizeProfileId(profileId);
    const settings = this.preferencesRepository.listSitePermissionSettings(normalizedProfileId);
    const defaults = this.preferencesRepository.getPreferences().sitePermissionDefaults;
    const allowRuleCount = this.countPermissionRules(settings, 'allow');
    const blockRuleCount = this.countPermissionRules(settings, 'block');
    const askRuleCount = this.countPermissionRules(settings, 'ask');
    return {
      profileId: normalizedProfileId,
      savedOriginCount: settings.length,
      allowRuleCount: allowRuleCount,
      blockRuleCount: blockRuleCount,
      askRuleCount: askRuleCount,
      defaults: defaults,
      defaultCapabilities: this.buildDefaultCapabilityStates(defaults),
      canClearPermissions: settings.length > 0,
      summaryLine: this.buildOverviewSummary(settings.length, allowRuleCount, blockRuleCount)
    };
  }

  buildSessionOverview(
    profileId: BrowserProfileId = DEFAULT_BROWSER_PROFILE_ID,
    originCount: number = 0,
    totalRuleCount: number = 0,
    allowRuleCount: number = 0,
    blockRuleCount: number = 0
  ): SiteControlsOverviewState {
    const normalizedProfileId = this.normalizeProfileId(profileId);
    const defaults = this.preferencesRepository.getPreferences().sitePermissionDefaults;
    return {
      profileId: normalizedProfileId,
      savedOriginCount: Math.max(0, originCount),
      allowRuleCount: Math.max(0, allowRuleCount),
      blockRuleCount: Math.max(0, blockRuleCount),
      askRuleCount: 0,
      defaults: defaults,
      defaultCapabilities: this.buildDefaultCapabilityStates(defaults),
      canClearPermissions: totalRuleCount > 0,
      summaryLine: this.buildSessionOverviewSummary(originCount, totalRuleCount)
    };
  }

  buildListState(
    profileId: BrowserProfileId = DEFAULT_BROWSER_PROFILE_ID,
    query: string = '',
    selectedFilter: SiteControlsFilterId = 'all'
  ): SiteControlsListState {
    const normalizedProfileId = this.normalizeProfileId(profileId);
    const normalizedFilter = this.normalizeFilterId(selectedFilter);
    const aggregates = this.collectAggregates(normalizedProfileId);
    const selectedFilterAggregates = aggregates.filter((aggregate: SiteControlsAggregate) => {
      return this.matchesAggregateFilter(aggregate, normalizedFilter);
    });
    const rows = selectedFilterAggregates
      .map((aggregate: SiteControlsAggregate): SiteControlsListRowState => {
        return this.buildListRow(aggregate, normalizedProfileId, normalizedFilter);
      })
      .filter((row: SiteControlsListRowState) => this.matchesQuery(row, query))
      .sort((left: SiteControlsListRowState, right: SiteControlsListRowState) => right.updatedAt - left.updatedAt);
    const totalCount = aggregates.length;
    const selectedFilterCount = selectedFilterAggregates.length;
    return {
      query: query,
      totalCount: totalCount,
      filteredCount: rows.length,
      filterOptions: this.buildFilterOptions(aggregates, normalizedFilter),
      rows: rows,
      hasRows: totalCount > 0,
      hasFilteredRows: rows.length > 0,
      summaryLine: this.buildListSummaryLine(normalizedFilter, query, selectedFilterCount, rows.length, totalCount),
      listTitle: this.buildListTitle(normalizedFilter),
      emptyTitle: this.buildListEmptyTitle(normalizedFilter, query),
      emptyMessage: this.buildListEmptyMessage(normalizedFilter, query)
    };
  }

  buildCapabilityDefaultState(
    selectedFilter: SiteControlsFilterId,
    isEnabled: boolean = true
  ): SiteControlsCapabilityDefaultState {
    const normalizedFilter = this.normalizeFilterId(selectedFilter);
    if (normalizedFilter === 'open_app') {
      return {
        title: resolveAppResourceText($r('app.string.settings_site_controls_default_title')),
        valueLabel: this.capabilityCatalog.getExternalNavigationPolicyLabel(
          this.preferencesRepository.getPreferences().externalNavigation.appOpenPolicy
        ),
        isEnabled: isEnabled
      };
    }
    const kind = this.capabilityCatalog.resolvePermissionKind(normalizedFilter);
    return {
      title: resolveAppResourceText($r('app.string.settings_site_controls_default_title')),
      valueLabel: this.capabilityCatalog.getPermissionRuleLabel(this.getDefaultRule(kind)),
      isEnabled: isEnabled
    };
  }

  private buildDevicePermissionStates(
    settings: SitePermissionSettings | undefined,
    hasSiteRule: boolean
  ): SiteControlCapabilityState[] {
    return this.capabilityCatalog.listDevicePermissionKinds().map((kind: SitePermissionKind) => {
      const rule = settings === undefined ? this.getDefaultRule(kind) : this.getPermissionRule(settings, kind);
      const source: SiteControlRuleSource = hasSiteRule ? 'site' : 'default';
      const state: SiteControlCapabilityState = {
        id: kind,
        group: 'device_permission',
        title: this.capabilityCatalog.getPermissionTitle(kind),
        valueLabel: this.capabilityCatalog.getPermissionRuleLabel(rule),
        rule: rule,
        source: source,
        hasSiteRule: hasSiteRule && rule !== this.getDefaultRule(kind),
        updatedAt: settings?.updatedAt ?? 0
      };
      return state;
    });
  }

  private buildOpenAppState(rule: ExternalNavigationSiteRule | undefined): SiteControlCapabilityState {
    const effectivePolicy: ExternalNavigationAppOpenPolicy =
      rule?.policy ?? this.preferencesRepository.getPreferences().externalNavigation.appOpenPolicy;
    return {
      id: 'open_app',
      group: 'navigation_policy',
      title: this.capabilityCatalog.getOpenAppDefinition().title,
      valueLabel: this.capabilityCatalog.getExternalNavigationPolicyLabel(effectivePolicy),
      rule: effectivePolicy,
      source: rule === undefined ? 'default' : 'site',
      hasSiteRule: rule !== undefined,
      updatedAt: rule?.updatedAt ?? 0
    };
  }

  private buildDefaultCapabilityStates(
    defaults: SitePermissionDefaultSettings
  ): SiteControlsDefaultCapabilityState[] {
    return this.capabilityCatalog.listDevicePermissionKinds().map((kind: SitePermissionKind) => {
      const rule = this.getDefaultRuleFromSettings(defaults, kind);
      const state: SiteControlsDefaultCapabilityState = {
        id: kind,
        title: this.capabilityCatalog.getPermissionTitle(kind),
        rule: rule,
        valueLabel: this.capabilityCatalog.getPermissionRuleLabel(rule)
      };
      return state;
    });
  }

  private buildSummary(capabilities: SiteControlCapabilityState[]): string {
    const siteRules = capabilities.filter((item: SiteControlCapabilityState) => item.hasSiteRule);
    if (siteRules.length === 0) {
      return '';
    }
    return siteRules.map((item: SiteControlCapabilityState) => {
      return `${item.title}${item.valueLabel}`;
    }).join(' · ');
  }

  private buildOverviewSummary(
    savedOriginCount: number,
    allowRuleCount: number,
    blockRuleCount: number
  ): string {
    if (savedOriginCount <= 0) {
      return resolveAppResourceText($r('app.string.settings_site_controls_summary_empty'));
    }
    return resolveAppResourceText(
      $r('app.string.settings_site_controls_summary_saved'),
      savedOriginCount,
      allowRuleCount,
      blockRuleCount
    );
  }

  private buildSessionOverviewSummary(originCount: number, totalRuleCount: number): string {
    if (totalRuleCount <= 0) {
      return resolveAppResourceText($r('app.string.settings_site_controls_summary_private_empty'));
    }
    return resolveAppResourceText(
      $r('app.string.settings_site_controls_summary_private'),
      Math.max(0, originCount),
      Math.max(0, totalRuleCount)
    );
  }

  private findPermissionSettings(
    _host: string,
    origin: string,
    profileId: BrowserProfileId
  ): SitePermissionSettings[] {
    const list = this.preferencesRepository.listSitePermissionSettings(profileId);
    return origin.length > 0
      ? list.filter((item: SitePermissionSettings) => this.normalizeOriginKey(item.primaryOrigin) === origin)
      : [];
  }

  private findExternalNavigationRule(
    _host: string,
    origin: string,
    profileId: BrowserProfileId
  ): ExternalNavigationSiteRule | undefined {
    const rules = this.preferencesRepository.getPreferences().externalNavigation.siteRules.filter(
      (rule: ExternalNavigationSiteRule) => rule.profileId === profileId
    );
    return origin.length > 0
      ? rules.find((rule: ExternalNavigationSiteRule) => this.normalizeOriginKey(rule.primaryOrigin) === origin)
      : undefined;
  }

  private collectAggregates(profileId: BrowserProfileId): SiteControlsAggregate[] {
    const map: Map<string, SiteControlsAggregate> = new Map<string, SiteControlsAggregate>();
    this.preferencesRepository.listSitePermissionSettings(profileId)
      .forEach((item: SitePermissionSettings) => {
        const origin = this.normalizeOriginKey(item.primaryOrigin);
        const host = this.normalizeHostKey(item.displayHost);
        if (origin.length === 0 || host.length === 0) {
          return;
        }
        const current = map.get(origin);
        const next: SiteControlsAggregate = current ?? {
          host: host,
          origin: origin,
          permissionSettings: [],
          updatedAt: 0
        };
        next.permissionSettings.push(item);
        if (item.updatedAt >= next.updatedAt) {
          next.origin = origin;
        }
        next.updatedAt = Math.max(next.updatedAt, item.updatedAt);
        map.set(origin, next);
      });
    this.preferencesRepository.getPreferences().externalNavigation.siteRules
      .filter((item: ExternalNavigationSiteRule) => item.profileId === profileId)
      .forEach((item: ExternalNavigationSiteRule) => {
        const origin = this.normalizeOriginKey(item.primaryOrigin);
        const host = this.normalizeHostKey(item.displayHost);
        if (origin.length === 0 || host.length === 0) {
          return;
        }
        const current = map.get(origin);
        const next: SiteControlsAggregate = current ?? {
          host: host,
          origin: origin,
          permissionSettings: [],
          updatedAt: 0
        };
        next.externalNavigationRule = item;
        if (item.updatedAt >= next.updatedAt || next.origin.length === 0) {
          next.origin = origin;
        }
        next.updatedAt = Math.max(next.updatedAt, item.updatedAt);
        map.set(origin, next);
      });
    return Array.from(map.values()).filter((aggregate: SiteControlsAggregate) => {
      return this.hasAggregateRules(aggregate);
    });
  }

  private buildListRow(
    aggregate: SiteControlsAggregate,
    profileId: BrowserProfileId,
    selectedFilter: SiteControlsFilterId
  ): SiteControlsListRowState {
    const siteControls = this.buildState(aggregate.host, aggregate.origin, profileId);
    const isCapabilityRow = selectedFilter !== 'all';
    const value = isCapabilityRow
      ? this.buildCapabilityRowValue(aggregate, selectedFilter)
      : siteControls.summary.length > 0 ? siteControls.summary : this.buildAggregateValue(aggregate);
    const origin = isCapabilityRow ? this.resolveAggregateOriginForFilter(aggregate, selectedFilter) : aggregate.origin;
    const updatedAt = isCapabilityRow ? this.resolveAggregateUpdatedAtForFilter(aggregate, selectedFilter) : aggregate.updatedAt;
    return {
      id: `${selectedFilter}:${aggregate.origin.length > 0 ? aggregate.origin : aggregate.host}`,
      host: aggregate.host,
      origin: origin,
      title: aggregate.origin.length > 0
        ? aggregate.origin
        : aggregate.host.length > 0 ? aggregate.host : resolveAppResourceText($r('app.string.settings_site_controls_unknown_site')),
      value: value,
      helperText: isCapabilityRow ? '' : this.buildAggregateHelperText(aggregate),
      updatedAt: updatedAt
    };
  }

  private buildCapabilityRowValue(
    aggregate: SiteControlsAggregate,
    selectedFilter: SiteControlsFilterId
  ): string {
    if (selectedFilter === 'open_app') {
      if (aggregate.externalNavigationRule === undefined) {
        return resolveAppResourceText($r('app.string.settings_site_capability_rule_ask'));
      }
      return this.capabilityCatalog.getExternalNavigationPolicyLabel(aggregate.externalNavigationRule.policy);
    }
    const settings = this.pickLatestSettingsForPermissionFilter(aggregate, selectedFilter);
    if (settings === undefined) {
      return this.capabilityCatalog.getPermissionRuleLabel(this.getDefaultRule(this.capabilityCatalog.resolvePermissionKind(selectedFilter)));
    }
    const kind = this.capabilityCatalog.resolvePermissionKind(selectedFilter);
    return this.capabilityCatalog.getPermissionRuleLabel(this.getPermissionRule(settings, kind));
  }

  private resolveAggregateOriginForFilter(
    aggregate: SiteControlsAggregate,
    selectedFilter: SiteControlsFilterId
  ): string {
    if (selectedFilter === 'open_app') {
      return aggregate.externalNavigationRule?.primaryOrigin ?? aggregate.origin;
    }
    const settings = this.pickLatestSettingsForPermissionFilter(aggregate, selectedFilter);
    return settings?.primaryOrigin ?? aggregate.origin;
  }

  private resolveAggregateUpdatedAtForFilter(
    aggregate: SiteControlsAggregate,
    selectedFilter: SiteControlsFilterId
  ): number {
    if (selectedFilter === 'open_app') {
      return aggregate.externalNavigationRule?.updatedAt ?? aggregate.updatedAt;
    }
    const settings = this.pickLatestSettingsForPermissionFilter(aggregate, selectedFilter);
    return settings?.updatedAt ?? aggregate.updatedAt;
  }

  private pickLatestSettingsForPermissionFilter(
    aggregate: SiteControlsAggregate,
    selectedFilter: SiteControlsFilterId
  ): SitePermissionSettings | undefined {
    if (selectedFilter === 'all' || selectedFilter === 'open_app') {
      return undefined;
    }
    const kind = this.capabilityCatalog.resolvePermissionKind(selectedFilter);
    const matches = aggregate.permissionSettings.filter((settings: SitePermissionSettings) => {
      return this.getPermissionRule(settings, kind) !== this.getDefaultRule(kind);
    });
    if (matches.length === 0) {
      return undefined;
    }
    return this.pickLatestPermissionSettings(matches);
  }

  private buildAggregateValue(aggregate: SiteControlsAggregate): string {
    const parts: string[] = [];
    if (aggregate.permissionSettings.length > 0) {
      parts.push(resolveAppResourceText(
        $r('app.string.settings_site_controls_fragment_permission_sites'),
        aggregate.permissionSettings.length
      ));
    }
    if (aggregate.externalNavigationRule !== undefined) {
      parts.push(resolveAppResourceText(
        $r('app.string.settings_site_controls_fragment_external_actions'),
        this.capabilityCatalog.getExternalNavigationPolicyLabel(aggregate.externalNavigationRule.policy)
      ));
    }
    return parts.length > 0 ? parts.join(' · ') : resolveAppResourceText($r('app.string.settings_site_controls_fragment_saved_rules'));
  }

  private buildAggregateHelperText(aggregate: SiteControlsAggregate): string {
    const parts: string[] = [];
    if (aggregate.permissionSettings.length > 0) {
      parts.push(resolveAppResourceText($r('app.string.settings_site_controls_group_device_permission')));
    }
    if (aggregate.externalNavigationRule !== undefined) {
      parts.push(resolveAppResourceText($r('app.string.settings_site_controls_group_open_app')));
    }
    return parts.length > 0 ? parts.join(' · ') : resolveAppResourceText($r('app.string.settings_site_controls_fragment_tap_to_manage'));
  }

  private hasAggregateRules(aggregate: SiteControlsAggregate): boolean {
    if (aggregate.externalNavigationRule !== undefined) {
      return true;
    }
    return aggregate.permissionSettings.some((settings: SitePermissionSettings) => {
      return this.capabilityCatalog.listDevicePermissionKinds().some((kind: SitePermissionKind) => {
        return this.getPermissionRule(settings, kind) !== this.getDefaultRule(kind);
      });
    });
  }

  private buildFilterOptions(
    aggregates: SiteControlsAggregate[],
    selectedFilter: SiteControlsFilterId
  ): SiteControlsFilterOptionState[] {
    const options: SiteControlsFilterOptionState[] = [
      {
        id: 'all',
        title: resolveAppResourceText($r('app.string.settings_site_controls_filter_all')),
        count: aggregates.length,
        isSelected: selectedFilter === 'all'
      }
    ];
    this.capabilityCatalog.listDevicePermissionKinds().forEach((kind: SitePermissionKind) => {
      const option: SiteControlsFilterOptionState = {
        id: kind,
        title: this.capabilityCatalog.getPermissionTitle(kind),
        count: this.countAggregatesForFilter(aggregates, kind),
        isSelected: selectedFilter === kind
      };
      options.push(option);
    });
    const openAppOption: SiteControlsFilterOptionState = {
      id: 'open_app',
      title: this.capabilityCatalog.getOpenAppDefinition().title,
      count: this.countAggregatesForFilter(aggregates, 'open_app'),
      isSelected: selectedFilter === 'open_app'
    };
    options.push(openAppOption);
    return options;
  }

  private countAggregatesForFilter(
    aggregates: SiteControlsAggregate[],
    filterId: SiteControlsFilterId
  ): number {
    return aggregates.filter((aggregate: SiteControlsAggregate) => {
      return this.matchesAggregateFilter(aggregate, filterId);
    }).length;
  }

  private matchesAggregateFilter(
    aggregate: SiteControlsAggregate,
    filterId: SiteControlsFilterId
  ): boolean {
    if (filterId === 'all') {
      return true;
    }
    if (filterId === 'open_app') {
      return aggregate.externalNavigationRule !== undefined;
    }
    const kind = this.capabilityCatalog.resolvePermissionKind(filterId);
    return aggregate.permissionSettings.some((settings: SitePermissionSettings) => {
      return this.getPermissionRule(settings, kind) !== this.getDefaultRule(kind);
    });
  }

  private buildListSummaryLine(
    selectedFilter: SiteControlsFilterId,
    query: string,
    selectedFilterCount: number,
    visibleCount: number,
    totalCount: number
  ): string {
    const title = this.getFilterTitle(selectedFilter);
    if (query.trim().length > 0) {
      return resolveAppResourceText(
        $r('app.string.settings_site_controls_title_matched'),
        title,
        visibleCount,
        selectedFilterCount
      );
    }
    if (selectedFilter === 'all') {
      return resolveAppResourceText(
        $r('app.string.settings_site_controls_title_all_saved'), totalCount);
    }
    return resolveAppResourceText(
      $r('app.string.settings_site_controls_title_filtered'), title, selectedFilterCount);
  }

  private buildListTitle(selectedFilter: SiteControlsFilterId): string {
    if (selectedFilter === 'all') {
      return resolveAppResourceText($r('app.string.settings_site_controls_list_title'));
    }
    return this.getFilterTitle(selectedFilter);
  }

  private buildListEmptyTitle(selectedFilter: SiteControlsFilterId, query: string): string {
    if (query.trim().length > 0) {
      return resolveAppResourceText($r('app.string.settings_site_controls_empty_search_title'));
    }
    if (selectedFilter === 'all') {
      return resolveAppResourceText($r('app.string.settings_site_controls_empty_title'));
    }
    return resolveAppResourceText(
      $r('app.string.settings_site_controls_empty_filter_title'), this.getFilterTitle(selectedFilter));
  }

  private buildListEmptyMessage(selectedFilter: SiteControlsFilterId, query: string): string {
    if (query.trim().length > 0) {
      return resolveAppResourceText($r('app.string.settings_site_controls_empty_search_message'));
    }
    if (selectedFilter === 'all') {
      return resolveAppResourceText($r('app.string.settings_site_controls_empty_message'));
    }
    return resolveAppResourceText(
      $r('app.string.settings_site_controls_empty_filter_message'), this.getFilterTitle(selectedFilter));
  }

  private pickLatestPermissionSettings(permissionSettings: SitePermissionSettings[]): SitePermissionSettings {
    return permissionSettings.reduce((latest: SitePermissionSettings, item: SitePermissionSettings) => {
      if (item.updatedAt >= latest.updatedAt) {
        return item;
      }
      return latest;
    }, permissionSettings[0]);
  }

  private getPermissionRule(settings: SitePermissionSettings, kind: SitePermissionKind): SitePermissionRule {
    if (kind === 'camera') {
      return settings.camera;
    }
    if (kind === 'microphone') {
      return settings.microphone;
    }
    if (kind === 'location') {
      return settings.location;
    }
    if (kind === 'sensor') {
      return settings.sensor;
    }
    return settings.clipboard;
  }

  private getDefaultRule(kind: SitePermissionKind): SitePermissionRule {
    const defaults = this.preferencesRepository.getPreferences().sitePermissionDefaults;
    return this.getDefaultRuleFromSettings(defaults, kind);
  }

  private getDefaultRuleFromSettings(
    defaults: SitePermissionDefaultSettings,
    kind: SitePermissionKind
  ): SitePermissionRule {
    if (kind === 'camera') {
      return defaults.camera;
    }
    if (kind === 'microphone') {
      return defaults.microphone;
    }
    if (kind === 'location') {
      return defaults.location;
    }
    if (kind === 'sensor') {
      return defaults.sensor;
    }
    return defaults.clipboard;
  }

  private countPermissionRules(settings: SitePermissionSettings[], rule: SitePermissionRule): number {
    let count = 0;
    settings.forEach((item: SitePermissionSettings) => {
      this.capabilityCatalog.listDevicePermissionKinds().forEach((kind: SitePermissionKind) => {
        if (this.getPermissionRule(item, kind) === rule) {
          count += 1;
        }
      });
    });
    return count;
  }

  private normalizeProfileId(profileId: BrowserProfileId): BrowserProfileId {
    return profileId.length > 0 ? profileId : DEFAULT_BROWSER_PROFILE_ID;
  }

  private normalizeFilterId(filterId: SiteControlsFilterId): SiteControlsFilterId {
    if (
      filterId === 'camera' ||
        filterId === 'microphone' ||
        filterId === 'location' ||
        filterId === 'sensor' ||
        filterId === 'clipboard' ||
        filterId === 'open_app'
    ) {
      return filterId;
    }
    return 'all';
  }

  private getFilterTitle(filterId: SiteControlsFilterId): string {
    if (filterId === 'all') {
      return resolveAppResourceText($r('app.string.settings_site_controls_filter_all'));
    }
    if (filterId === 'open_app') {
      return this.capabilityCatalog.getOpenAppDefinition().title;
    }
    return this.capabilityCatalog.getPermissionTitle(this.capabilityCatalog.resolvePermissionKind(filterId));
  }

  private matchesQuery(row: SiteControlsListRowState, query: string): boolean {
    const normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.length === 0) {
      return true;
    }
    return `${row.title} ${row.value} ${row.helperText}`.toLowerCase().indexOf(normalizedQuery) >= 0;
  }

  private normalizeOriginKey(value: string): string {
    return this.siteIdentityService.resolveSiteSettingTarget(value)?.canonicalOrigin ?? value.trim().toLowerCase();
  }

  private normalizeHostKey(value: string): string {
    return this.siteIdentityService.extractHost(value);
  }
}
