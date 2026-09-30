import { common } from '@kit.AbilityKit';
import buffer from '@ohos.buffer';
import {
  AppVersionIdentity,
  ChangelogContentService
} from '../settings/ChangelogContentService';
import { AIRA_DISTRIBUTION_CAPABILITY_OWNER } from '../../common/config/AiraDistributionCapabilityOwner';
import { isEnglishSystemLanguage } from '../../core/resources/LocalizedRawFile';

const RELEASE_NOTICE_RAW_FILE_NAME: string = 'release_notice.json';
const RELEASE_NOTICE_RAW_FILE_NAME_EN: string = 'release_notice_en.json';

interface ReleaseNoticeConfig {
  enabled?: boolean;
  noticeId?: string;
  title?: string;
  updatedAt?: string;
  summary?: string;
  items?: string[];
  actionLabel?: string;
}

export interface ReleaseNoticeContent {
  noticeId: string;
  title: string;
  updatedAt: string;
  summary: string;
  items: string[];
  feedbackText: string;
  actionLabel: string;
}

export class ReleaseNoticeContentService {
  private changelogService: ChangelogContentService;

  constructor(changelogService: ChangelogContentService = new ChangelogContentService()) {
    this.changelogService = changelogService;
  }

  buildContent(context: common.Context, version: AppVersionIdentity): ReleaseNoticeContent | undefined {
    if (AIRA_DISTRIBUTION_CAPABILITY_OWNER.isCommunity()) {
      return undefined;
    }
    const config = this.readConfig(context);
    if (config === undefined || config.enabled !== true) {
      return undefined;
    }
    const changelogSection = this.changelogService.buildCurrentSection(context);
    const summary = this.normalizeText(config.summary, changelogSection.summary);
    const items = this.normalizeItems(config.items, changelogSection.items);
    return {
      noticeId: this.buildNoticeId(config.noticeId, version),
      title: this.normalizeText(
        config.title,
        this.readResourceText(context, 'release_notice_title_fallback', version.versionName)
      ),
      updatedAt: this.normalizeText(config.updatedAt, changelogSection.updateDate),
      summary: summary.length > 0 ? summary : this.readResourceText(context, 'settings_changelog_summary_fallback'),
      items: items,
      feedbackText: this.readResourceText(context, 'release_notice_feedback_text'),
      actionLabel: this.normalizeText(config.actionLabel, this.readResourceText(context, 'release_notice_action_fallback'))
    };
  }

  /**
   * Reads a notice fallback from the string catalog so it follows the system language
   * instead of being pinned to the base text.
   */
  private readResourceText(context: common.Context, name: string, formatArg?: string): string {
    try {
      const value = formatArg === undefined
        ? context.resourceManager.getStringByNameSync(name)
        : context.resourceManager.getStringByNameSync(name, formatArg);
      return value.length > 0 ? value : '';
    } catch (_error) {
      return '';
    }
  }

  /**
   * The notice JSON ships in base and English. English reads the English file and every
   * other language reads the base file; a missing English file falls back to the base one
   * rather than dropping the notice.
   */
  private readConfig(context: common.Context): ReleaseNoticeConfig | undefined {
    const baseConfig = this.readConfigFile(context, RELEASE_NOTICE_RAW_FILE_NAME);
    if (!isEnglishSystemLanguage()) {
      return baseConfig;
    }
    const englishConfig = this.readConfigFile(context, RELEASE_NOTICE_RAW_FILE_NAME_EN);
    return englishConfig !== undefined ? englishConfig : baseConfig;
  }

  private readConfigFile(context: common.Context, rawFileName: string): ReleaseNoticeConfig | undefined {
    try {
      const rawFile = context.resourceManager.getRawFileContentSync(rawFileName);
      return JSON.parse(buffer.from(rawFile.buffer).toString('utf8')) as ReleaseNoticeConfig;
    } catch (_error) {
      return undefined;
    }
  }

  private buildNoticeId(noticeId: string | undefined, version: AppVersionIdentity): string {
    const normalizedNoticeId = this.normalizeText(noticeId, 'current-release');
    return `${normalizedNoticeId}-${version.versionCode}`;
  }

  private normalizeText(value: string | undefined, fallback: string): string {
    const normalizedValue = `${value ?? ''}`.trim();
    return normalizedValue.length > 0 ? normalizedValue : fallback;
  }

  private normalizeItems(value: string[] | undefined, fallback: string[]): string[] {
    const source = Array.isArray(value) && value.length > 0 ? value : fallback;
    const items: string[] = [];
    source.forEach((item: string) => {
      const normalizedItem = item.trim();
      if (normalizedItem.length > 0) {
        items.push(normalizedItem);
      }
    });
    return items;
  }
}
