import { resolveAppResourceText } from '../../../core/resources/AppResourceText';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_DIVIDER_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { BrowserSheetActionButton } from '../browser/BrowserModalBottomSheet';
import { CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER } from '../common/CenteredDialogSurface';

@CustomDialog
export struct BookmarkImportResultDialog {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY) private storedDividerColor: string = '#E3E8EF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  controller?: CustomDialogController;
  @Link summary: string;
  @Link importedFolderCount: number;
  @Link importedBookmarkCount: number;
  @Link duplicateCount: number;
  @Link skippedNodeCount: number;

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.history_import_success'))
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.storedPrimaryTextColor)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Column({ space: 0 }) {
        this.buildResultRow($r('app.string.bookmark_import_result'), this.buildOutcomeText(), 2)
        this.buildDivider()
        this.buildResultRow($r('app.string.bookmark_import_added'), this.formatImportedContent(), 2)
        if (this.duplicateCount > 0 || this.skippedNodeCount > 0) {
          this.buildDivider()
          this.buildResultRow($r('app.string.bookmark_import_skipped'), this.formatSkippedContent(), 2)
        }
      }
      .width('100%')

      BrowserSheetActionButton({
        stacked: true,
        label: $r('app.string.settings_pro_got_it'),
        emphasis: 'primary',
        accentColor: this.storedAccentColor,
        fillAvailableWidth: false,
        buttonWidth: '100%',
        buttonHeight: 44,
        fontSize: 15,
        onAction: () => {
          this.controller?.close();
        }
      })
    }
    .attributeModifier(CENTERED_DIALOG_SYSTEM_SURFACE_MODIFIER)
  }

  @Builder
  private buildResultRow(label: ResourceStr, value: ResourceStr, maxLines: number) {
    Row({ space: 16 }) {
      Text(label)
        .width(86)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.storedSecondaryTextColor)
        .textAlign(TextAlign.Start)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(value)
        .layoutWeight(1)
        .fontSize(14)
        .lineHeight(20)
        .fontColor(this.storedPrimaryTextColor)
        .textAlign(TextAlign.End)
        .maxLines(maxLines)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private buildDivider() {
    Divider()
      .width('100%')
      .height(1)
      .color(this.storedDividerColor)
  }

  private buildOutcomeText(): ResourceStr {
    if (this.importedFolderCount > 0 || this.importedBookmarkCount > 0) {
      return $r('app.string.bookmark_import_added_local');
    }
    if (this.duplicateCount > 0) {
      return $r('app.string.bookmark_import_none_duplicate');
    }
    if (this.skippedNodeCount > 0) {
      return $r('app.string.bookmark_import_none_invalid');
    }
    return this.summary.length > 0 ? this.summary : $r('app.string.bookmark_import_none');
  }

  private formatImportedContent(): ResourceStr {
    const segments: string[] = [];
    if (this.importedFolderCount > 0) {
      segments.push(resolveAppResourceText($r('app.string.bookmark_import_folder_count', Math.max(0, Math.floor(this.importedFolderCount)))));
    }
    if (this.importedBookmarkCount > 0) {
      segments.push(resolveAppResourceText($r('app.string.bookmark_import_bookmark_count', Math.max(0, Math.floor(this.importedBookmarkCount)))));
    }
    return segments.length > 0 ? segments.join(resolveAppResourceText($r('app.string.ui_list_separator'))) : $r('app.string.bookmark_import_none_added');
  }

  private formatSkippedContent(): ResourceStr {
    const segments: string[] = [];
    if (this.duplicateCount > 0) {
      segments.push(resolveAppResourceText($r('app.string.bookmark_import_duplicate_count', Math.max(0, Math.floor(this.duplicateCount)))));
    }
    if (this.skippedNodeCount > 0) {
      segments.push(resolveAppResourceText($r('app.string.bookmark_import_invalid_count', Math.max(0, Math.floor(this.skippedNodeCount)))));
    }
    return segments.length > 0 ? segments.join(resolveAppResourceText($r('app.string.ui_list_separator'))) : $r('app.string.bookmark_import_none_skipped');
  }
}
