import { resolveAppResourceText } from '../../../core/resources/AppResourceText';
import { DownloadV2TaskEntity } from '../../../domain/downloadv2/DownloadV2TaskEntity';
import { DownloadTaskBoundary } from '../../../domain/download/DownloadTypes';
import {
  BrowserDataScope,
  BrowserProfileId,
  BrowserSessionPrivacyMode
} from '../../../common/models/BrowserModels';
import { DownloadFileType } from '../../../core/download/DownloadFileTypeResolver';
import {
  DownloadRecentRecordView,
  DownloadRecentRecordsViewModel,
  DOWNLOAD_RECENT_ACTIVE_ROW_HEIGHT_VP,
  DOWNLOAD_RECENT_FOOTER_HEIGHT_VP,
  DOWNLOAD_RECENT_HEADER_HEIGHT_VP,
  DOWNLOAD_RECENT_IDLE_ROW_HEIGHT_VP,
  DOWNLOAD_RECENT_POPUP_WIDTH_VP
} from '../../../core/download/DownloadRecentRecordsViewModel';
import {
  createHiddenDownloadToolbarIndicatorState,
  DownloadToolbarIndicatorState,
  DownloadToolbarIndicatorViewModel
} from '../../../core/download/DownloadToolbarIndicatorViewModel';
import { sharedDownloadRuntimeService } from '../../bootstrap/BrowserAppRuntime';
import { AppWindowModalLayoutService } from '../../../services/layout/AppWindowModalLayoutService';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_DIVIDER_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { AiraIcon } from '../common/AiraIcon';
import { resolveDownloadFileTypeImage } from './DownloadFileTypeIcon';

const DOWNLOAD_POPUP_RADIUS_VP: number = 20;
const DOWNLOAD_POPUP_TARGET_SPACE_VP: number = 6;
const DOWNLOAD_RING_SIZE_VP: number = 28;
const DOWNLOAD_RING_STROKE_VP: number = 2;
const DOWNLOAD_BUTTON_SIZE_VP: number = 34;
const DOWNLOAD_BUTTON_ICON_SIZE_VP: number = 16;
const DOWNLOAD_ROW_ICON_SIZE_VP: number = 28;
const DOWNLOAD_ROW_HOVER_BUTTON_SIZE_VP: number = 28;
const DOWNLOAD_ROW_HOVER_ICON_SIZE_VP: number = 16;

/**
 * Plain record objects keyed only by guid are reused by ForEach and never
 * repaint the progress bar. These instances stay put and take new numbers in place.
 */
@Observed
class DownloadRecentPopupRowState {
  guid: string = '';
  fileName: string = '';
  fileType: DownloadFileType = 'unknown';
  subtitle: string = '';
  struckThrough: boolean = false;
  showProgress: boolean = false;
  progressValue: number = 0;
  canOpenFile: boolean = false;
  leadingHoverAction: string = '';
  trailingHoverAction: string = '';
  profileId: BrowserProfileId = 'profile-main';
  privacyMode: BrowserSessionPrivacyMode = 'regular';
  dataScope: BrowserDataScope = 'profile_persistent';
  windowId: string = '';
}

@Component
struct BrowserLargeScreenDownloadPopupRow {
  @ObjectLink row: DownloadRecentPopupRowState;
  onAction: (row: DownloadRecentPopupRowState, action: string) => void =
    (_row: DownloadRecentPopupRowState, _action: string): void => {};

  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY)
  private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY)
  private storedDividerColor: string = '#E3E8EF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY)
  private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY)
  private storedSecondaryTextColor: string = '#5F6875';
  @State private hovered: boolean = false;
  private swallowRowClick: boolean = false;

  build() {
    Row({ space: 12 }) {
      Image(resolveDownloadFileTypeImage(this.row.fileType))
        .width(DOWNLOAD_ROW_ICON_SIZE_VP)
        .height(DOWNLOAD_ROW_ICON_SIZE_VP)
        .objectFit(ImageFit.Contain)
        .flexShrink(0)

      Column({ space: 2 }) {
        Text(this.row.fileName)
          .width('100%')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.storedPrimaryTextColor)
          .decoration({
            type: this.row.struckThrough ? TextDecorationType.LineThrough : TextDecorationType.None,
            color: this.storedPrimaryTextColor
          })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.row.subtitle)
          .width('100%')
          .fontSize(12)
          .fontColor(this.storedSecondaryTextColor)
          .decoration({
            type: this.row.struckThrough ? TextDecorationType.LineThrough : TextDecorationType.None,
            color: this.storedSecondaryTextColor
          })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.row.showProgress) {
          Progress({
            value: this.row.progressValue,
            total: 100,
            type: ProgressType.Linear
          })
            .width('100%')
            .height(4)
            .margin({ top: 4 })
            .color(this.storedAccentColor)
            .backgroundColor(this.storedDividerColor)
            .style({
              strokeWidth: 4,
              enableSmoothEffect: true
            })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)

      if (this.hovered && this.hasHoverActions()) {
        Row({ space: 2 }) {
          if (this.row.leadingHoverAction.length > 0) {
            this.buildHoverButton(this.row.leadingHoverAction)
          }
          if (this.row.trailingHoverAction.length > 0) {
            this.buildHoverButton(this.row.trailingHoverAction)
          }
        }
        .flexShrink(0)
      }
    }
    .width('100%')
    .height(this.row.showProgress ? DOWNLOAD_RECENT_ACTIVE_ROW_HEIGHT_VP : DOWNLOAD_RECENT_IDLE_ROW_HEIGHT_VP)
    .padding({ left: 16, right: 8 })
    .alignItems(VerticalAlign.Center)
    .onHover((isHover: boolean): void => {
      this.hovered = isHover;
    })
    .onClick((): void => {
      if (this.swallowRowClick) {
        this.swallowRowClick = false;
        return;
      }
      if (!this.row.canOpenFile) {
        return;
      }
      this.onAction(this.row, 'open_file');
    })
  }

  @Builder
  private buildHoverButton(action: string) {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(this.resolveHoverIcon(action))
        .fontSize(DOWNLOAD_ROW_HOVER_ICON_SIZE_VP)
        .fontColor([this.storedSecondaryTextColor])
    }
    .width(DOWNLOAD_ROW_HOVER_BUTTON_SIZE_VP)
    .height(DOWNLOAD_ROW_HOVER_BUTTON_SIZE_VP)
    .buttonStyle(ButtonStyleMode.TEXTUAL)
    .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
    .accessibilityText(this.resolveHoverLabel(action))
    .onClick((): void => {
      this.swallowRowClick = true;
      this.onAction(this.row, action);
      setTimeout((): void => {
        this.swallowRowClick = false;
      }, 0);
    })
  }

  private hasHoverActions(): boolean {
    return this.row.leadingHoverAction.length > 0 || this.row.trailingHoverAction.length > 0;
  }

  private resolveHoverIcon(action: string): Resource {
    if (action === 'pause') {
      return $r('sys.symbol.pause_fill');
    }
    if (action === 'resume') {
      return $r('sys.symbol.play_fill');
    }
    if (action === 'open_location') {
      return $r('sys.symbol.folder');
    }
    if (action === 'open_file') {
      return $r('sys.symbol.rectangle_and_arrowshape_turn_up_right');
    }
    return $r('sys.symbol.xmark');
  }

  private resolveHoverLabel(action: string): string {
    if (action === 'pause') {
      return resolveAppResourceText($r('app.string.browser_ui_browser_video_assistant_player_overlay_013'));
    }
    if (action === 'resume') {
      return resolveAppResourceText($r('app.string.settings_pro_continue'));
    }
    if (action === 'open_location') {
      return resolveAppResourceText($r('app.string.browser_ui_browser_large_screen_download_popover_001'));
    }
    if (action === 'open_file') {
      return resolveAppResourceText($r('app.string.ui_open'));
    }
    return resolveAppResourceText($r('app.string.settings_account_cancel'));
  }
}

@Component
struct BrowserLargeScreenDownloadPopupPanel {
  @Prop @Watch('rebuildLayout') viewportHeightVp: number = 0;
  @Prop @Watch('rebuildLayout') popupReservedTopVp: number = 0;
  onOpenDownloads: () => void = (): void => {};
  onRequestClose: () => void = (): void => {};

  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY)
  private storedDividerColor: string = '#E3E8EF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY)
  private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY)
  private storedSecondaryTextColor: string = '#5F6875';

  @State private rows: DownloadRecentPopupRowState[] = [];
  @State private layoutHeightVp: number =
    DOWNLOAD_RECENT_HEADER_HEIGHT_VP + DOWNLOAD_RECENT_FOOTER_HEIGHT_VP;
  private tasks: DownloadV2TaskEntity[] = [];
  private listenerKey: string = '';
  private readonly recordsViewModel: DownloadRecentRecordsViewModel = new DownloadRecentRecordsViewModel();
  private readonly modalLayoutService: AppWindowModalLayoutService = new AppWindowModalLayoutService();

  aboutToAppear(): void {
    this.listenerKey = sharedDownloadRuntimeService.addCallbacksListener({
      onTaskListChange: (tasks: DownloadV2TaskEntity[]): void => {
        this.publish(tasks);
      }
    });
  }

  aboutToDisappear(): void {
    if (this.listenerKey.length > 0) {
      sharedDownloadRuntimeService.removeCallbacksListener(this.listenerKey);
      this.listenerKey = '';
    }
  }

  build() {
    Column() {
      this.buildHeader()
      Scroll() {
        Column() {
          if (this.rows.length === 0) {
            Text(resolveAppResourceText($r('app.string.browser_ui_browser_large_screen_download_popover_003')))
              .width('100%')
              .height(DOWNLOAD_RECENT_IDLE_ROW_HEIGHT_VP)
              .fontSize(13)
              .fontColor(this.storedSecondaryTextColor)
              .textAlign(TextAlign.Center)
          } else {
            ForEach(this.rows, (row: DownloadRecentPopupRowState): void => {
              BrowserLargeScreenDownloadPopupRow({
                row: row,
                onAction: (target: DownloadRecentPopupRowState, action: string): void => {
                  this.performAction(target, action);
                }
              })
            }, (row: DownloadRecentPopupRowState): string => row.guid)
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
      .width('100%')

      this.buildFooter()
    }
    .width('100%')
    .height(this.resolveRenderedHeight())
    .borderRadius(DOWNLOAD_POPUP_RADIUS_VP)
    .clip(true)
  }

  @Builder
  private buildHeader() {
    Row() {
      Text(resolveAppResourceText($r('app.string.browser_ui_browser_large_screen_download_popover_005')))
        .layoutWeight(1)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.storedPrimaryTextColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Button({ type: ButtonType.Circle }) {
        AiraIcon({
          airaIconId: 'browser.tabs.delete',
          iconSize: 16,
          iconColor: this.storedSecondaryTextColor
        })
      }
      .width(28)
      .height(28)
      .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
      .accessibilityText(resolveAppResourceText($r('app.string.ui_close')))
      .onClick((): void => {
        this.onRequestClose();
      })
    }
    .width('100%')
    .height(DOWNLOAD_RECENT_HEADER_HEIGHT_VP)
    .padding({ left: 16, right: 10 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildFooter() {
    Row() {
      Text(resolveAppResourceText($r('app.string.browser_ui_browser_large_screen_download_popover_002')))
        .layoutWeight(1)
        .fontSize(14)
        .fontColor(this.storedPrimaryTextColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      AiraIcon({
        airaIconId: 'site.setting.externalActions',
        iconSize: 16,
        iconColor: this.storedSecondaryTextColor
      })
    }
    .width('100%')
    .height(DOWNLOAD_RECENT_FOOTER_HEIGHT_VP)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .border({ width: { top: 1 }, color: this.storedDividerColor })
    .onClick((): void => {
      this.onOpenDownloads();
    })
  }

  private rebuildLayout(): void {
    this.publish(this.tasks);
  }

  private publish(tasks: DownloadV2TaskEntity[]): void {
    this.tasks = tasks;
    const layout = this.recordsViewModel.resolve(tasks, {
      viewportHeightVp: this.viewportHeightVp,
      reservedTopVp: this.popupReservedTopVp,
      now: Date.now()
    });
    this.layoutHeightVp = layout.heightVp;
    this.syncRows(layout.records);
  }

  private syncRows(records: DownloadRecentRecordView[]): void {
    if (this.sameRowOrder(records)) {
      for (let index = 0; index < records.length; index++) {
        const current = this.rows[index];
        const next = records[index];
        if (current !== undefined && next !== undefined) {
          this.applyRow(current, next);
        }
      }
      return;
    }
    const kept: DownloadRecentPopupRowState[] = [];
    for (let index = 0; index < records.length; index++) {
      const next = records[index];
      if (next === undefined) {
        continue;
      }
      const current = this.findRow(next.guid);
      const row = current !== undefined ? current : new DownloadRecentPopupRowState();
      this.applyRow(row, next);
      kept.push(row);
    }
    this.rows = kept;
  }

  private sameRowOrder(records: DownloadRecentRecordView[]): boolean {
    if (records.length !== this.rows.length) {
      return false;
    }
    for (let index = 0; index < records.length; index++) {
      const current = this.rows[index];
      const next = records[index];
      if (current === undefined || next === undefined || current.guid !== next.guid) {
        return false;
      }
    }
    return true;
  }

  private findRow(guid: string): DownloadRecentPopupRowState | undefined {
    for (let index = 0; index < this.rows.length; index++) {
      const row = this.rows[index];
      if (row !== undefined && row.guid === guid) {
        return row;
      }
    }
    return undefined;
  }

  private applyRow(row: DownloadRecentPopupRowState, record: DownloadRecentRecordView): void {
    row.guid = record.guid;
    row.fileName = record.fileName;
    row.fileType = record.fileType;
    row.subtitle = record.subtitle;
    row.struckThrough = record.struckThrough;
    row.showProgress = record.showProgress;
    row.progressValue = record.progressValue;
    row.canOpenFile = record.canOpenFile;
    row.leadingHoverAction = record.leadingHoverAction;
    row.trailingHoverAction = record.trailingHoverAction;
    row.profileId = record.profileId;
    row.privacyMode = record.privacyMode;
    row.dataScope = record.dataScope;
    row.windowId = record.windowId;
  }

  private resolveRenderedHeight(): number {
    return this.modalLayoutService.resolvePopupHeight(
      this.viewportHeightVp,
      this.layoutHeightVp,
      this.popupReservedTopVp
    );
  }

  private performAction(row: DownloadRecentPopupRowState, action: string): void {
    const boundary = this.boundaryFor(row);
    if (action === 'pause') {
      this.finishControl(
        sharedDownloadRuntimeService.pauseTaskForBoundary(row.guid, boundary),
        resolveAppResourceText($r('app.string.browser_ui_browser_download_management_screen_027')),
        false
      );
      return;
    }
    if (action === 'resume') {
      this.finishControl(
        sharedDownloadRuntimeService.resumeTaskForBoundary(row.guid, boundary),
        resolveAppResourceText($r('app.string.browser_ui_browser_download_management_screen_028')),
        false
      );
      return;
    }
    if (action === 'cancel') {
      this.finishControl(
        sharedDownloadRuntimeService.cancelTaskForBoundary(row.guid, boundary),
        resolveAppResourceText($r('app.string.browser_ui_browser_download_management_screen_024')),
        false
      );
      return;
    }
    if (action === 'open_location') {
      this.finishControl(
        sharedDownloadRuntimeService.openLocationForBoundary(row.guid, boundary),
        resolveAppResourceText($r('app.string.browser_ui_browser_large_screen_download_popover_004')),
        true
      );
      return;
    }
    if (action === 'open_file') {
      this.finishControl(
        sharedDownloadRuntimeService.openFileForBoundary(row.guid, boundary),
        resolveAppResourceText($r('app.string.browser_ui_browser_download_management_screen_026')),
        true
      );
    }
  }

  private boundaryFor(row: DownloadRecentPopupRowState): DownloadTaskBoundary {
    const boundary: DownloadTaskBoundary = {
      profileId: row.profileId,
      privacyMode: row.privacyMode,
      dataScope: row.dataScope
    };
    if (row.windowId.length > 0) {
      boundary.windowId = row.windowId;
    }
    return boundary;
  }

  private finishControl(result: Promise<boolean>, failureMessage: string, closeOnSuccess: boolean): void {
    result.then((succeeded: boolean): void => {
      if (!succeeded) {
        this.showToast(failureMessage);
        return;
      }
      if (closeOnSuccess) {
        this.onRequestClose();
      }
    }).catch((_error: Error): void => {
      this.showToast(failureMessage);
    });
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 1500
      });
    } catch (_error) {
    }
  }
}

@Component
export struct BrowserLargeScreenDownloadPopover {
  @Prop @Watch('rebuildLayout') viewportWidthVp: number = 0;
  @Prop @Watch('rebuildLayout') viewportHeightVp: number = 0;
  @Prop @Watch('rebuildLayout') popupReservedTopVp: number = 0;
  onOpenDownloads: () => void = (): void => {};

  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY)
  private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY)
  private storedDividerColor: string = '#E3E8EF';
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY)
  private storedSurfaceBackgroundColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY)
  private storedPrimaryTextColor: string = '#111318';

  @State private indicator: DownloadToolbarIndicatorState = createHiddenDownloadToolbarIndicatorState();
  @State private layoutHeightVp: number =
    DOWNLOAD_RECENT_HEADER_HEIGHT_VP + DOWNLOAD_RECENT_FOOTER_HEIGHT_VP;
  @State private popupVisible: boolean = false;

  private tasks: DownloadV2TaskEntity[] = [];
  private listenerKey: string = '';
  private readonly indicatorViewModel: DownloadToolbarIndicatorViewModel = new DownloadToolbarIndicatorViewModel();
  private readonly recordsViewModel: DownloadRecentRecordsViewModel = new DownloadRecentRecordsViewModel();
  private readonly modalLayoutService: AppWindowModalLayoutService = new AppWindowModalLayoutService();

  aboutToAppear(): void {
    this.listenerKey = sharedDownloadRuntimeService.addCallbacksListener({
      onTaskListChange: (tasks: DownloadV2TaskEntity[]): void => {
        this.publish(tasks);
      }
    });
  }

  aboutToDisappear(): void {
    if (this.listenerKey.length > 0) {
      sharedDownloadRuntimeService.removeCallbacksListener(this.listenerKey);
      this.listenerKey = '';
    }
  }

  build() {
    Button({ type: ButtonType.Circle }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.indicator.visible) {
          Progress({
            value: this.indicator.progressValue,
            total: 100,
            type: ProgressType.Ring
          })
            .width(DOWNLOAD_RING_SIZE_VP)
            .height(DOWNLOAD_RING_SIZE_VP)
            .style({
              strokeWidth: DOWNLOAD_RING_STROKE_VP,
              enableSmoothEffect: true,
              status: this.resolveProgressStatus()
            })
            .color(this.storedAccentColor)
            .backgroundColor(this.storedDividerColor)
            .hitTestBehavior(HitTestMode.None)
        }

        AiraIcon({
          airaIconId: 'browser.toolbar.activeDownload',
          iconSize: DOWNLOAD_BUTTON_ICON_SIZE_VP,
          iconColor: this.storedPrimaryTextColor
        })
          .hitTestBehavior(HitTestMode.None)
      }
      .width(DOWNLOAD_BUTTON_SIZE_VP)
      .height(DOWNLOAD_BUTTON_SIZE_VP)
    }
    .width(DOWNLOAD_BUTTON_SIZE_VP)
    .height(DOWNLOAD_BUTTON_SIZE_VP)
    .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
    .stateEffect(true)
    .accessibilityText(this.indicator.visible ? this.indicator.accessibilityText() : resolveAppResourceText($r('app.string.settings_web_downloads')))
    .onClick((): void => {
      if (!this.popupVisible) {
        this.rebuildLayout();
      }
      this.popupVisible = !this.popupVisible;
    })
    .bindPopup(this.popupVisible, {
      builder: this.buildPopup,
      placement: Placement.BottomRight,
      popupColor: this.storedSurfaceBackgroundColor,
      enableArrow: false,
      autoCancel: true,
      mask: false,
      targetSpace: DOWNLOAD_POPUP_TARGET_SPACE_VP,
      width: this.resolvePopupWidth(),
      radius: DOWNLOAD_POPUP_RADIUS_VP,
      showInSubWindow: false,
      focusable: true,
      shadow: {
        radius: 24,
        color: $r('app.color.elevation_shadow'),
        offsetX: 0,
        offsetY: 8
      },
      onStateChange: (event: PopupStateChangeParam): void => {
        this.popupVisible = event.isVisible;
      }
    })
  }

  @Builder
  private buildPopup() {
    BrowserLargeScreenDownloadPopupPanel({
      viewportHeightVp: this.viewportHeightVp,
      popupReservedTopVp: this.popupReservedTopVp,
      onOpenDownloads: (): void => {
        this.popupVisible = false;
        this.onOpenDownloads();
      },
      onRequestClose: (): void => {
        this.popupVisible = false;
      }
    })
      .width(this.resolvePopupWidth())
      .height(this.resolveRenderedHeight())
  }

  private rebuildLayout(): void {
    this.publish(this.tasks);
  }

  private publish(tasks: DownloadV2TaskEntity[]): void {
    this.tasks = tasks;
    this.indicator = this.indicatorViewModel.buildState(tasks);
    const layout = this.recordsViewModel.resolve(tasks, {
      viewportHeightVp: this.viewportHeightVp,
      reservedTopVp: this.popupReservedTopVp,
      now: Date.now()
    });
    this.layoutHeightVp = layout.heightVp;
  }

  private resolveProgressStatus(): ProgressStatus {
    return this.indicator.progressKnown ? ProgressStatus.PROGRESSING : ProgressStatus.LOADING;
  }

  private resolvePopupWidth(): number {
    return this.modalLayoutService.resolvePopupWidth(this.viewportWidthVp, DOWNLOAD_RECENT_POPUP_WIDTH_VP);
  }

  private resolveRenderedHeight(): number {
    return this.modalLayoutService.resolvePopupHeight(
      this.viewportHeightVp,
      this.layoutHeightVp,
      this.popupReservedTopVp
    );
  }
}
