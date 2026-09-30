import {
  createHiddenBottomToolbarGuideSnapshot,
  BottomToolbarGuideAction,
  BottomToolbarGuideClipId,
  BottomToolbarGuideSnapshot
} from '../../../core/onboarding/BottomToolbarGuideCoordinator';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_FLOATING_SURFACE_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import {
  BrowserBottomSheetSurface,
  BrowserSheetActionButton
} from '../browser/BrowserModalBottomSheet';

// A floating card, so the surface and its text come from the shared theme tokens:
// white in light mode, black in dark mode, never a fixed brand color.
const BOTTOM_TOOLBAR_GUIDE_CARD_RADIUS: number = 24;
const BOTTOM_TOOLBAR_GUIDE_CARD_PADDING: number = 18;
const BOTTOM_TOOLBAR_GUIDE_ART_RADIUS: number = 14;
// A hairline only: the clip is mostly white, so without it the card edge disappears
// into a light surface. `browser_top_address_edge` is the lightest adaptive hairline
// the theme carries: 7% black in light mode, 14% white in dark mode.
const BOTTOM_TOOLBAR_GUIDE_ART_BORDER_WIDTH: number = 1;
// Every clip is a bundled 720x426 recording, so the card slot never changes shape.
const BOTTOM_TOOLBAR_GUIDE_ART_ASPECT_RATIO: number = 720 / 426;
const BOTTOM_TOOLBAR_GUIDE_PROGRESS_FONT_SIZE: number = 13;
const BOTTOM_TOOLBAR_GUIDE_TITLE_FONT_SIZE: number = 22;
const BOTTOM_TOOLBAR_GUIDE_MESSAGE_FONT_SIZE: number = 15;
// The player surface is black until it has a picture. Hold the still through that
// beat, the same way the feature-intro mesh does, so tapping next does not flash.
const BOTTOM_TOOLBAR_GUIDE_CLIP_REVEAL_DELAY_MS: number = 120;
const BOTTOM_TOOLBAR_GUIDE_ART_FALLBACK_COLOR: string = '#F4F6F8';

@Component
export struct BottomToolbarGuideSheet {
  @StorageProp(BROWSER_THEME_STORAGE_FLOATING_SURFACE_KEY) private storedFloatingSurfaceColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  @Prop @Watch('onGuideSnapshot') state: BottomToolbarGuideSnapshot = createHiddenBottomToolbarGuideSnapshot();
  @Prop layoutMode: 'phone' | 'large_screen' = 'phone';
  onAction: (action: BottomToolbarGuideAction) => void = (_action: BottomToolbarGuideAction) => {};
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

  private revealPlayingClip(clipId: BottomToolbarGuideClipId): void {
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
    }, BOTTOM_TOOLBAR_GUIDE_CLIP_REVEAL_DELAY_MS);
  }

  private clearRevealTimer(): void {
    this.revealGeneration += 1;
    if (this.revealTimer >= 0) {
      clearTimeout(this.revealTimer);
      this.revealTimer = -1;
    }
  }

  // $rawfile only accepts a literal, so each step names its own clip and still.
  // The stills stay mounted: swapping players is what used to flash black.
  @Builder
  private guidePoster(src: Resource, clipId: BottomToolbarGuideClipId) {
    Image(src)
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Cover)
      .opacity(this.state.clipId === clipId ? 1 : 0)
  }

  @Builder
  private guideClip(src: Resource, poster: Resource, clipId: BottomToolbarGuideClipId) {
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
    BrowserBottomSheetSurface({
      presentation: 'flat_content',
      horizontalPadding: 16,
      topPadding: 0,
      bottomPadding: 16
    }) {
      Column({ space: 18 }) {
        // The rounding, the clip, and the stroke cannot live on one node: the Video
        // paints its own square frame above that node's stroke and a clip on the same
        // node shaves the stroke at the corners. So the stroke sits on an unclipped
        // outer box, and the clip is an inset child whose radius stays concentric.
        Stack() {
          Stack() {
            // Decoration only: each clip just loops, with no controls and no sound.
            // Muted is also what lets it autoplay. The still of the incoming step is
            // already decoded, so the slot never goes empty while the player restarts.
            this.guidePoster($rawfile('bottom_toolbar_guide_poster.jpg'), 'hide')
            this.guidePoster($rawfile('return_home_guide_poster.jpg'), 'return_home')
            this.guidePoster($rawfile('tools_panel_guide_poster.jpg'), 'tools_panel')
            this.guidePoster($rawfile('tab_switch_guide_poster.jpg'), 'tab_switch')
            if (this.state.clipId === 'return_home') {
              this.guideClip($rawfile('return_home_guide.mp4'), $rawfile('return_home_guide_poster.jpg'), 'return_home')
            } else if (this.state.clipId === 'tools_panel') {
              this.guideClip($rawfile('tools_panel_guide.mp4'), $rawfile('tools_panel_guide_poster.jpg'), 'tools_panel')
            } else if (this.state.clipId === 'tab_switch') {
              this.guideClip($rawfile('tab_switch_guide.mp4'), $rawfile('tab_switch_guide_poster.jpg'), 'tab_switch')
            } else {
              this.guideClip($rawfile('bottom_toolbar_guide.mp4'), $rawfile('bottom_toolbar_guide_poster.jpg'), 'hide')
            }
          }
          .backgroundColor(BOTTOM_TOOLBAR_GUIDE_ART_FALLBACK_COLOR)
          .width('100%')
          .height('100%')
          .borderRadius(BOTTOM_TOOLBAR_GUIDE_ART_RADIUS - BOTTOM_TOOLBAR_GUIDE_ART_BORDER_WIDTH)
          .clip(true)
        }
        .width('100%')
        .aspectRatio(BOTTOM_TOOLBAR_GUIDE_ART_ASPECT_RATIO)
        .padding(BOTTOM_TOOLBAR_GUIDE_ART_BORDER_WIDTH)
        .borderRadius(BOTTOM_TOOLBAR_GUIDE_ART_RADIUS)
        .border({
          width: BOTTOM_TOOLBAR_GUIDE_ART_BORDER_WIDTH,
          color: $r('app.color.browser_top_address_edge')
        })

        Column({ space: 8 }) {
          if (this.state.progressLabel.length > 0) {
            Text(this.state.progressLabel)
              .width('100%')
              .fontSize(BOTTOM_TOOLBAR_GUIDE_PROGRESS_FONT_SIZE)
              .fontColor(this.storedSecondaryTextColor)
              .textAlign(TextAlign.Center)
          }

          Text(this.state.title)
            .width('100%')
            .fontSize(BOTTOM_TOOLBAR_GUIDE_TITLE_FONT_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.storedPrimaryTextColor)
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.state.message)
            .width('100%')
            .fontSize(BOTTOM_TOOLBAR_GUIDE_MESSAGE_FONT_SIZE)
            .lineHeight(22)
            .fontColor(this.storedSecondaryTextColor)
            .textAlign(TextAlign.Center)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        Column({ space: 8 }) {
          BrowserSheetActionButton({
            label: this.state.primaryActionTitle,
            emphasis: 'primary',
            stacked: true,
            accentColor: this.storedAccentColor,
            onAction: () => {
              this.onAction(this.state.primaryAction);
            }
          })

          BrowserSheetActionButton({
            label: this.state.secondaryActionTitle,
            emphasis: 'ghost',
            stacked: true,
            onAction: () => {
              this.onAction('never_show_again');
            }
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding(BOTTOM_TOOLBAR_GUIDE_CARD_PADDING)
      .backgroundColor(this.storedFloatingSurfaceColor)
      .borderRadius(BOTTOM_TOOLBAR_GUIDE_CARD_RADIUS)
      .clip(true)
      .alignItems(HorizontalAlign.Center)
    }
  }
}

