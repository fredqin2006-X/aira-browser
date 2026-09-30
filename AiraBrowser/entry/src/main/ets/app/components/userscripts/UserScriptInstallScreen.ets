import { DEFAULT_THEME_PALETTE } from '../../../features/theme/palettes/DefaultThemePalette';
import {
  resolveUserScriptInstallLoadFailureTitle,
  resolveUserScriptInstallSurfaceMode,
  UserScriptInstallPreviewState,
  UserScriptInstallSurfaceMode
} from '../../../core/userscripts/UserScriptsSettingsViewModel';
import {
  UserScriptInstallExistingTarget,
  buildEmptyUserScriptInstallExistingTarget
} from '../../../core/userscripts/UserScriptInstallSessionCoordinator';
import { SiteIconView } from '../common/SiteIconView';
import {
  BROWSER_MODAL_BOTTOM_SHEET_ACTION_HEIGHT,
  BrowserSheetActionButton,
  BrowserSheetIconButton
} from '../browser/BrowserModalBottomSheet';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_DIVIDER_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { resolveAppResourceText } from '../../../core/resources/AppResourceText';

interface UserScriptInstallInfoRowView {
  label: ResourceStr;
  value: ResourceStr;
}

@Component
export struct UserScriptInstallScreen {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY) private storedDividerColor: string = '#E3E8EF';
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = DEFAULT_THEME_PALETTE.light.pageBackground;
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private storedSurfaceBackgroundColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  @Prop source: string = '';
  @Prop sourceUrl: string = '';
  @Prop loadErrorMessage: string = '';
  @Prop preview: UserScriptInstallPreviewState = {
    name: '',
    iconUrl: '',
    version: '',
    description: '',
    scope: '',
    scopeDetail: '',
    grants: '',
    sourceLabel: '',
    updateLabel: '',
    runAtLabel: '',
    warnings: [],
    errorMessage: '',
    saveEnabled: false
  };
  @Prop importBusy: boolean = false;
  @Prop installBusy: boolean = false;
  @Prop existingTarget: UserScriptInstallExistingTarget = buildEmptyUserScriptInstallExistingTarget();
  onSave: () => void = () => {};
  onClose: () => void = () => {};
  onRetry: () => void = () => {};

  build() {
    Column() {
      this.buildCompactHeader()

      Stack({ alignContent: Alignment.Bottom }) {
        if (this.shouldShowInstallLoading()) {
          this.buildInstallLoadingState()
        } else if (this.shouldShowLoadFailure()) {
          this.buildLoadFailureState()
        } else {
          Scroll() {
            Column({ space: 18 }) {
              if (this.shouldShowInstallConfirmation()) {
                this.buildInstallHero()
              }
              this.buildPreviewSection()
            }
            .width('100%')
            .constraintSize({ minHeight: '100%' })
            .padding({
              left: 16,
              right: 16,
              top: 8,
              bottom: this.shouldShowInstallConfirmation() ? 96 : 32
            })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })

          if (this.shouldShowInstallConfirmation()) {
            this.buildInstallAction()
          }
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.storedPageBackgroundColor)
  }

  @Builder
  private buildCompactHeader() {
    Row() {
      Blank()
        .layoutWeight(1)

      BrowserSheetIconButton({
        airaIconId: 'browser.tabs.delete',
        iconSize: 17,
        actionEnabled: !this.installBusy,
        accessibilityLabel: $r('app.string.user_script_action_close'),
        onAction: () => {
          this.onClose();
        }
      })
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16, top: 4, bottom: 4 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildLoadFailureState() {
    Column() {
      Column({ space: 14 }) {
        Text(this.resolveLoadFailureTitle())
          .width('100%')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.storedPrimaryTextColor)
          .textAlign(TextAlign.Center)
          .maxLines(2)

        Text(this.loadErrorMessage)
          .width('100%')
          .fontSize(14)
          .lineHeight(21)
          .fontColor($r('sys.color.ohos_id_color_warning'))
          .textAlign(TextAlign.Center)

        if (this.sourceUrl.trim().length > 0) {
          Column({ space: 6 }) {
            Text($r('app.string.user_script_script_url'))
              .width('100%')
              .fontSize(12)
              .fontColor(this.storedSecondaryTextColor)

            Text(this.sourceUrl)
              .width('100%')
              .fontSize(13)
              .lineHeight(18)
              .fontColor(this.storedPrimaryTextColor)
              .maxLines(4)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
          }
          .width('100%')
          .padding(16)
          .alignItems(HorizontalAlign.Start)
          .backgroundColor(this.storedSurfaceBackgroundColor)
          .borderRadius(22)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 20, right: 20 })
      .justifyContent(FlexAlign.Center)

      if (this.canRetrySourceLoad()) {
        this.buildRetryAction()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildRetryAction() {
    Row() {
      BrowserSheetActionButton({
        label: $r('app.string.user_script_action_retry'),
        emphasis: 'primary',
        accentColor: this.storedAccentColor,
        actionEnabled: this.canRetrySourceLoad(),
        buttonHeight: BROWSER_MODAL_BOTTOM_SHEET_ACTION_HEIGHT,
        onAction: () => {
          this.onRetry();
        }
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildInstallLoadingState() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(32)
        .height(32)
        .color(this.storedAccentColor)

      Text($r('app.string.user_script_reading_script'))
        .fontSize(15)
        .fontColor(this.storedPrimaryTextColor)
        .maxLines(1)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, bottom: 44 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildPreviewSection() {
    if (this.source.length > 0 || this.preview.errorMessage.length > 0 || this.preview.warnings.length > 0) {
      Column({ space: 8 }) {
        this.buildSectionTitle(this.resolvePreviewSectionTitle())
        Column({ space: 0 }) {
          this.buildPreviewDetails()
        }
        .width('100%')
        .backgroundColor(this.storedSurfaceBackgroundColor)
        .borderRadius(22)
        .clip(true)

        if (this.isUpdatingInstalledScript() && this.preview.errorMessage.length <= 0) {
          Text($r('app.string.user_script_replace_note'))
            .width('100%')
            .fontSize(13)
            .lineHeight(18)
            .fontColor(this.storedSecondaryTextColor)
            .padding({ left: 16, right: 16 })
        }
      }
      .width('100%')
    }
  }

  private resolvePreviewSectionTitle(): ResourceStr {
    if (this.shouldShowInstallConfirmation()) {
      return this.isUpdatingInstalledScript()
        ? $r('app.string.user_script_preview_update')
        : $r('app.string.user_script_preview_install');
    }
    return $r('app.string.user_script_preview_info');
  }

  private isUpdatingInstalledScript(): boolean {
    return this.existingTarget.scriptId.length > 0;
  }

  private resolveInstallActionLabel(): ResourceStr {
    if (this.installBusy) {
      return this.isUpdatingInstalledScript()
        ? $r('app.string.user_script_updating')
        : $r('app.string.user_script_installing');
    }
    return this.isUpdatingInstalledScript()
      ? $r('app.string.user_script_action_update')
      : $r('app.string.user_script_action_install');
  }

  @Builder
  private buildInstallHero() {
    Column({ space: 10 }) {
      SiteIconView({
        iconUri: this.preview.iconUrl,
        fallbackAiraIconId: 'userscripts.defaultIcon',
        fallbackIconSize: 44,
        iconSize: 76,
        cornerRadius: 22,
        fit: ImageFit.Contain,
        containerBackgroundColor: this.storedSurfaceBackgroundColor,
        frameBorderColor: this.storedDividerColor,
        textColor: this.storedPrimaryTextColor
      })

      Text(this.preview.name.length > 0 ? this.preview.name :
        (this.isUpdatingInstalledScript()
          ? $r('app.string.user_script_prepare_update')
          : $r('app.string.user_script_prepare_install')))
        .width('100%')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.storedPrimaryTextColor)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.preview.description.length > 0) {
        Text(this.preview.description)
          .width('100%')
          .fontSize(13)
          .lineHeight(19)
          .fontColor(this.storedSecondaryTextColor)
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 16, right: 16, top: 12, bottom: 4 })
  }

  @Builder
  private buildInstallAction() {
    Row() {
      BrowserSheetActionButton({
        label: this.resolveInstallActionLabel(),
        emphasis: 'primary',
        accentColor: this.storedAccentColor,
        actionEnabled: this.isInstallActionEnabled(),
        buttonHeight: BROWSER_MODAL_BOTTOM_SHEET_ACTION_HEIGHT,
        loading: this.installBusy,
        onAction: () => {
          this.onSave();
        }
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 16 })
    .alignItems(VerticalAlign.Center)
    .zIndex(2)
  }

  private isInstallActionEnabled(): boolean {
    return this.preview.saveEnabled && !this.importBusy && !this.installBusy;
  }

  @Builder
  private buildSectionTitle(title: ResourceStr) {
    Text(title)
      .width('100%')
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.storedSecondaryTextColor)
      .padding({ left: 16 })
  }

  @Builder
  private buildPreviewDetails() {
    if (this.preview.version.length > 0) {
      this.buildInfoRow(
        { label: $r('app.string.user_script_meta_version'), value: this.resolveVersionValue() },
        this.hasRowsAfterVersion()
      )
    }
    if (this.preview.sourceLabel.length > 0) {
      this.buildInfoRow(
        { label: $r('app.string.user_script_meta_source'), value: this.preview.sourceLabel },
        this.hasRowsAfterSource()
      )
    }
    if (this.preview.scope.length > 0) {
      this.buildInfoRow({
        label: $r('app.string.user_script_label_sites'),
        value: this.preview.scopeDetail.length > 0 ? this.preview.scopeDetail : this.preview.scope
      }, this.hasRowsAfterScope())
    }
    if (this.preview.description.length > 0) {
      this.buildInfoRow(
        { label: $r('app.string.user_script_label_description'), value: this.preview.description },
        this.hasRowsAfterDescription()
      )
    }
    if (this.preview.grants.length > 0) {
      this.buildInfoRow(
        { label: $r('app.string.user_script_label_capabilities'), value: this.preview.grants },
        this.hasRowsAfterGrants()
      )
    }
    if (this.preview.runAtLabel.length > 0) {
      this.buildInfoRow(
        { label: $r('app.string.user_script_meta_run_at'), value: this.preview.runAtLabel },
        this.hasRowsAfterRunAt()
      )
    }
    if (this.preview.updateLabel.length > 0) {
      this.buildInfoRow(
        { label: $r('app.string.user_script_action_update'), value: this.preview.updateLabel },
        this.hasPreviewMessages()
      )
    }
    if (this.shouldShowPendingPreviewMessage()) {
      this.buildPreviewMessage($r('app.string.user_script_pending_preview_message'), false)
    }
    if (this.preview.errorMessage.length > 0) {
      this.buildPreviewMessage(this.preview.errorMessage, true)
    }
    ForEach(this.preview.warnings, (warning: string) => {
      this.buildPreviewMessage(warning, false)
    }, (warning: string) => warning)
  }

  private resolveVersionValue(): string {
    const installedVersion = this.existingTarget.version.trim();
    if (!this.isUpdatingInstalledScript() || installedVersion.length === 0) {
      return this.preview.version;
    }
    return resolveAppResourceText($r('app.string.user_script_version_installed'), this.preview.version, installedVersion);
  }

  @Builder
  private buildInfoRow(row: UserScriptInstallInfoRowView, showDivider: boolean) {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text(row.label)
          .width(76)
          .fontSize(14)
          .fontColor(this.storedSecondaryTextColor)

        Text(row.value)
          .layoutWeight(1)
          .fontSize(14)
          .lineHeight(19)
          .fontColor(this.storedPrimaryTextColor)
          .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 13, bottom: 13 })
      .alignItems(VerticalAlign.Top)

      if (showDivider) {
        Divider()
          .width('100%')
          .height(1)
          .color(this.storedDividerColor)
          .margin({ left: 16, right: 16 })
      }
    }
    .width('100%')
  }

  @Builder
  private buildPreviewMessage(message: ResourceStr, isError: boolean) {
    Text(message)
      .width('100%')
      .fontSize(13)
      .lineHeight(18)
      .fontColor(isError ? $r('sys.color.ohos_id_color_warning') : this.storedSecondaryTextColor)
      .padding({ left: 16, right: 16, top: 13, bottom: 13 })
  }

  private shouldShowPendingPreviewMessage(): boolean {
    return this.preview.name.length <= 0 &&
      this.preview.version.length <= 0 &&
      this.preview.scope.length <= 0 &&
      this.preview.description.length <= 0 &&
      this.preview.grants.length <= 0 &&
      this.preview.errorMessage.length <= 0;
  }

  private hasPreviewMessages(): boolean {
    return this.shouldShowPendingPreviewMessage() ||
      this.preview.errorMessage.length > 0 ||
      this.preview.warnings.length > 0;
  }

  private hasRowsAfterVersion(): boolean {
    return this.preview.sourceLabel.length > 0 ||
      this.preview.scope.length > 0 ||
      this.preview.description.length > 0 ||
      this.preview.grants.length > 0 ||
      this.preview.runAtLabel.length > 0 ||
      this.preview.updateLabel.length > 0 ||
      this.hasPreviewMessages();
  }

  private hasRowsAfterSource(): boolean {
    return this.preview.scope.length > 0 ||
      this.preview.description.length > 0 ||
      this.preview.grants.length > 0 ||
      this.preview.runAtLabel.length > 0 ||
      this.preview.updateLabel.length > 0 ||
      this.hasPreviewMessages();
  }

  private hasRowsAfterScope(): boolean {
    return this.preview.description.length > 0 ||
      this.preview.grants.length > 0 ||
      this.preview.runAtLabel.length > 0 ||
      this.preview.updateLabel.length > 0 ||
      this.hasPreviewMessages();
  }

  private hasRowsAfterDescription(): boolean {
    return this.preview.grants.length > 0 ||
      this.preview.runAtLabel.length > 0 ||
      this.preview.updateLabel.length > 0 ||
      this.hasPreviewMessages();
  }

  private hasRowsAfterGrants(): boolean {
    return this.preview.runAtLabel.length > 0 ||
      this.preview.updateLabel.length > 0 ||
      this.hasPreviewMessages();
  }

  private hasRowsAfterRunAt(): boolean {
    return this.preview.updateLabel.length > 0 ||
      this.hasPreviewMessages();
  }

  private shouldShowInstallLoading(): boolean {
    return this.installSurfaceMode() === 'loading';
  }

  private shouldShowLoadFailure(): boolean {
    return this.installSurfaceMode() === 'failure';
  }

  private installSurfaceMode(): UserScriptInstallSurfaceMode {
    return resolveUserScriptInstallSurfaceMode(this.source, this.importBusy, this.loadErrorMessage);
  }

  private resolveLoadFailureTitle(): string {
    return resolveUserScriptInstallLoadFailureTitle(this.loadErrorMessage);
  }

  private canRetrySourceLoad(): boolean {
    return this.sourceUrl.trim().length > 0 && !this.importBusy && !this.installBusy;
  }

  private shouldShowInstallConfirmation(): boolean {
    return this.source.length > 0;
  }
}
