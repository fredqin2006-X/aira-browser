import {
  AiraCloudBookmarkV4BootstrapViewState
} from '../../../core/sync/AiraCloudBookmarkV4BootstrapViewModelService';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_ON_ACCENT_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';

const HIDDEN_BOOTSTRAP_STATE: AiraCloudBookmarkV4BootstrapViewState = {
  visible: false,
  status: 'hidden',
  primaryAction: 'none',
  recoveryAvailable: false,
  uid: '',
  errorMessage: ''
};

@Component
export struct AiraCloudBookmarkV4BootstrapOverlay {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_ON_ACCENT_KEY) private storedOnAccentColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = '#F2F3F5';
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private storedSurfaceColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  @Prop state: AiraCloudBookmarkV4BootstrapViewState = HIDDEN_BOOTSTRAP_STATE;
  onStart: () => void = (): void => {};
  onRetry: () => void = (): void => {};
  onRestore: () => void = (): void => {};

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll() {
        Column({ space: 0 }) {
          this.buildStatusMark()

          Text(this.resolveTitle())
            .width('100%')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.storedPrimaryTextColor)
            .textAlign(TextAlign.Start)
            .margin({ top: 24 })

          Text(this.resolveMessage())
            .width('100%')
            .fontSize(16)
            .lineHeight(24)
            .fontColor(this.storedSecondaryTextColor)
            .textAlign(TextAlign.Start)
            .margin({ top: 12 })

          if (this.state.status === 'required') {
            this.buildPreparationDetails()
          }

          if (this.state.status === 'failed' && this.state.errorMessage.length > 0) {
            Text(this.state.errorMessage)
              .width('100%')
              .fontSize(14)
              .lineHeight(21)
              .fontColor('#B42318')
              .textAlign(TextAlign.Start)
              .padding(14)
              .backgroundColor('#FFF1F0')
              .borderRadius(6)
              .margin({ top: 20 })
          }

          if (this.state.status !== 'running') {
            this.buildActions()
          }
        }
        .width('100%')
        .constraintSize({ minHeight: '100%', maxWidth: 560 })
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 24, right: 24, top: 72, bottom: 36 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.storedPageBackgroundColor)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  private buildStatusMark() {
    if (this.state.status === 'running') {
      LoadingProgress()
        .width(56)
        .height(56)
        .color(this.storedAccentColor)
    } else {
      Column() {
        Text(this.state.status === 'failed' ? '!' : 'A')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.state.status === 'failed' ? '#B42318' : this.storedOnAccentColor)
      }
      .width(56)
      .height(56)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.state.status === 'failed' ? '#FEE4E2' : this.storedAccentColor)
      .borderRadius(8)
    }
  }

  @Builder
  private buildPreparationDetails() {
    Column({ space: 12 }) {
      this.buildDetailRow('1', $r('app.string.sync_ui_aira_cloud_bookmark_v4_bootstrap_overlay_003'))
      this.buildDetailRow('2', $r('app.string.sync_ui_aira_cloud_bookmark_v4_bootstrap_overlay_008'))
      this.buildDetailRow('3', $r('app.string.sync_ui_aira_cloud_bookmark_v4_bootstrap_overlay_002'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 24, bottom: 4 })
  }

  @Builder
  private buildDetailRow(index: string, label: ResourceStr) {
    Row({ space: 12 }) {
      Text(index)
        .width(28)
        .height(28)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.storedAccentColor)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.storedSurfaceColor)
        .borderRadius(6)

      Text(label)
        .layoutWeight(1)
        .fontSize(15)
        .lineHeight(22)
        .fontColor(this.storedPrimaryTextColor)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildActions() {
    Column({ space: 10 }) {
      Button(this.state.primaryAction === 'retry'
        ? $r('app.string.novel_action_retry')
        : $r('app.string.sync_bookmark_v4_backup_update'))
        .width('100%')
        .height(50)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.storedOnAccentColor)
        .backgroundColor(this.storedAccentColor)
        .borderRadius(8)
        .onClick((): void => this.handlePrimaryAction())

    }
    .width('100%')
    .margin({ top: 32 })
  }

  private handlePrimaryAction(): void {
    if (this.state.primaryAction === 'retry') {
      this.onRetry();
      return;
    }
    if (this.state.primaryAction === 'start') {
      this.onStart();
    }
  }

  private resolveTitle(): ResourceStr {
    if (this.state.status === 'running') {
      return $r('app.string.sync_ui_aira_cloud_bookmark_v4_bootstrap_overlay_006');
    }
    if (this.state.status === 'failed') {
      return $r('app.string.sync_ui_aira_cloud_bookmark_v4_bootstrap_overlay_001');
    }
    return $r('app.string.sync_ui_aira_cloud_bookmark_v4_bootstrap_overlay_004');
  }

  private resolveMessage(): ResourceStr {
    if (this.state.status === 'running') {
      return $r('app.string.sync_ui_aira_cloud_bookmark_v4_bootstrap_overlay_009');
    }
    if (this.state.status === 'failed') {
      return $r('app.string.sync_ui_aira_cloud_bookmark_v4_bootstrap_overlay_005');
    }
    return $r('app.string.sync_ui_aira_cloud_bookmark_v4_bootstrap_overlay_007');
  }
}
