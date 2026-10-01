import { describe, expect, it } from '@ohos/hypium';
import {
  DEFAULT_WALLPAPER_BING_STATE,
  DEFAULT_WALLPAPER_SETTINGS,
  findHomeWallpaperChoice,
  HOME_WALLPAPER_AUTO_CHOICE_ID,
  HOME_WALLPAPER_AUTO_DARK_COLOR,
  HOME_WALLPAPER_AUTO_LIGHT_COLOR,
  HOME_WALLPAPER_THEME_CHOICE_ID,
  listHomeWallpaperChoices,
  normalizeHomeWallpaperSolidColorId,
  paintsHomeBackdrop,
  resolveHomeWallpaperAutoColor,
  usesOwnHomeForegroundTone,
  WallpaperAsset,
  WallpaperMode,
  WallpaperRepositorySnapshot,
  WallpaperSettings
} from '../main/ets/common/models/WallpaperModels';
import { HOME_IMAGE_WALLPAPER_MASK_OPACITY } from '../main/ets/services/wallpaper/HomeWallpaperAnalysisPolicy';
import { WallpaperSettingsViewModel, WallpaperColorChoiceViewState } from '../main/ets/core/wallpaper/WallpaperSettingsViewModel';
import { WallpaperPresentationService } from '../main/ets/services/wallpaper/WallpaperPresentationService';

function settingsWith(mode: WallpaperMode, solidColorId: string): WallpaperSettings {
  return {
    mode: mode,
    solidColorId: solidColorId,
    bingWallpaperId: '',
    customWallpaperId: '',
    bing: DEFAULT_WALLPAPER_BING_STATE,
    updatedAt: 10
  };
}

function snapshotWith(settings: WallpaperSettings): WallpaperRepositorySnapshot {
  return { settings: settings, assets: [] };
}

function countSelected(choices: WallpaperColorChoiceViewState[]): number {
  let selected = 0;
  for (let index = 0; index < choices.length; index += 1) {
    if (choices[index].isSelected) {
      selected += 1;
    }
  }
  return selected;
}

export default function wallpaperColorChoicePolicyTest(): void {
  describe('WallpaperColorChoicePolicy', () => {
    it('opens_with_the_auto_black_white_swatch', 0, () => {
      const choices = listHomeWallpaperChoices();
      expect(choices[0].id).assertEqual(HOME_WALLPAPER_AUTO_CHOICE_ID);
      expect(choices[0].kind).assertEqual('auto');
      // Auto carries no color of its own; it is white or black by mode.
      expect(choices[0].color).assertEqual('');
      expect(choices[1].kind).assertEqual('solid');
      const last = choices[choices.length - 1];
      expect(last.id).assertEqual(HOME_WALLPAPER_THEME_CHOICE_ID);
      expect(last.kind).assertEqual('theme');
      const ids: string[] = [];
      for (let index = 0; index < choices.length; index += 1) {
        expect(ids.indexOf(choices[index].id)).assertEqual(-1);
        expect(choices[index].label.length > 0).assertTrue();
        ids.push(choices[index].id);
      }
    });

    it('paints_white_in_light_mode_and_black_in_dark_mode', 0, () => {
      expect(resolveHomeWallpaperAutoColor(false)).assertEqual(HOME_WALLPAPER_AUTO_LIGHT_COLOR);
      expect(resolveHomeWallpaperAutoColor(true)).assertEqual(HOME_WALLPAPER_AUTO_DARK_COLOR);
      expect(HOME_WALLPAPER_AUTO_LIGHT_COLOR).assertEqual('#FFFFFF');
      expect(HOME_WALLPAPER_AUTO_DARK_COLOR).assertEqual('#000000');
    });

    it('starts_new_installs_on_the_theme_palette', 0, () => {
      expect(DEFAULT_WALLPAPER_SETTINGS.mode).assertEqual('theme');
    });

    it('accepts_only_a_flat_color_as_a_solid_color_id', 0, () => {
      expect(normalizeHomeWallpaperSolidColorId('blush')).assertEqual('blush');
      expect(normalizeHomeWallpaperSolidColorId('  sage ')).assertEqual('sage');
      // Auto and theme are modes, not colors, so they fall back to a real flat color.
      expect(normalizeHomeWallpaperSolidColorId('auto')).assertEqual('mist');
      expect(normalizeHomeWallpaperSolidColorId('theme')).assertEqual('mist');
      expect(normalizeHomeWallpaperSolidColorId('nope')).assertEqual('mist');
      expect(normalizeHomeWallpaperSolidColorId(undefined)).assertEqual('mist');
      expect(findHomeWallpaperChoice('sage')?.label).assertEqual('浅绿');
    });

    it('embraces_auto_in_the_painted_backdrop', 0, () => {
      expect(paintsHomeBackdrop('image')).assertTrue();
      expect(paintsHomeBackdrop('video')).assertTrue();
      expect(paintsHomeBackdrop('solid')).assertTrue();
      expect(paintsHomeBackdrop('auto')).assertTrue();
      expect(paintsHomeBackdrop('default')).assertFalse();
      // Auto borrows the theme's tone instead of naming one. A video names its own, like a photo.
      expect(usesOwnHomeForegroundTone('image')).assertTrue();
      expect(usesOwnHomeForegroundTone('video')).assertTrue();
      expect(usesOwnHomeForegroundTone('solid')).assertTrue();
      expect(usesOwnHomeForegroundTone('auto')).assertFalse();
      expect(usesOwnHomeForegroundTone('default')).assertFalse();
    });

    it('selects_exactly_one_swatch_per_mode', 0, () => {
      const viewModel = new WallpaperSettingsViewModel();

      const auto = viewModel.buildState(snapshotWith(settingsWith('auto', 'mist')));
      expect(auto.modeTitle).assertEqual('自动黑白');
      expect(countSelected(auto.colorChoices)).assertEqual(1);
      expect(auto.colorChoices[0].isSelected).assertTrue();

      const solid = viewModel.buildState(snapshotWith(settingsWith('solid', 'blush')));
      expect(solid.modeTitle).assertEqual('浅粉');
      expect(countSelected(solid.colorChoices)).assertEqual(1);
      let selectedSolidId = '';
      for (let index = 0; index < solid.colorChoices.length; index += 1) {
        if (solid.colorChoices[index].isSelected) {
          selectedSolidId = solid.colorChoices[index].id;
        }
      }
      expect(selectedSolidId).assertEqual('blush');

      const theme = viewModel.buildState(snapshotWith(settingsWith('theme', 'mist')));
      expect(theme.modeTitle).assertEqual('跟随主题色');
      const last = theme.colorChoices[theme.colorChoices.length - 1];
      expect(last.isSelected).assertTrue();
      expect(last.kind).assertEqual('theme');
      expect(countSelected(theme.colorChoices)).assertEqual(1);
    });

    it('paints_the_chosen_color_with_its_own_text_tone', 0, () => {
      const service = new WallpaperPresentationService();

      const auto = service.buildPresentationState(snapshotWith(settingsWith('auto', 'mist')));
      expect(auto.kind).assertEqual('auto');
      expect(auto.mode).assertEqual('auto');
      expect(auto.solidColor).assertEqual('');
      expect(auto.imagePath).assertEqual('');
      expect(auto.videoPath).assertEqual('');
      expect(auto.maskOpacity).assertEqual(0);

      const sage = service.buildPresentationState(snapshotWith(settingsWith('solid', 'sage')));
      expect(sage.kind).assertEqual('solid');
      expect(sage.solidColor).assertEqual('#E6EFE7');
      expect(sage.foregroundTone).assertEqual('darkText');

      const theme = service.buildPresentationState(snapshotWith(settingsWith('theme', 'sage')));
      expect(theme.kind).assertEqual('default');
      expect(theme.solidColor).assertEqual('');
    });

    it('plays_a_custom_video_without_a_new_sync_mode', 0, () => {
      const service = new WallpaperPresentationService();
      const viewModel = new WallpaperSettingsViewModel();
      const settings = settingsWith('custom', 'mist');
      settings.customWallpaperId = 'custom-home';
      const snapshot: WallpaperRepositorySnapshot = {
        settings: settings,
        assets: [videoAsset()]
      };

      const state = service.buildPresentationState(snapshot);
      expect(state.kind).assertEqual('video');
      expect(state.mode).assertEqual('custom');
      expect(state.videoPath).assertEqual('file://video.mp4');
      expect(state.imagePath).assertEqual('file://poster.jpg');
      expect(state.foregroundTone).assertEqual('lightText');
      expect(state.maskOpacity).assertEqual(HOME_IMAGE_WALLPAPER_MASK_OPACITY);

      const view = viewModel.buildState(snapshot);
      expect(view.modeTitle).assertEqual('视频壁纸');
      expect(view.imageOptions.length).assertEqual(3);
      expect(view.imageOptions[1].id).assertEqual('custom');
      expect(view.imageOptions[1].isSelected).assertFalse();
      expect(view.imageOptions[2].id).assertEqual('video');
      expect(view.imageOptions[2].isSelected).assertTrue();
      expect(view.imageOptions[2].previewPath).assertEqual('file://poster.jpg');
    });
  });
}

function videoAsset(): WallpaperAsset {
  return {
    id: 'custom-home',
    source: 'custom',
    mediaType: 'video',
    originalPath: 'file://video.mp4',
    displayPath: 'file://video.mp4',
    thumbPath: 'file://poster.jpg',
    contentSignature: 'custom-1',
    foregroundTone: 'lightText',
    foregroundToneContentSignature: 'custom-1',
    foregroundToneCropSignature: 'crop',
    foregroundToneSampleSignature: 'sample',
    foregroundToneAlgorithmVersion: 4,
    width: 720,
    height: 1280,
    mimeType: 'video/mp4',
    byteSize: 1000,
    title: '视频壁纸',
    attribution: '',
    createdAt: 1,
    updatedAt: 2,
    isFavorite: false
  };
}
