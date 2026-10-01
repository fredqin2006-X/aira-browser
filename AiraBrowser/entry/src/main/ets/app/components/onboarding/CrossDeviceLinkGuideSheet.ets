import {
  createHiddenCrossDeviceLinkGuideSnapshot,
  CrossDeviceLinkGuideAction,
  CrossDeviceLinkGuideClipId,
  CrossDeviceLinkGuideSnapshot
} from '../../../core/onboarding/CrossDeviceLinkGuideCoordinator';
import { APP_STANDARD_HORIZONTAL_PADDING } from '../common/AppLayoutTokens';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import { BrowserSheetActionButton } from '../browser/BrowserModalBottomSheet';
import { localizeCrossDeviceLinkCopy } from '../../../core/sync/CrossDeviceLinkViewModel';

const CROSS_DEVICE_LINK_GUIDE_PROGRESS_FONT_SIZE: number = 13;
const CROSS_DEVICE_LINK_GUIDE_TITLE_FONT_SIZE: number = 22;
const CROSS_DEVICE_LINK_GUIDE_MESSAGE_FONT_SIZE: number = 15;
const CROSS_DEVICE_LINK_GUIDE_COPY_TOP: number = 20;
const CROSS_DEVICE_LINK_GUIDE_FOOTER_TOP_GAP: number = 20;
const CROSS_DEVICE_LINK_GUIDE_BOTTOM_PADDING: number = 28;
const CROSS_DEVICE_LINK_GUIDE_DRAG_WIDTH: number = 36;
const CROSS_DEVICE_LINK_GUIDE_DRAG_HEIGHT: number = 4;
const CROSS_DEVICE_LINK_GUIDE_DRAG_TOP: number = 8;
const CROSS_DEVICE_LINK_GUIDE_CLIP_REVEAL_DELAY_MS: number = 120;
const CROSS_DEVICE_LINK_GUIDE_ART_FALLBACK_COLOR: string = '#F4F6F8';

@Component
export struct CrossDeviceLinkGuideSheet {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  @Prop @Watch('onGuideSnapshot') state: CrossDeviceLinkGuideSnapshot = createHiddenCrossDeviceLinkGuideSnapshot();
  onAction: (action: CrossDeviceLinkGuideAction) => void = (_action: CrossDeviceLinkGuideAction) => {};
  @State private shownClipId: string = '';
  private readonly videoController: VideoController = new VideoController();
  private revealTimer: number = -1;
  private revealGeneration: number = 0;
  private trackedClipId: string = '';

  aboutToAppear(): void {
    this.trackedClipId = this.state.clipId;
  }

  aboutToDisappear(): void {
    this.clearRevealTimer();
    this.videoController.stop();
  }

  private onGuideSnapshot(): void {
    if (this.trackedClipId === this.state.clipId) {
      return;
    }
    this.trackedClipId = this.state.clipId;
    this.shownClipId = '';
    this.clearRevealTimer();
  }

  private revealPlayingClip(clipId: CrossDeviceLinkGuideClipId): void {
    if (this.state.clipId !== clipId || this.shownClipId === clipId) {
      return;
    }
    this.clearRevealTimer();
    const generation = this.revealGeneration + 1;
    this.revealGeneration = generation;
    this.revealTimer = setTimeout((): void => {
      if (this.revealGeneration !== generation) {
        return;
      }
      this.revealTimer = -1;
      if (this.state.clipId === clipId) {
        this.shownClipId = clipId;
      }
    }, CROSS_DEVICE_LINK_GUIDE_CLIP_REVEAL_DELAY_MS);
  }

  private clearRevealTimer(): void {
    this.revealGeneration += 1;
    if (this.revealTimer >= 0) {
      clearTimeout(this.revealTimer);
      this.revealTimer = -1;
    }
  }

  @Builder
  private guidePoster(src: Resource, clipId: CrossDeviceLinkGuideClipId) {
    Image(src)
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Cover)
      .opacity(this.state.clipId === clipId ? 1 : 0)
  }

  @Builder
  private guideClip(src: Resource, poster: Resource, clipId: CrossDeviceLinkGuideClipId) {
    Video({
      src: src,
      previewUri: poster,
      controller: this.videoController
    })
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Cover)
      .backgroundColor(Color.Transparent)
      .muted(true)
      .controls(false)
      .loop(true)
      .autoPlay(true)
      .opacity(this.shownClipId === clipId ? 1 : 0)
      .visibility(this.shownClipId === clipId ? Visibility.Visible : Visibility.Hidden)
      .onPrepared((): void => {
        this.videoController.start();
      })
      .onStart((): void => {
        this.revealPlayingClip(clipId);
      })
  }

  build() {
    // The clip and the copy scroll together; the two actions sit in their own footer at the
    // bottom of the sheet. A sheet taller than its content must not strand the buttons
    // mid-screen with empty surface below them.
    Column({ space: 0 }) {
      Scroll() {
        Column({ space: 0 }) {
          Stack({ alignContent: Alignment.Top }) {
            Stack() {
              this.guidePoster($rawfile('page_push_guide_poster.jpg'), 'page_push')
              this.guidePoster($rawfile('device_tabs_guide_poster.jpg'), 'device_tabs')
              if (this.state.clipId === 'device_tabs') {
                this.guideClip($rawfile('device_tabs_guide.mp4'), $rawfile('device_tabs_guide_poster.jpg'), 'device_tabs')
              } else {
                this.guideClip($rawfile('page_push_guide.mp4'), $rawfile('page_push_guide_poster.jpg'), 'page_push')
              }
            }
            .backgroundColor(CROSS_DEVICE_LINK_GUIDE_ART_FALLBACK_COLOR)
            .width('100%')
            .height('100%')
            .clip(true)

            Column()
              .width(CROSS_DEVICE_LINK_GUIDE_DRAG_WIDTH)
              .height(CROSS_DEVICE_LINK_GUIDE_DRAG_HEIGHT)
              .margin({ top: CROSS_DEVICE_LINK_GUIDE_DRAG_TOP })
              .borderRadius(CROSS_DEVICE_LINK_GUIDE_DRAG_HEIGHT)
              .backgroundColor('#F4F6F8')
              .hitTestBehavior(HitTestMode.None)
          }
          .width('100%')
          .aspectRatio(1)
          .clip(true)

          Column({ space: 8 }) {
            if (this.state.progressLabel.length > 0) {
              Text(this.state.progressLabel)
                .width('100%')
                .fontSize(CROSS_DEVICE_LINK_GUIDE_PROGRESS_FONT_SIZE)
                .fontColor(this.storedSecondaryTextColor)
                .textAlign(TextAlign.Center)
            }

            Text(localizeCrossDeviceLinkCopy(this.state.title))
              .width('100%')
              .fontSize(CROSS_DEVICE_LINK_GUIDE_TITLE_FONT_SIZE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.storedPrimaryTextColor)
              .textAlign(TextAlign.Center)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(localizeCrossDeviceLinkCopy(this.state.message))
              .width('100%')
              .fontSize(CROSS_DEVICE_LINK_GUIDE_MESSAGE_FONT_SIZE)
              .lineHeight(22)
              .fontColor(this.storedSecondaryTextColor)
              .textAlign(TextAlign.Center)
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({
            left: APP_STANDARD_HORIZONTAL_PADDING,
            right: APP_STANDARD_HORIZONTAL_PADDING,
            top: CROSS_DEVICE_LINK_GUIDE_COPY_TOP
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)

      Column({ space: 8 }) {
        BrowserSheetActionButton({
          label: localizeCrossDeviceLinkCopy(this.state.primaryActionTitle),
          emphasis: 'primary',
          stacked: true,
          accentColor: this.storedAccentColor,
          onAction: () => {
            this.onAction(this.state.primaryAction);
          }
        })

        BrowserSheetActionButton({
          label: localizeCrossDeviceLinkCopy(this.state.secondaryActionTitle),
          emphasis: 'ghost',
          stacked: true,
          onAction: () => {
            this.onAction('never_show_again');
          }
        })
      }
      .width('100%')
      .padding({
        left: APP_STANDARD_HORIZONTAL_PADDING,
        right: APP_STANDARD_HORIZONTAL_PADDING,
        top: CROSS_DEVICE_LINK_GUIDE_FOOTER_TOP_GAP,
        bottom: CROSS_DEVICE_LINK_GUIDE_BOTTOM_PADDING
      })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
