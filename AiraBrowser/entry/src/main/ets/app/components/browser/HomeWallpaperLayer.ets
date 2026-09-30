import {
  DEFAULT_HOME_WALLPAPER_PRESENTATION_STATE,
  HomeWallpaperPresentationState,
  resolveHomeWallpaperAutoColor
} from '../../../common/models/WallpaperModels';
import { resolveHomeWallpaperRenderedMaskOpacity } from '../../../services/wallpaper/HomeWallpaperAnalysisPolicy';
import {
  HOME_WALLPAPER_RESUME_ATTEMPT_LIMIT,
  HOME_WALLPAPER_RESUME_FORCE_DELAY_MS,
  HOME_WALLPAPER_RESUME_NUDGE_DELAY_MS,
  shouldForceHomeWallpaperResume
} from '../../../services/wallpaper/HomeWallpaperPlaybackPolicy';
import { BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY } from '../../../core/theme/BrowserThemeStorageKeys';

/** Wait until a presented frame exists before uncovering the surface. */
const HOME_WALLPAPER_VIDEO_REVEAL_DELAY_MS: number = 120;

@Component
export struct HomeWallpaperLayer {
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = '#F2F3F5';
  @Prop @Watch('onWallpaperStateChanged') state: HomeWallpaperPresentationState =
    DEFAULT_HOME_WALLPAPER_PRESENTATION_STATE;
  @Prop darkModeActive: boolean = false;
  @Prop themeBackgroundColor: ResourceColor | undefined = undefined;
  @Prop @Watch('syncVideoPlayback') playbackEnabled: boolean = false;
  @Prop @Watch('onPageForegroundChanged') pageForeground: boolean = true;
  @Prop @Watch('onResumeEpochChanged') resumeEpoch: number = 0;
  @State private videoMountLatched: boolean = false;
  @State private videoFrameReady: boolean = false;
  private videoController: VideoController = new VideoController();
  private videoPrepared: boolean = false;
  private videoRevealTimer: number = -1;
  private videoPauseTimer: number = -1;
  private boundVideoPath: string = '';
  private lastProgressAtMs: number = 0;
  private progressAtResumeRequestMs: number = 0;
  private resumeAttempts: number = 0;
  private resumeRetryGeneration: number = 0;

  aboutToAppear(): void {
    this.boundVideoPath = this.state.videoPath;
    this.syncVideoPlayback();
  }

  aboutToDisappear(): void {
    this.cancelResumeRetries();
    this.clearVideoRevealTimer();
    this.clearVideoPauseTimer();
    this.videoController.stop();
  }

  build() {
    Stack() {
      if (this.hasPlayableVideo() && (this.playbackEnabled || this.videoMountLatched)) {
        this.buildPlayingVideo()
      } else if (this.state.kind === 'video' && this.state.imagePath.length > 0) {
        this.buildStillImage(this.state.imagePath)
      } else if (this.state.kind === 'image' && this.state.imagePath.length > 0) {
        this.buildStillImage(this.state.imagePath)
      } else if (this.state.kind === 'solid' && this.state.solidColor.length > 0) {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(this.state.solidColor)
      } else if (this.state.kind === 'auto') {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(resolveHomeWallpaperAutoColor(this.darkModeActive))
      } else {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(this.resolveThemeBackgroundColor())
      }

      Row()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(this.resolveOverlayOpacity(this.state))
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private buildPlayingVideo() {
    // Poster stays under the surface. Video is not removed when playback pauses:
    // tearing the surface down on a page transition is what flashes.
    if (this.state.imagePath.length > 0) {
      this.buildStillImage(this.state.imagePath)
    } else {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor(this.resolveThemeBackgroundColor())
    }
    Video({
      src: this.state.videoPath,
      controller: this.videoController,
      previewUri: this.state.imagePath,
      posterOptions: {
        showFirstFrame: this.state.imagePath.length === 0
      }
    })
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Cover)
      .autoPlay(false)
      .muted(true)
      .loop(true)
      .controls(false)
      .backgroundColor(Color.Transparent)
      .opacity(this.videoFrameReady ? 1 : 0)
      .visibility(this.videoFrameReady || this.playbackEnabled ? Visibility.Visible : Visibility.Hidden)
      .onPrepared((): void => {
        this.videoPrepared = true;
        this.syncVideoPlayback();
      })
      .onStart((): void => {
        this.notePlaybackProgress();
      })
      .onPause((): void => {
        this.noteExternalPause();
      })
      .onUpdate((_info: PlaybackInfo): void => {
        if (this.playbackEnabled) {
          this.notePlaybackProgress();
        }
      })
      .hitTestBehavior(HitTestMode.None)

    if (this.state.imagePath.length > 0 && !this.videoFrameReady) {
      this.buildStillImage(this.state.imagePath)
    }
  }

  @Builder
  private buildStillImage(path: string) {
    Image(path)
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Cover)
      .interpolation(ImageInterpolation.Medium)
      .backgroundColor(this.resolveThemeBackgroundColor())
      .hitTestBehavior(HitTestMode.None)
  }

  private onWallpaperStateChanged(): void {
    if (this.state.videoPath === this.boundVideoPath) {
      return;
    }
    this.boundVideoPath = this.state.videoPath;
    this.videoPrepared = false;
    this.videoFrameReady = false;
    this.clearVideoRevealTimer();
    if (!this.hasPlayableVideo()) {
      this.videoMountLatched = false;
    }
    this.syncVideoPlayback();
  }

  private onPageForegroundChanged(): void {
    if (this.pageForeground) {
      return;
    }
    this.cancelResumeRetries();
  }

  private onResumeEpochChanged(): void {
    const epoch = this.resumeEpoch;
    // Props from the same page-show can land in either order. Replay after both settle.
    setTimeout((): void => {
      if (epoch !== this.resumeEpoch) {
        return;
      }
      this.replayAfterForeground();
    }, 0);
  }

  private syncVideoPlayback(): void {
    if (this.playbackEnabled && this.hasPlayableVideo()) {
      this.videoMountLatched = true;
    }
    if (!this.playbackEnabled) {
      this.cancelResumeRetries();
    }
    if (!this.videoPrepared) {
      if (!this.playbackEnabled) {
        this.videoFrameReady = false;
        this.clearVideoRevealTimer();
      }
      return;
    }
    this.clearVideoPauseTimer();
    if (this.playbackEnabled && this.hasPlayableVideo()) {
      this.videoController.start();
      if (this.pageForeground) {
        this.armResumeRetries();
      }
      return;
    }
    this.videoPauseTimer = setTimeout((): void => {
      this.videoPauseTimer = -1;
      if (this.playbackEnabled || !this.videoPrepared) {
        return;
      }
      this.videoController.pause();
    }, 400);
  }

  private replayAfterForeground(): void {
    if (!this.pageForeground || !this.playbackEnabled || !this.hasPlayableVideo()) {
      return;
    }
    this.clearVideoPauseTimer();
    this.progressAtResumeRequestMs = this.lastProgressAtMs;
    this.resumeAttempts = 0;
    if (this.videoPrepared) {
      this.videoController.start();
    }
    this.scheduleResumeRetries();
  }

  private noteExternalPause(): void {
    // The system pauses Video on background even when our flag never changes.
    if (!this.pageForeground || !this.playbackEnabled || !this.videoPrepared) {
      return;
    }
    if (this.resumeAttempts >= HOME_WALLPAPER_RESUME_ATTEMPT_LIMIT) {
      return;
    }
    this.scheduleResumeRetries();
  }

  private notePlaybackProgress(): void {
    this.lastProgressAtMs = Date.now();
    this.scheduleVideoFrameReady();
  }

  private armResumeRetries(): void {
    this.progressAtResumeRequestMs = this.lastProgressAtMs;
    this.scheduleResumeRetries();
  }

  private scheduleResumeRetries(): void {
    this.cancelResumeRetries();
    const generation = this.resumeRetryGeneration;
    setTimeout((): void => {
      if (generation !== this.resumeRetryGeneration) {
        return;
      }
      this.nudgeResume();
    }, HOME_WALLPAPER_RESUME_NUDGE_DELAY_MS);
    setTimeout((): void => {
      if (generation !== this.resumeRetryGeneration) {
        return;
      }
      this.forceResumeIfStalled();
    }, HOME_WALLPAPER_RESUME_FORCE_DELAY_MS);
  }

  private nudgeResume(): void {
    if (!this.pageForeground || !this.playbackEnabled || !this.hasPlayableVideo() || !this.videoPrepared) {
      return;
    }
    this.clearVideoPauseTimer();
    this.videoController.start();
  }

  private forceResumeIfStalled(): void {
    if (this.resumeAttempts >= HOME_WALLPAPER_RESUME_ATTEMPT_LIMIT) {
      return;
    }
    if (!shouldForceHomeWallpaperResume({
      playbackRequested: this.pageForeground && this.playbackEnabled && this.hasPlayableVideo(),
      prepared: this.videoPrepared,
      progressAtRequestMs: this.progressAtResumeRequestMs,
      lastProgressAtMs: this.lastProgressAtMs
    })) {
      return;
    }
    this.resumeAttempts += 1;
    this.clearVideoPauseTimer();
    // start() is a no-op while the controller still believes it is started.
    this.videoController.pause();
    this.videoController.start();
  }

  private cancelResumeRetries(): void {
    this.resumeRetryGeneration += 1;
  }

  private scheduleVideoFrameReady(): void {
    if (this.videoFrameReady || this.videoRevealTimer >= 0 || !this.playbackEnabled) {
      return;
    }
    this.videoRevealTimer = setTimeout((): void => {
      this.videoRevealTimer = -1;
      if (this.playbackEnabled) {
        this.videoFrameReady = true;
      }
    }, HOME_WALLPAPER_VIDEO_REVEAL_DELAY_MS);
  }

  private clearVideoPauseTimer(): void {
    if (this.videoPauseTimer < 0) {
      return;
    }
    clearTimeout(this.videoPauseTimer);
    this.videoPauseTimer = -1;
  }

  private clearVideoRevealTimer(): void {
    if (this.videoRevealTimer >= 0) {
      clearTimeout(this.videoRevealTimer);
      this.videoRevealTimer = -1;
    }
  }

  private hasPlayableVideo(): boolean {
    return this.state.kind === 'video' && this.state.videoPath.length > 0;
  }

  private resolveOverlayOpacity(state: HomeWallpaperPresentationState): number {
    // A photo or looping video needs the readability mask; a flat color carries its own contrast.
    if (state.kind !== 'image' && state.kind !== 'video') {
      return 0;
    }
    return resolveHomeWallpaperRenderedMaskOpacity(state.maskOpacity);
  }

  private resolveThemeBackgroundColor(): ResourceColor {
    return this.themeBackgroundColor === undefined ? this.storedPageBackgroundColor : this.themeBackgroundColor;
  }
}
