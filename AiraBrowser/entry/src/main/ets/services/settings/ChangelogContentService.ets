import { common } from '@kit.AbilityKit';
import bundleManager from '@ohos.bundle.bundleManager';
import buffer from '@ohos.buffer';
import {
  APP_PREVIEW_VERSION_CODE,
  APP_PREVIEW_VERSION_NAME
} from '../../common/constants/AppVersionInfo';
import { AIRA_DISTRIBUTION_CAPABILITY_OWNER } from '../../common/config/AiraDistributionCapabilityOwner';
import { isEnglishSystemLanguage } from '../../core/resources/LocalizedRawFile';

const CHANGELOG_RAW_FILE_NAME: string = 'changelog.md';
const CHANGELOG_RAW_FILE_NAME_EN: string = 'changelog_en.md';
const COMMUNITY_CHANGELOG_RAW_FILE_NAME: string = 'community-changelog.md';
const COMMUNITY_CHANGELOG_RAW_FILE_NAME_EN: string = 'community-changelog_en.md';

export interface AppVersionIdentity {
  versionName: string;
  versionCode: number;
}

export interface CurrentChangelogSection {
  versionName: string;
  versionCode: number;
  updateDate: string;
  summary: string;
  items: string[];
  markdown: string;
  available: boolean;
  /** True when the section was rendered in the base (Chinese) text. */
  fellBackToBase: boolean;
}

class ChangelogSectionBlock {
  heading: string;
  body: string;

  constructor(heading: string, body: string) {
    this.heading = heading;
    this.body = body;
  }
}

const VERSION_SECTION_HEADING: RegExp = /^##\s+\S+\s+\(\d+\)\s*$/;

export class ChangelogContentService {
  buildFullMarkdown(context: common.Context): string {
    return this.readMarkdown(context);
  }

  buildCurrentSection(context: common.Context): CurrentChangelogSection {
    const version = this.resolveCurrentVersion();
    return this.parseCurrentSection(this.readMarkdown(context), version);
  }

  resolveCurrentVersion(): AppVersionIdentity {
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      const versionName = `${bundleInfo.versionName ?? ''}`.trim();
      return {
        versionName: versionName.length > 0 ? versionName : APP_PREVIEW_VERSION_NAME,
        versionCode: this.normalizeVersionCode(bundleInfo.versionCode, APP_PREVIEW_VERSION_CODE)
      };
    } catch (_error) {
      return {
        versionName: APP_PREVIEW_VERSION_NAME,
        versionCode: APP_PREVIEW_VERSION_CODE
      };
    }
  }

  private readMarkdown(context: common.Context): string {
    const baseMarkdown = this.readRawMarkdown(context, this.resolveBaseRawFileName());
    if (!isEnglishSystemLanguage()) {
      return baseMarkdown;
    }
    const englishMarkdown = this.readRawMarkdown(context, this.resolveEnglishRawFileName());
    return this.mergeEnglishSections(baseMarkdown, englishMarkdown);
  }

  private readRawMarkdown(context: common.Context, rawFileName: string): string {
    try {
      const rawFile = context.resourceManager.getRawFileContentSync(rawFileName);
      return this.applyRuntimePlaceholders(buffer.from(rawFile.buffer).toString('utf8'));
    } catch (error) {
      const detail = this.stringifyError(error);
      return [
        `# ${this.readLocalizedName(context, 'settings_about_changelog', '更新日志')}`,
        '',
        this.readLocalizedName(
          context,
          'settings_about_changelog_load_failed_detail',
          `更新日志加载失败：${detail}`,
          detail
        )
      ].join('\n');
    }
  }

  /**
   * Overlays the English sections on the base document, keeping the base order and keeping
   * every base section the English file does not translate.
   */
  private mergeEnglishSections(baseMarkdown: string, englishMarkdown: string): string {
    const baseSections = this.splitVersionSections(baseMarkdown);
    const englishSections = this.splitVersionSections(englishMarkdown);
    if (baseSections.length <= 0) {
      return englishMarkdown;
    }
    const englishHeader = this.extractDocumentHeader(englishMarkdown);
    const header = englishHeader.length > 0 ? englishHeader : this.extractDocumentHeader(baseMarkdown);
    const englishByHeading = new Map<string, string>();
    for (let index = 0; index < englishSections.length; index += 1) {
      const section = englishSections[index];
      if (!englishByHeading.has(section.heading)) {
        englishByHeading.set(section.heading, section.body);
      }
    }
    const merged: string[] = [];
    for (let index = 0; index < baseSections.length; index += 1) {
      const section = baseSections[index];
      const englishBody = englishByHeading.get(section.heading);
      merged.push(englishBody !== undefined ? englishBody : section.body);
    }
    for (let index = 0; index < englishSections.length; index += 1) {
      const section = englishSections[index];
      if (!this.hasSectionHeading(baseSections, section.heading)) {
        merged.push(section.body);
      }
    }
    return [header, ...merged].join('\n');
  }

  private hasSectionHeading(sections: ChangelogSectionBlock[], heading: string): boolean {
    for (let index = 0; index < sections.length; index += 1) {
      if (sections[index].heading === heading) {
        return true;
      }
    }
    return false;
  }

  private extractDocumentHeader(markdown: string): string {
    const match = /^([\s\S]*?)(?=^##\s)/m.exec(markdown);
    return match === null ? '' : match[1].trim();
  }

  /**
   * Splits a changelog into `## <version> (<code>)` blocks. A heading that does not carry a
   * version stays in the preceding block, so prose between versions is never dropped.
   */
  private splitVersionSections(markdown: string): ChangelogSectionBlock[] {
    const lines = markdown.split(/\r?\n/);
    const blocks: ChangelogSectionBlock[] = [];
    let heading = '';
    let body: string[] = [];
    for (let index = 0; index < lines.length; index += 1) {
      const line = lines[index];
      const trimmedLine = line.trim();
      if (VERSION_SECTION_HEADING.test(trimmedLine)) {
        if (body.length > 0) {
          blocks.push(new ChangelogSectionBlock(heading, body.join('\n').trim()));
        }
        heading = trimmedLine.replace(/^##\s+/, '');
        body = [line];
        continue;
      }
      if (body.length > 0) {
        body.push(line);
      }
    }
    if (body.length > 0) {
      blocks.push(new ChangelogSectionBlock(heading, body.join('\n').trim()));
    }
    return blocks;
  }

  private resolveBaseRawFileName(): string {
    return AIRA_DISTRIBUTION_CAPABILITY_OWNER.isCommunity()
      ? COMMUNITY_CHANGELOG_RAW_FILE_NAME
      : CHANGELOG_RAW_FILE_NAME;
  }

  private resolveEnglishRawFileName(): string {
    return AIRA_DISTRIBUTION_CAPABILITY_OWNER.isCommunity()
      ? COMMUNITY_CHANGELOG_RAW_FILE_NAME_EN
      : CHANGELOG_RAW_FILE_NAME_EN;
  }

  private applyRuntimePlaceholders(markdown: string): string {
    const version = this.resolveCurrentVersion();
    return markdown
      .replace(/\{\{CURRENT_VERSION_NAME\}\}/g, version.versionName)
      .replace(/\{\{CURRENT_VERSION_CODE\}\}/g, `${version.versionCode}`);
  }

  private parseCurrentSection(markdown: string, version: AppVersionIdentity): CurrentChangelogSection {
    const sectionLines = this.extractFirstVersionSectionLines(markdown);
    if (sectionLines.length <= 0) {
      return this.buildFallbackSection(version);
    }
    const bodyLines = sectionLines.slice(1);
    const updateDate = this.extractUpdateDate(bodyLines);
    const summary = this.extractSummary(bodyLines);
    const items = this.extractBulletItems(bodyLines);
    return {
      versionName: version.versionName,
      versionCode: version.versionCode,
      updateDate: updateDate,
      summary: summary.length > 0 ? summary : '这一版带来了一些体验优化和问题修复。',
      items: items,
      markdown: sectionLines.join('\n').trim(),
      available: true,
      fellBackToBase: false
    };
  }

  private extractFirstVersionSectionLines(markdown: string): string[] {
    const lines = markdown.split(/\r?\n/);
    let startIndex = -1;
    let endIndex = lines.length;
    for (let index = 0; index < lines.length; index++) {
      if (/^##\s+/.test(lines[index].trim())) {
        startIndex = index;
        break;
      }
    }
    if (startIndex < 0) {
      return [];
    }
    for (let index = startIndex + 1; index < lines.length; index++) {
      if (/^##\s+/.test(lines[index].trim())) {
        endIndex = index;
        break;
      }
    }
    return lines.slice(startIndex, endIndex);
  }

  private extractUpdateDate(lines: string[]): string {
    for (let index = 0; index < lines.length; index++) {
      const line = lines[index].trim();
      if (/^\d{4}-\d{2}-\d{2}$/.test(line)) {
        return line;
      }
    }
    return '';
  }

  private extractSummary(lines: string[]): string {
    for (let index = 0; index < lines.length; index++) {
      const line = lines[index].trim();
      if (line.length <= 0 || line.startsWith('- ') || /^\d{4}-\d{2}-\d{2}$/.test(line)) {
        continue;
      }
      return line;
    }
    return '';
  }

  private extractBulletItems(lines: string[]): string[] {
    const items: string[] = [];
    lines.forEach((line: string) => {
      const normalizedLine = line.trim();
      if (!normalizedLine.startsWith('- ')) {
        return;
      }
      const item = normalizedLine.substring(2).trim();
      if (item.length > 0) {
        items.push(item);
      }
    });
    return items;
  }

  private buildFallbackSection(version: AppVersionIdentity): CurrentChangelogSection {
    return {
      versionName: version.versionName,
      versionCode: version.versionCode,
      updateDate: '',
      summary: 'Aira 已更新到新版本。',
      items: [],
      markdown: '',
      available: false,
      fellBackToBase: true
    };
  }

  private normalizeVersionCode(value: number | undefined, fallback: number): number {
    const versionCode = Number(value);
    return Number.isFinite(versionCode) && versionCode > 0 ? Math.round(versionCode) : fallback;
  }

  private stringifyError(error: Object | undefined): string {
    if (error instanceof Error && error.message.length > 0) {
      return error.message;
    }
    return JSON.stringify(error);
  }

  private readLocalizedName(context: common.Context, name: string, fallback: string, formatArg?: string): string {
    try {
      const value = formatArg === undefined ?
        context.resourceManager.getStringByNameSync(name) :
        context.resourceManager.getStringByNameSync(name, formatArg);
      return value.length > 0 ? value : fallback;
    } catch (_error) {
      return fallback;
    }
  }
}
