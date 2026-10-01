import { describe, expect, it } from '@ohos/hypium';
import {
  buildHomeLogoCustomAssetId,
  findHomeLogoCustomAsset,
  findHomeLogoPreset,
  HOME_LOGO_BUILTIN_ID,
  HOME_LOGO_CUSTOM_ASSET_ID_PREFIX,
  HomeLogoCustomAsset,
  HomeLogoPreset,
  HomeLogoSelection,
  homeLogoFollowsWallpaper,
  listHomeLogoPresets,
  normalizeHomeLogoSelection,
  resolveHomeLogoDisplaySource,
  resolveHomeLogoRowLabel,
  withoutHomeLogoCustomAsset
} from '../main/ets/common/models/HomeLogoModels';
import {
  buildHomeLogoGridRows,
  buildHomeLogoSettingsViewState,
  formatHomeLogoOpacityLabel,
  formatHomeLogoScaleLabel,
  HOME_LOGO_ADD_ITEM_ID,
  HOME_LOGO_OPACITY_DEFAULT,
  HOME_LOGO_SCALE_DEFAULT_RATIO,
  HOME_LOGO_SCALE_MAX_RATIO,
  HOME_LOGO_SCALE_MIN_RATIO,
  homeLogoOpacityToSliderValue,
  homeLogoScaleToSliderValue,
  homeLogoSliderValueToOpacity,
  homeLogoSliderValueToScale,
  normalizeHomeLogoOpacity,
  normalizeHomeLogoScaleRatio,
  resolveHomeLogoCornerRadiusVp,
  resolveHomeLogoDisplayWidthVp,
  resolveHomeLogoGridColumns,
  resolveHomeLogoHeightVp
} from '../main/ets/core/settings/HomeLogoSettingsPolicy';

function selectionWith(id: string, customUris: string[]): HomeLogoSelection {
  const customAssets: HomeLogoCustomAsset[] = [];
  for (let index = 0; index < customUris.length; index += 1) {
    const uri = customUris[index];
    customAssets.push({
      id: buildHomeLogoCustomAssetId(1000 + index),
      uri: uri,
      fileName: uri.substring(uri.lastIndexOf('/') + 1),
      width: 400,
      height: 120
    });
  }
  return { id: id, customAssets: customAssets };
}

function rowKeyContaining(id: string, containerWidth: number): string {
  const state = buildHomeLogoSettingsViewState(selectionWith(id, []), containerWidth);
  const rows = buildHomeLogoGridRows(state.items, state.columns);
  for (let index = 0; index < rows.length; index += 1) {
    const items = rows[index].items;
    for (let itemIndex = 0; itemIndex < items.length; itemIndex += 1) {
      if (items[itemIndex].id === id) {
        return rows[index].key;
      }
    }
  }
  return '';
}

export default function homeLogoSettingsPolicyTest(): void {
  describe('HomeLogoSettingsPolicy', () => {
    it('uses_two_columns_on_a_phone_and_more_when_wider', 0, () => {
      expect(resolveHomeLogoGridColumns(328)).assertEqual(2);
      expect(resolveHomeLogoGridColumns(439)).assertEqual(2);
      expect(resolveHomeLogoGridColumns(440)).assertEqual(3);
      expect(resolveHomeLogoGridColumns(679)).assertEqual(3);
      expect(resolveHomeLogoGridColumns(680)).assertEqual(4);
    });

    it('keeps_height_fixed_and_lets_width_follow_the_image', 0, () => {
      expect(Math.round(resolveHomeLogoDisplayWidthVp(546, 163, 53, 0))).assertEqual(177);
      expect(Math.round(resolveHomeLogoDisplayWidthVp(100, 200, 53, 0))).assertEqual(27);
      expect(resolveHomeLogoDisplayWidthVp(2000, 100, 53, 200)).assertEqual(200);
      expect(resolveHomeLogoDisplayWidthVp(0, 0, 53, 0)).assertEqual(53);
    });

    it('ends_the_grid_with_the_add_tile_and_no_custom_images', 0, () => {
      const state = buildHomeLogoSettingsViewState(selectionWith(HOME_LOGO_BUILTIN_ID, []), 328);
      expect(state.items.length).assertEqual(10);
      expect(state.items[0].kind).assertEqual('preset');
      expect(state.items[0].title).assertEqual('默认');
      expect(state.items[1].title).assertEqual('像素');
      expect(state.items[2].title).assertEqual('锋芒');
      expect(state.items[3].title).assertEqual('圆笔');
      expect(state.items[4].title).assertEqual('签名');
      expect(state.items[5].title).assertEqual('彩带');
      expect(state.items[6].title).assertEqual('父亲节');
      expect(state.items[7].title).assertEqual('世界杯');
      expect(state.items[8].title).assertEqual('德甲');
      expect(state.items[0].selected).assertTrue();
      expect(state.items[9].kind).assertEqual('add');
      expect(state.items[9].id).assertEqual(HOME_LOGO_ADD_ITEM_ID);
      expect(state.items[9].selected).assertFalse();
      // The add tile must not be selectable, so it never takes the accent border.
      expect(state.items[9].fileUri).assertEqual('');
      expect(state.items[9].rawfileName).assertEqual('');
    });

    it('appends_each_custom_image_before_the_add_tile', 0, () => {
      const first = selectionWith('builtin', ['file://a.png']);
      const withOne = buildHomeLogoSettingsViewState(first, 328);
      expect(withOne.items.length).assertEqual(11);
      expect(withOne.items[9].kind).assertEqual('custom');
      expect(withOne.items[9].fileUri).assertEqual('file://a.png');
      // The tile is labelled with the file the user picked.
      expect(withOne.items[9].title).assertEqual('a.png');
      expect(withOne.items[10].kind).assertEqual('add');

      const customId = first.customAssets[0].id;
      const second = selectionWith(customId, ['file://a.png', 'file://b.png']);
      const withTwo = buildHomeLogoSettingsViewState(second, 328);
      expect(withTwo.items.length).assertEqual(12);
      expect(withTwo.items[9].kind).assertEqual('custom');
      expect(withTwo.items[10].kind).assertEqual('custom');
      expect(withTwo.items[10].fileUri).assertEqual('file://b.png');
      expect(withTwo.items[11].kind).assertEqual('add');
      expect(withTwo.items[9].selected).assertTrue();
    });

    it('fills_the_last_grid_row_so_tiles_stay_equal', 0, () => {
      const state = buildHomeLogoSettingsViewState(selectionWith('preset-1', []), 500);
      expect(state.columns).assertEqual(3);
      expect(state.items[6].id).assertEqual('preset-1');
      expect(state.items[6].selected).assertTrue();
      const rows = buildHomeLogoGridRows(state.items, state.columns);
      expect(rows.length).assertEqual(4);
      expect(rows[0].items.length).assertEqual(3);
      expect(rows[3].items.length).assertEqual(1);
      expect(rows[3].placeholderCount).assertEqual(2);
    });

    // ForEach reuses a node whose key is unchanged, so the row key must move with the selection
    // or the blue selection border stays on the previously chosen tile.
    it('moves_the_row_key_when_the_selection_changes', 0, () => {
      const firstKey = rowKeyContaining('preset-1', 500);
      const secondKey = rowKeyContaining('preset-2', 500);
      expect(firstKey !== secondKey).assertTrue();

      // The same selection must keep a stable key so nothing rebuilds needlessly.
      expect(rowKeyContaining('preset-1', 500)).assertEqual(firstKey);
    });

    it('drops_a_custom_entry_that_has_no_file', 0, () => {
      const selection = normalizeHomeLogoSelection({
        id: 'custom-1000',
        customAssets: [
          { id: 'custom-1000', uri: '   ', fileName: 'x.png', width: 80, height: 40 },
          { id: '', uri: 'file://b.png', fileName: 'b.png', width: 10, height: 10 }
        ]
      });
      expect(selection.customAssets.length).assertEqual(0);
      // Nothing left to select, so the choice falls back to the shipped wordmark.
      expect(selection.id).assertEqual(HOME_LOGO_BUILTIN_ID);
      expect(resolveHomeLogoDisplaySource(selection).rawfileName).assertEqual('home_centered_wordmark.svg');
      expect(resolveHomeLogoRowLabel(selection)).assertEqual('默认');
    });

    it('falls_back_to_the_uri_name_when_no_name_was_stored', 0, () => {
      const selection = normalizeHomeLogoSelection({
        id: 'custom-1000',
        customAssets: [
          { id: 'custom-1000', uri: 'file://media/Photo/9/IMG_2024/IMG_20240101.jpg', fileName: '', width: 10, height: 10 }
        ]
      });
      expect(selection.customAssets[0].fileName).assertEqual('IMG_20240101.jpg');
    });

    it('selects_a_custom_image_and_labels_it', 0, () => {
      const selection = selectionWith('custom-1000', ['file://a.png', 'file://b.png']);
      expect(findHomeLogoCustomAsset(selection.customAssets, 'custom-1000')?.uri).assertEqual('file://a.png');
      const source = resolveHomeLogoDisplaySource(selection);
      expect(source.fileUri).assertEqual('file://a.png');
      expect(source.colorMode).assertEqual('authored');
      expect(resolveHomeLogoRowLabel(selection)).assertEqual('自定义');
    });

    it('offers_the_shipped_app_icons_as_rounded_presets', 0, () => {
      const classic = findHomeLogoPreset('icon-classic');
      const night = findHomeLogoPreset('icon-night');
      const blue = findHomeLogoPreset('icon-blue');
      const color = findHomeLogoPreset('icon-color');
      const texture = findHomeLogoPreset('icon-texture');
      expect(classic !== undefined).assertTrue();
      expect(night !== undefined).assertTrue();
      expect(blue !== undefined).assertTrue();
      expect(color !== undefined).assertTrue();
      expect(texture !== undefined).assertTrue();
      expect(classic?.title).assertEqual('经典');
      expect(night?.title).assertEqual('夜色');
      expect(blue?.title).assertEqual('海蓝');
      expect(color?.title).assertEqual('缤纷');
      expect(texture?.title).assertEqual('磨砂');
      expect(classic?.shape).assertEqual('icon');
      expect(texture?.shape).assertEqual('icon');
      expect(classic?.colorMode).assertEqual('authored');
      expect(blue?.rawfileName).assertEqual('home_logo_icon_blue.png');
      expect(color?.rawfileName).assertEqual('home_logo_icon_color.png');
      expect(texture?.rawfileName).assertEqual('home_logo_icon_texture.png');
      const presets = listHomeLogoPresets();
      expect(presets[1].id).assertEqual('icon-classic');
      expect(presets[2].id).assertEqual('icon-night');
      expect(presets[3].id).assertEqual('icon-blue');
      expect(presets[4].id).assertEqual('icon-color');
      expect(presets[5].id).assertEqual('icon-texture');
      expect(resolveHomeLogoDisplaySource({ id: 'icon-classic', customAssets: [] }).shape).assertEqual('icon');
      expect(resolveHomeLogoCornerRadiusVp(40, 'icon')).assertEqual(9);
      expect(resolveHomeLogoCornerRadiusVp(40, 'wordmark')).assertEqual(0);
    });

    it('removes_an_imported_logo_and_falls_back_when_it_was_selected', 0, () => {
      const selection = selectionWith('custom-1000', ['file://a.png', 'file://b.png']);
      const removed = withoutHomeLogoCustomAsset(selection, 'custom-1000');
      expect(removed !== undefined).assertTrue();
      expect(removed?.id).assertEqual(HOME_LOGO_BUILTIN_ID);
      expect(removed?.customAssets.length).assertEqual(1);
      expect(removed?.customAssets[0].uri).assertEqual('file://b.png');
      const kept = withoutHomeLogoCustomAsset(selection, 'custom-1001');
      expect(kept?.id).assertEqual('custom-1000');
      expect(kept?.customAssets.length).assertEqual(1);
      expect(withoutHomeLogoCustomAsset(selection, 'icon-classic') === undefined).assertTrue();
    });

    it('follows_the_wallpaper_only_for_single_color_masks', 0, () => {
      const presets = listHomeLogoPresets();
      const seenIds: string[] = [];
      for (let index = 0; index < presets.length; index += 1) {
        const preset: HomeLogoPreset = presets[index];
        expect(seenIds.indexOf(preset.id)).assertEqual(-1);
        seenIds.push(preset.id);
        expect(preset.id.indexOf(HOME_LOGO_CUSTOM_ASSET_ID_PREFIX)).assertEqual(-1);
        const followsWallpaper = homeLogoFollowsWallpaper(preset.colorMode);
        if (followsWallpaper) {
          expect(preset.rawfileName.endsWith('.svg')).assertTrue();
        }
        expect(resolveHomeLogoDisplaySource({ id: preset.id, customAssets: [] }).colorMode)
          .assertEqual(preset.colorMode);
      }
      expect(homeLogoFollowsWallpaper(resolveHomeLogoDisplaySource({
        id: 'preset-pixel', customAssets: []
      }).colorMode)).assertTrue();
      expect(homeLogoFollowsWallpaper(resolveHomeLogoDisplaySource({
        id: 'preset-sharp', customAssets: []
      }).colorMode)).assertTrue();
      expect(homeLogoFollowsWallpaper(resolveHomeLogoDisplaySource({
        id: 'preset-round', customAssets: []
      }).colorMode)).assertTrue();
      expect(homeLogoFollowsWallpaper(resolveHomeLogoDisplaySource({
        id: 'preset-script', customAssets: []
      }).colorMode)).assertTrue();
      // Full-color art stays authored even though this one is also an SVG.
      expect(resolveHomeLogoDisplaySource({ id: 'preset-confetti', customAssets: [] }).colorMode)
        .assertEqual('authored');
      expect(resolveHomeLogoDisplaySource({ id: 'preset-1', customAssets: [] }).colorMode)
        .assertEqual('authored');
      expect(resolveHomeLogoRowLabel({ id: 'preset-1', customAssets: [] })).assertEqual('父亲节');
    });
    it('clamps_the_size_slider_to_its_range', 0, () => {
      expect(HOME_LOGO_SCALE_DEFAULT_RATIO).assertEqual(1);
      expect(normalizeHomeLogoScaleRatio(1.25)).assertEqual(1.25);
      // Below the floor and above the cap both snap back inside the range.
      expect(normalizeHomeLogoScaleRatio(0.1)).assertEqual(HOME_LOGO_SCALE_MIN_RATIO);
      expect(normalizeHomeLogoScaleRatio(9)).assertEqual(HOME_LOGO_SCALE_MAX_RATIO);
      expect(normalizeHomeLogoScaleRatio(undefined)).assertEqual(HOME_LOGO_SCALE_DEFAULT_RATIO);
      expect(normalizeHomeLogoScaleRatio(Number.NaN)).assertEqual(HOME_LOGO_SCALE_DEFAULT_RATIO);
    });

    it('round_trips_between_ratio_and_slider_percent', 0, () => {
      expect(homeLogoScaleToSliderValue(1)).assertEqual(100);
      expect(homeLogoScaleToSliderValue(1.4)).assertEqual(140);
      expect(homeLogoSliderValueToScale(150)).assertEqual(1.5);
      expect(homeLogoSliderValueToScale(500)).assertEqual(HOME_LOGO_SCALE_MAX_RATIO);
      expect(formatHomeLogoScaleLabel(1.2)).assertEqual('120%');
    });

    it('lets_opacity_reach_zero_and_clamps_the_rest', 0, () => {
      expect(HOME_LOGO_OPACITY_DEFAULT).assertEqual(1);
      expect(normalizeHomeLogoOpacity(0)).assertEqual(0);
      expect(normalizeHomeLogoOpacity(0.35)).assertEqual(0.35);
      expect(normalizeHomeLogoOpacity(-1)).assertEqual(0);
      expect(normalizeHomeLogoOpacity(2)).assertEqual(1);
      expect(normalizeHomeLogoOpacity(undefined)).assertEqual(1);
      expect(normalizeHomeLogoOpacity(Number.NaN)).assertEqual(1);
      expect(homeLogoOpacityToSliderValue(0)).assertEqual(0);
      expect(homeLogoSliderValueToOpacity(0)).assertEqual(0);
      expect(homeLogoSliderValueToOpacity(40)).assertEqual(0.4);
      expect(formatHomeLogoOpacityLabel(0)).assertEqual('0%');
    });

    it('scales_the_wordmark_height_and_never_passes_the_cap', 0, () => {
      // The shipped wordmark is 53vp, so 100% is exactly the current size.
      expect(resolveHomeLogoHeightVp(53, 1)).assertEqual(53);
      expect(resolveHomeLogoHeightVp(53, 2)).assertEqual(106);
      expect(resolveHomeLogoHeightVp(53, 0.6)).assertEqual(Math.round(53 * 0.6));
      // A ratio past the cap is clamped instead of growing without limit.
      expect(resolveHomeLogoHeightVp(53, 8)).assertEqual(106);
      expect(resolveHomeLogoHeightVp(53, 0)).assertEqual(HOME_LOGO_SCALE_DEFAULT_RATIO * 53);
    });
  });
}
