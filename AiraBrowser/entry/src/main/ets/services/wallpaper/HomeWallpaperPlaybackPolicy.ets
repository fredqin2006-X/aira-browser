export interface HomeWallpaperPlaybackInput {
  pageForeground: boolean;
  showHomePage: boolean;
  showTabsSheet: boolean;
  revealSettled: boolean;
}

/**
 * Play only while the homepage is the stable foreground.
 * A reveal, a pushed page, or the tab overview must not start the surface:
 * creating or uncovering Video during those transitions is the flash.
 */
export function shouldPlayHomeWallpaperVideo(input: HomeWallpaperPlaybackInput): boolean {
  return input.pageForeground &&
    input.showHomePage &&
    !input.showTabsSheet &&
    input.revealSettled;
}

const HOME_WALLPAPER_PLAYBACK_TRANSITION_DELAY_MS: number = 400;

/** A playing surface should have reported progress before this fallback. */
export const HOME_WALLPAPER_RESUME_NUDGE_DELAY_MS: number = 180;
export const HOME_WALLPAPER_RESUME_FORCE_DELAY_MS: number = 480;
export const HOME_WALLPAPER_RESUME_ATTEMPT_LIMIT: number = 3;

export interface HomeWallpaperResumeInput {
  playbackRequested: boolean;
  prepared: boolean;
  progressAtRequestMs: number;
  lastProgressAtMs: number;
}

/**
 * Restart only a surface that has not advanced since the foreground request.
 * Fresh progress means it is already playing; pausing it would hitch the frame.
 */
export function shouldForceHomeWallpaperResume(input: HomeWallpaperResumeInput): boolean {
  if (!input.playbackRequested || !input.prepared) {
    return false;
  }
  return input.lastProgressAtMs <= input.progressAtRequestMs;
}

export type HomeWallpaperPlaybackCommit = (enabled: boolean) => void;
export type HomeWallpaperResumeCommit = (epoch: number) => void;

/**
 * Delays pause across the outgoing page transition.
 *
 * The push still shows this page, so the pause waits until the next page has
 * covered it. Resume is immediate: a delayed resume lets that pause land after
 * the homepage is already visible and hides the frame the user is looking at.
 */
export class HomeWallpaperPlaybackGate {
  private enabled: boolean = true;
  private suspendTimer: number = -1;
  private resumeEpoch: number = 0;

  isEnabled(): boolean {
    return this.enabled;
  }

  dispose(): void {
    this.cancelSuspend();
  }

  /**
   * Always request a replay. The system pauses Video on background without
   * changing this flag, and a cancelled suspend must not skip the restart.
   */
  handlePageShow(commitEnabled: HomeWallpaperPlaybackCommit, commitResume: HomeWallpaperResumeCommit): void {
    this.cancelSuspend();
    if (!this.enabled) {
      this.enabled = true;
      commitEnabled(true);
    }
    this.resumeEpoch += 1;
    commitResume(this.resumeEpoch);
  }

  handlePageHide(commit: HomeWallpaperPlaybackCommit): void {
    this.scheduleSuspend(commit);
  }

  private scheduleSuspend(commit: HomeWallpaperPlaybackCommit): void {
    this.cancelSuspend();
    this.suspendTimer = setTimeout((): void => {
      this.suspendTimer = -1;
      this.enabled = false;
      commit(false);
    }, HOME_WALLPAPER_PLAYBACK_TRANSITION_DELAY_MS);
  }

  private cancelSuspend(): void {
    if (this.suspendTimer < 0) {
      return;
    }
    clearTimeout(this.suspendTimer);
    this.suspendTimer = -1;
  }

}
