import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { productViewManager } from '@kit.AppGalleryKit';
import { SiteIconService } from '../siteicons/SiteIconService';
import { WebAppInstallIconRuleService } from '../webapps/WebAppInstallIconRuleService';
import { DesktopShortcutIconPreparationService } from './DesktopShortcutIconPreparationService';
import {
  DESKTOP_WEB_SHORTCUT_ID_PREFIX,
  DESKTOP_WEB_SHORTCUT_SOURCE,
  DESKTOP_WEB_SHORTCUT_WANT_KEYS,
  DesktopWebEntryRecord
} from '../../data/webapps/WebAppInstallModels';
import {
  WebAppInstallRepository,
  sharedWebAppInstallRepository
} from '../../data/webapps/WebAppInstallRepository';

export interface DesktopShortcutTarget {
  url: string;
  title: string;
  bundleName: string;
  moduleName: string;
  abilityName: string;
  favicon?: image.PixelMap;
  preparedIconPath?: string;
  customIconPath?: string;
  origin?: string;
  scope?: string;
  manifestUrl?: string;
  themeColor?: string;
  backgroundColor?: string;
  display?: string;
  currentUrl?: string;
}

export interface DesktopShortcutIconPreparationTarget {
  url: string;
  favicon?: image.PixelMap;
}

export interface DesktopShortcutResult {
  ok: boolean;
  message: ResourceStr;
  code: number;
  shortcutId: string;
  record?: DesktopWebEntryRecord;
}

const WEB_PAGE_SHORTCUT_ICON_RESOURCE_NAME: string = 'startIcon';
const WEB_PAGE_SHORTCUT_ICON_FILE_NAME: string = 'aira_desktop_shortcut_icon.png';
const WEB_PAGE_SHORTCUT_SITE_ICON_FILE_PREFIX: string = 'aira_desktop_site_icon_';
const WEB_PAGE_SHORTCUT_BUILT_IN_ICON_FILE_PREFIX: string = 'aira_desktop_built_in_icon_';
const WEB_PAGE_SHORTCUT_PREVIEW_ICON_FILE_PREFIX: string = 'aira_desktop_preview_icon_';
const WEB_PAGE_SHORTCUT_PREPARED_ICON_FILE_PREFIX: string = 'aira_desktop_prepared_icon_';
const WEB_PAGE_SHORTCUT_SITE_ICON_BUFFER_SIZE: number = 512 * 1024;
const SHORTCUT_ALREADY_EXISTS_CODE: number = 1006620003;
const SHORTCUT_LIMIT_REACHED_CODE: number = 1006620004;
const SHORTCUT_REJECTED_CODE: number = 1006620007;

export class DesktopShortcutService {
  private siteIconService: SiteIconService = new SiteIconService();
  private iconRuleService: WebAppInstallIconRuleService = new WebAppInstallIconRuleService();
  private installRepository: WebAppInstallRepository;
  private iconPreparationService: DesktopShortcutIconPreparationService;

  constructor(
    installRepository: WebAppInstallRepository = sharedWebAppInstallRepository,
    iconPreparationService: DesktopShortcutIconPreparationService = new DesktopShortcutIconPreparationService()
  ) {
    this.installRepository = installRepository;
    this.iconPreparationService = iconPreparationService;
  }

  async prepareWebPageShortcutIcon(
    context: common.UIAbilityContext,
    target: DesktopShortcutIconPreparationTarget
  ): Promise<string> {
    const normalizedUrl = target.url.trim();
    if (normalizedUrl.length === 0) {
      return '';
    }
    const shortcutId = this.buildShortcutId(normalizedUrl);
    return await this.resolveShortcutIconFile(
      context,
      normalizedUrl,
      shortcutId,
      `${context.cacheDir}/${WEB_PAGE_SHORTCUT_PREVIEW_ICON_FILE_PREFIX}${shortcutId}.png`,
      target.favicon
    );
  }

  async addWebPageShortcut(context: common.UIAbilityContext, target: DesktopShortcutTarget): Promise<DesktopShortcutResult> {
    const normalizedUrl = target.url.trim();
    if (normalizedUrl.length <= 0) {
      return {
        ok: false,
        message: $r('app.string.settings_desktop_shortcut_no_url'),
        code: 0,
        shortcutId: ''
      };
    }
    const label = this.resolveShortcutLabel(target.title, normalizedUrl);
    const shortcutId = this.buildShortcutId(normalizedUrl);
    const createdAt = Date.now();
    const previousRecord = await this.installRepository.findByShortcutId(shortcutId);
    try {
      const foregroundIcon = await this.resolveShortcutIconFile(
        context,
        normalizedUrl,
        shortcutId,
        this.resolveInstalledIconPath(context, shortcutId),
        target.favicon,
        target.customIconPath,
        target.preparedIconPath
      );
      if (foregroundIcon.length === 0) {
        throw new Error('desktop shortcut icon preparation failed');
      }
      const want = this.buildShortcutWant(target, normalizedUrl, label, foregroundIcon, shortcutId, createdAt);
      const pendingRecord = await this.upsertInstallRecord(
        shortcutId,
        label,
        foregroundIcon,
        normalizedUrl,
        target,
        'pending'
      );
      const result = await productViewManager.checkPinShortcutPermitted(
        context,
        shortcutId,
        want,
        label,
        foregroundIcon,
        ''
      );
      const tid = (result.tid ?? '').trim();
      if (tid.length <= 0) {
        await this.rollbackPendingInstallRecord(shortcutId, previousRecord);
        return {
          ok: false,
          message: $r('app.string.settings_desktop_shortcut_unavailable'),
          code: result.code,
          shortcutId: shortcutId,
          record: pendingRecord
        };
      }
      await productViewManager.requestNewPinShortcut(context, tid);
      const record = await this.upsertInstallRecord(
        shortcutId,
        label,
        foregroundIcon,
        normalizedUrl,
        target,
        'installed'
      );
      return {
        ok: true,
        message: $r('app.string.settings_desktop_shortcut_added'),
        code: result.code,
        shortcutId: shortcutId,
        record: record
      };
    } catch (error) {
      const businessError = error as BusinessError;
      if (Number(businessError?.code ?? 0) === SHORTCUT_ALREADY_EXISTS_CODE) {
        const foregroundIcon = await this.resolveShortcutIconFile(
          context,
          normalizedUrl,
          shortcutId,
          this.resolveInstalledIconPath(context, shortcutId),
          target.favicon,
          target.customIconPath,
          target.preparedIconPath
        );
        const record = await this.upsertInstallRecord(
          shortcutId,
          label,
          foregroundIcon,
          normalizedUrl,
          target,
          'installed'
        );
        return {
          ok: true,
          message: $r('app.string.settings_desktop_shortcut_updated'),
          code: SHORTCUT_ALREADY_EXISTS_CODE,
          shortcutId: shortcutId,
          record: record
        };
      }
      await this.rollbackPendingInstallRecord(shortcutId, previousRecord);
      return this.buildFailureResult(businessError, shortcutId);
    }
  }

  async probeInstalledShortcut(
    context: common.UIAbilityContext,
    record: DesktopWebEntryRecord
  ): Promise<'present' | 'absent' | 'unknown'> {
    const shortcutId = record.shortcutId.trim();
    const launchUrl = record.launchUrl.trim().length > 0 ? record.launchUrl.trim() : record.currentUrl.trim();
    if (shortcutId.length === 0 || launchUrl.length === 0) {
      return 'unknown';
    }
    const iconPath = await this.resolveProbeIconPath(context, record.iconPath);
    if (iconPath.length === 0) {
      return 'unknown';
    }
    const label = this.resolveProbeLabel(record.title, launchUrl);
    const want = this.buildShortcutWant(
      {
        url: launchUrl,
        title: label,
        bundleName: context.abilityInfo.bundleName,
        moduleName: context.abilityInfo.moduleName,
        abilityName: context.abilityInfo.name,
        origin: record.origin,
        scope: record.scope,
        manifestUrl: record.manifestUrl,
        themeColor: record.themeColor,
        backgroundColor: record.backgroundColor,
        display: record.display,
        currentUrl: record.currentUrl
      },
      launchUrl,
      label,
      iconPath,
      shortcutId,
      record.createdAt
    );
    try {
      const result = await productViewManager.checkPinShortcutPermitted(
        context,
        shortcutId,
        want,
        label,
        iconPath,
        ''
      );
      return this.resolveProbeCode(Number(result.code ?? 0));
    } catch (error) {
      const businessError = error as BusinessError;
      return this.resolveProbeCode(Number(businessError?.code ?? 0));
    }
  }

  private async rollbackPendingInstallRecord(
    shortcutId: string,
    previousRecord: DesktopWebEntryRecord | undefined
  ): Promise<void> {
    if (previousRecord === undefined) {
      await this.installRepository.remove(shortcutId);
      return;
    }
    await this.installRepository.replace(previousRecord);
  }

  private async upsertInstallRecord(
    shortcutId: string,
    label: string,
    iconPath: string,
    launchUrl: string,
    target: DesktopShortcutTarget,
    installState: 'pending' | 'installed'
  ): Promise<DesktopWebEntryRecord> {
    return this.installRepository.upsert({
      shortcutId: shortcutId,
      installState: installState,
      title: label,
      iconPath: iconPath,
      launchUrl: launchUrl,
      currentUrl: target.currentUrl ?? launchUrl,
      origin: target.origin ?? this.extractOrigin(launchUrl),
      manifestUrl: target.manifestUrl,
      scope: target.scope,
      display: target.display,
      themeColor: target.themeColor,
      backgroundColor: target.backgroundColor
    });
  }

  private buildShortcutWant(
    target: DesktopShortcutTarget,
    url: string,
    label: string,
    iconPath: string,
    shortcutId: string,
    createdAt: number
  ): Want {
    const parameters: Record<string, Object> = {};
    parameters['url'] = url;
    parameters['targetUrl'] = url;
    parameters['title'] = label;
    parameters[DESKTOP_WEB_SHORTCUT_WANT_KEYS.source] = DESKTOP_WEB_SHORTCUT_SOURCE;
    parameters[DESKTOP_WEB_SHORTCUT_WANT_KEYS.shortcutId] = shortcutId;
    parameters[DESKTOP_WEB_SHORTCUT_WANT_KEYS.createdAt] = createdAt;
    parameters[DESKTOP_WEB_SHORTCUT_WANT_KEYS.title] = label;
    parameters[DESKTOP_WEB_SHORTCUT_WANT_KEYS.iconPath] = iconPath;
    if ((target.scope ?? '').length > 0) {
      parameters[DESKTOP_WEB_SHORTCUT_WANT_KEYS.scope] = String(target.scope);
    }
    if ((target.manifestUrl ?? '').length > 0) {
      parameters[DESKTOP_WEB_SHORTCUT_WANT_KEYS.manifestUrl] = String(target.manifestUrl);
    }
    if ((target.origin ?? '').length > 0) {
      parameters[DESKTOP_WEB_SHORTCUT_WANT_KEYS.origin] = String(target.origin);
    } else {
      parameters[DESKTOP_WEB_SHORTCUT_WANT_KEYS.origin] = this.extractOrigin(url);
    }
    if ((target.themeColor ?? '').length > 0) {
      parameters[DESKTOP_WEB_SHORTCUT_WANT_KEYS.themeColor] = String(target.themeColor);
    }
    return {
      bundleName: target.bundleName,
      moduleName: target.moduleName,
      abilityName: target.abilityName,
      uri: url,
      parameters: parameters
    };
  }

  private resolveShortcutLabel(title: string, url: string): string {
    const normalizedTitle = title.trim();
    if (normalizedTitle.length > 0) {
      return normalizedTitle;
    }
    return url;
  }

  private resolveProbeLabel(title: string, url: string): string {
    const label = this.resolveShortcutLabel(title, url);
    if (label.length <= 255) {
      return label;
    }
    return label.substring(0, 255);
  }

  private async resolveProbeIconPath(context: common.UIAbilityContext, iconPath: string): Promise<string> {
    const storedPath = iconPath.trim();
    if (storedPath.length > 0 && await this.fileExists(storedPath)) {
      return storedPath;
    }
    try {
      return await this.ensureShortcutIconFile(context);
    } catch (_error) {
      return '';
    }
  }

  private async fileExists(path: string): Promise<boolean> {
    try {
      return await fileIo.access(path);
    } catch (_error) {
      return false;
    }
  }

  private resolveProbeCode(code: number): 'present' | 'absent' | 'unknown' {
    if (code === SHORTCUT_ALREADY_EXISTS_CODE) {
      return 'present';
    }
    if (code === 0) {
      return 'absent';
    }
    return 'unknown';
  }

  private buildShortcutId(url: string): string {
    return `${DESKTOP_WEB_SHORTCUT_ID_PREFIX}${this.hashUrl(url)}`;
  }

  private hashUrl(url: string): string {
    let hash = 2166136261;
    for (let index = 0; index < url.length; index++) {
      hash = hash ^ url.charCodeAt(index);
      hash = Math.imul(hash, 16777619);
    }
    return (hash >>> 0).toString(36);
  }

  private extractOrigin(url: string): string {
    const trimmed = url.trim();
    if (trimmed.length === 0) {
      return '';
    }
    const match = /^([a-z]+:\/\/[^/?#]+)/i.exec(trimmed);
    if (match === null) {
      return '';
    }
    return match[1];
  }

  private async resolveShortcutIconFile(
    context: common.UIAbilityContext,
    url: string,
    shortcutId: string,
    targetPath: string,
    favicon?: image.PixelMap,
    customIconPath?: string,
    preparedIconPath?: string
  ): Promise<string> {
    let prepared = await this.tryPrepareIconSource(customIconPath ?? '', targetPath);
    if (prepared.length > 0) {
      return prepared;
    }

    prepared = await this.tryPrepareIconSource(preparedIconPath ?? '', targetPath);
    if (prepared.length > 0) {
      return prepared;
    }

    prepared = await this.tryPrepareIconSource(
      await this.resolveBuiltInIconFile(context, url, shortcutId),
      targetPath
    );
    if (prepared.length > 0) {
      return prepared;
    }

    prepared = await this.tryPrepareIconSource(await this.resolveCachedSiteIconFile(url), targetPath);
    if (prepared.length > 0) {
      return prepared;
    }

    if (favicon !== undefined) {
      prepared = await this.tryPrepareIconSource(
        await this.writePixelMapIconFile(context, shortcutId, favicon),
        targetPath
      );
      if (prepared.length > 0) {
        return prepared;
      }
    }

    return await this.tryPrepareIconSource(await this.ensureShortcutIconFile(context), targetPath);
  }

  private resolveInstalledIconPath(context: common.UIAbilityContext, shortcutId: string): string {
    return `${context.filesDir}/${WEB_PAGE_SHORTCUT_PREPARED_ICON_FILE_PREFIX}${shortcutId}.png`;
  }

  private async tryPrepareIconSource(source: string, targetPath: string): Promise<string> {
    const normalized = source.trim();
    if (normalized.length === 0) {
      return '';
    }
    try {
      return await this.iconPreparationService.prepare(normalized, targetPath);
    } catch (_error) {
      return '';
    }
  }

  private async resolveBuiltInIconFile(
    context: common.UIAbilityContext,
    url: string,
    shortcutId: string
  ): Promise<string> {
    const match = this.iconRuleService.resolveBuiltInIcon(url);
    if (match === undefined || match.mediaName.length === 0) {
      return '';
    }
    const path = `${context.filesDir}/${WEB_PAGE_SHORTCUT_BUILT_IN_ICON_FILE_PREFIX}${shortcutId}.png`;
    try {
      const iconBytes = await context.resourceManager.getMediaByName(match.mediaName);
      await this.writeBytes(path, iconBytes.buffer as ArrayBuffer);
      return path;
    } catch (_error) {
      return '';
    }
  }

  private async writePixelMapIconFile(
    context: common.UIAbilityContext,
    shortcutId: string,
    favicon: image.PixelMap
  ): Promise<string> {
    const path = `${context.filesDir}/${WEB_PAGE_SHORTCUT_SITE_ICON_FILE_PREFIX}${shortcutId}.png`;
    const packer = image.createImagePacker();
    try {
      const data = await packer.packToData(favicon, {
        format: 'image/png',
        quality: 100,
        bufferSize: WEB_PAGE_SHORTCUT_SITE_ICON_BUFFER_SIZE
      });
      await this.writeBytes(path, data);
      return path;
    } catch (_error) {
      return '';
    } finally {
      try {
        await packer.release();
      } catch (_error) {
      }
    }
  }

  private async resolveCachedSiteIconFile(url: string): Promise<string> {
    try {
      const siteIcon = await this.siteIconService.resolve(url, {
        networkPolicy: 'cacheOnly'
      });
      return siteIcon?.uri ?? '';
    } catch (_error) {
      return '';
    }
  }

  private async ensureShortcutIconFile(context: common.UIAbilityContext): Promise<string> {
    const path = `${context.filesDir}/${WEB_PAGE_SHORTCUT_ICON_FILE_NAME}`;
    try {
      if (await fileIo.access(path)) {
        return path;
      }
    } catch (_error) {
    }
    const iconBytes = await context.resourceManager.getMediaByName(WEB_PAGE_SHORTCUT_ICON_RESOURCE_NAME);
    await this.writeBytes(path, iconBytes.buffer as ArrayBuffer);
    return path;
  }

  private async writeBytes(path: string, data: ArrayBuffer): Promise<void> {
    const file = await fileIo.open(path, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      await fileIo.write(file.fd, data);
    } finally {
      await fileIo.close(file);
    }
  }

  private buildFailureResult(
    error: BusinessError,
    shortcutId: string
  ): DesktopShortcutResult {
    const code = Number(error?.code ?? 0);
    return {
      ok: false,
      message: this.resolveFailureMessage(code),
      code: code,
      shortcutId: shortcutId
    };
  }

  private resolveFailureMessage(code: number): ResourceStr {
    if (code === SHORTCUT_ALREADY_EXISTS_CODE) {
      return $r('app.string.settings_desktop_shortcut_exists');
    }
    if (code === SHORTCUT_LIMIT_REACHED_CODE) {
      return $r('app.string.settings_desktop_shortcut_limit');
    }
    if (code === SHORTCUT_REJECTED_CODE) {
      return $r('app.string.settings_desktop_shortcut_cancelled');
    }
    return $r('app.string.settings_web_app_install_failed');
  }
}
