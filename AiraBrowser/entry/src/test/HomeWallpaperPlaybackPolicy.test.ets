import { describe, expect, it } from '@ohos/hypium';
import {
  HomeWallpaperPlaybackGate,
  HomeWallpaperPlaybackInput,
  shouldForceHomeWallpaperResume,
  shouldPlayHomeWallpaperVideo
} from '../main/ets/services/wallpaper/HomeWallpaperPlaybackPolicy';

function settledHome(): HomeWallpaperPlaybackInput {
  return {
    pageForeground: true,
    showHomePage: true,
    showTabsSheet: false,
    revealSettled: true
  };
}

export default function homeWallpaperPlaybackPolicyTest(): void {
  describe('HomeWallpaperPlaybackPolicy', () => {
    it('plays_only_on_a_settled_foreground_homepage', 0, () => {
      expect(shouldPlayHomeWallpaperVideo(settledHome())).assertTrue();

      const covered: HomeWallpaperPlaybackInput = settledHome();
      covered.pageForeground = false;
      expect(shouldPlayHomeWallpaperVideo(covered)).assertFalse();

      const webPage: HomeWallpaperPlaybackInput = settledHome();
      webPage.showHomePage = false;
      expect(shouldPlayHomeWallpaperVideo(webPage)).assertFalse();

      const tabs: HomeWallpaperPlaybackInput = settledHome();
      tabs.showTabsSheet = true;
      expect(shouldPlayHomeWallpaperVideo(tabs)).assertFalse();

      const revealing: HomeWallpaperPlaybackInput = settledHome();
      revealing.revealSettled = false;
      expect(shouldPlayHomeWallpaperVideo(revealing)).assertFalse();
    });

    it('forces_resume_only_when_playback_stalled_after_the_request', 0, () => {
      expect(shouldForceHomeWallpaperResume({
        playbackRequested: true,
        prepared: true,
        progressAtRequestMs: 1000,
        lastProgressAtMs: 1000
      })).assertTrue();
      expect(shouldForceHomeWallpaperResume({
        playbackRequested: true,
        prepared: true,
        progressAtRequestMs: 1000,
        lastProgressAtMs: 1001
      })).assertFalse();
      expect(shouldForceHomeWallpaperResume({
        playbackRequested: false,
        prepared: true,
        progressAtRequestMs: 1000,
        lastProgressAtMs: 1000
      })).assertFalse();
      expect(shouldForceHomeWallpaperResume({
        playbackRequested: true,
        prepared: false,
        progressAtRequestMs: 0,
        lastProgressAtMs: 0
      })).assertFalse();
    });

    it('requests_a_replay_on_every_page_show', 0, () => {
      const gate = new HomeWallpaperPlaybackGate();
      const epochs: number[] = [];
      let enabledCommits = 0;
      gate.handlePageShow((): void => {
        enabledCommits += 1;
      }, (epoch: number): void => {
        epochs.push(epoch);
      });
      expect(gate.isEnabled()).assertTrue();
      expect(enabledCommits).assertEqual(0);
      expect(epochs.length).assertEqual(1);
      expect(epochs[0]).assertEqual(1);

      gate.handlePageShow((): void => {
        enabledCommits += 1;
      }, (epoch: number): void => {
        epochs.push(epoch);
      });
      expect(enabledCommits).assertEqual(0);
      expect(epochs[1]).assertEqual(2);
    });
  });
}
