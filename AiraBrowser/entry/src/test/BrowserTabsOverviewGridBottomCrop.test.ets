import { describe, expect, it } from '@ohos/hypium';
import { BrowserTabsOverviewLayoutViewModel } from '../main/ets/core/browser/BrowserTabsOverviewLayoutViewModel';
import {
  BrowserTabsOverlayViewModel,
  BrowserTabsSharedSnapshotInput
} from '../main/ets/core/browser/BrowserTabsOverlayViewModel';
import { BrowserTabsOverviewStyleEntryPolicy } from '../main/ets/core/browser/tabsOverview/BrowserTabsOverviewStyleEntryPolicy';
import { BROWSER_TABS_OVERVIEW_GRID_BOTTOM_CROP_FRACTION } from '../main/ets/core/browser/BrowserTabsOverviewVisualTokens';

const SOURCE_WIDTH: number = 400;
const SOURCE_HEIGHT: number = 800;
const TARGET_LEFT: number = 16;
const TARGET_TOP: number = 80;
const TARGET_WIDTH: number = 180;
const TARGET_HEIGHT: number = 240;

function close(actual: number, expected: number, tolerance: number = 0.05): void {
  expect(Math.abs(actual - expected) <= tolerance).assertTrue();
}

function cropInput(progress: number, direction: 'enter' | 'exit' = 'enter',
  fraction: number = BROWSER_TABS_OVERVIEW_GRID_BOTTOM_CROP_FRACTION): BrowserTabsSharedSnapshotInput {
  return {
    direction: direction,
    progress: progress,
    sourceRect: { left: 0, top: 0, width: SOURCE_WIDTH, height: SOURCE_HEIGHT },
    targetRect: { left: TARGET_LEFT, top: TARGET_TOP, width: TARGET_WIDTH, height: TARGET_HEIGHT },
    sourceImageTopInset: 0,
    previewCornerRadius: 26,
    useFullWebSnapshot: true,
    imageWidth: SOURCE_WIDTH,
    imageHeight: SOURCE_HEIGHT,
    bottomCropFraction: fraction
  };
}

export default function browserTabsOverviewGridBottomCropTest(): void {
  describe('BrowserTabsOverviewGridBottomCrop', () => {
    it('keeps the bottom-third crop on the tiled grid only', 0, () => {
      const policy = new BrowserTabsOverviewStyleEntryPolicy();
      expect(policy.resolve('grid').bottomCropFraction)
        .assertEqual(BROWSER_TABS_OVERVIEW_GRID_BOTTOM_CROP_FRACTION);
      expect(policy.resolve(undefined).bottomCropFraction)
        .assertEqual(BROWSER_TABS_OVERVIEW_GRID_BOTTOM_CROP_FRACTION);
      expect(policy.resolve('horizontal_cards').bottomCropFraction).assertEqual(0);
      expect(policy.resolve('stack').bottomCropFraction).assertEqual(0);
      expect(policy.resolve('list').bottomCropFraction).assertEqual(0);
    });

    it('sizes a tiled card to the page with the bottom third removed', 0, () => {
      const state = new BrowserTabsOverviewLayoutViewModel().buildState({
        gridWidth: 360,
        sheetWidth: 392,
        sheetHeight: 800,
        layoutStyle: 'grid'
      });
      const visible = 1 - BROWSER_TABS_OVERVIEW_GRID_BOTTOM_CROP_FRACTION;
      const expected = Math.max(118, Math.round(state.cardWidth * 800 / 392 * visible));
      expect(state.layoutStyle).assertEqual('grid');
      expect(state.previewHeight).assertEqual(expected);
      expect(state.previewHeight < Math.round(state.cardWidth * 800 / 392)).assertTrue();
    });

    it('does not shorten the large centred card', 0, () => {
      const strip = new BrowserTabsOverviewLayoutViewModel().buildState({
        gridWidth: 360,
        sheetWidth: 392,
        sheetHeight: 800,
        layoutStyle: 'horizontal_cards'
      });
      const pageAspect = 800 / 392;
      close(strip.previewHeight / strip.cardWidth, pageAspect, 0.02);
    });

    it('crops the bottom during the flight and lands on the shorter card', 0, () => {
      const model = new BrowserTabsOverlayViewModel();
      const start = model.buildSharedSnapshotVisualState(cropInput(0));
      close(start.frame.width, SOURCE_WIDTH);
      close(start.frame.height, SOURCE_HEIGHT);
      close(start.frame.left, 0);
      close(start.imageFrame.top, 0);

      const cropped = model.buildSharedSnapshotVisualState(cropInput(0.42));
      close(cropped.frame.left, TARGET_LEFT * 0.36);
      close(cropped.frame.top, TARGET_TOP * 0.36);
      const croppedWidth = SOURCE_WIDTH + (TARGET_WIDTH - SOURCE_WIDTH) * 0.36;
      close(cropped.frame.width, croppedWidth);
      close(cropped.frame.height, croppedWidth * (SOURCE_HEIGHT / SOURCE_WIDTH) * (2 / 3));
      expect(cropped.imageFrame.height > cropped.frame.height).assertTrue();
      close(cropped.imageFrame.top, 0);
      close(cropped.imageFrame.width, cropped.frame.width);

      const landed = model.buildSharedSnapshotVisualState(cropInput(1));
      close(landed.frame.left, TARGET_LEFT);
      close(landed.frame.top, TARGET_TOP);
      close(landed.frame.width, TARGET_WIDTH);
      close(landed.frame.height, TARGET_HEIGHT);
      close(landed.imageFrame.top, 0);
      expect(landed.imageFrame.height > landed.frame.height).assertTrue();
    });

    it('plays the crop backwards when returning to the page', 0, () => {
      const model = new BrowserTabsOverlayViewModel();
      const leaving = model.buildSharedSnapshotVisualState(cropInput(0, 'exit'));
      close(leaving.frame.left, TARGET_LEFT);
      close(leaving.frame.width, TARGET_WIDTH);
      close(leaving.frame.height, TARGET_HEIGHT);
      const back = model.buildSharedSnapshotVisualState(cropInput(1, 'exit'));
      close(back.frame.left, 0);
      close(back.frame.width, SOURCE_WIDTH);
      close(back.frame.height, SOURCE_HEIGHT);
    });

    it('still scales other styles without cropping the bottom early', 0, () => {
      const mid = new BrowserTabsOverlayViewModel().buildSharedSnapshotVisualState(cropInput(0.5, 'enter', 0));
      close(mid.frame.height, (SOURCE_HEIGHT + TARGET_HEIGHT) / 2);
      close(mid.frame.left, TARGET_LEFT / 2);
    });
  });
}
