import { describe, expect, it } from '@ohos/hypium';
import { normalizeBrowserHomePageStyle } from '../main/ets/common/models/HomePagePresentationSettingsModels';
import {
  applyCenteredHomeShortcutLayout,
  centeredHomeSearchCenterOffset,
  centeredHomeHeaderBlockHeight,
  CENTERED_HOME_ICON_CORNER_RADIUS_RATIO,
  CENTERED_HOME_LARGE_SCREEN_SEARCH_MAX_WIDTH,
  CENTERED_HOME_SEARCH_CENTER_LIFT_VP,
  resolveCenteredHomeFrame,
  resolveCenteredHomeSearchFieldWidth,
  resolveMeasuredCenteredSurfaceHeight,
  shouldCenterCenteredHomePartialRows
} from '../main/ets/features/newtab/CenteredHomeShortcutLayoutPolicy';
import { HomeResponsiveLayoutState } from '../main/ets/features/newtab/HomeResponsiveLayoutViewModel';

function classicLayout(): HomeResponsiveLayoutState {
  return {
    widthBreakpoint: 'sm',
    aspectBreakpoint: 'regular',
    centerContentVertically: false,
    useSharedSectionWidth: false,
    shortcutGridTopInset: 18,
    shortcutGridWidth: 360,
    recentlyClosedColumns: 1,
    recentlyClosedColumnGap: 8,
    recentlyClosedRowGap: 8,
    contentHorizontalPadding: 8,
    contentTopPadding: 12,
    bottomSpacerExtra: 0,
    sectionVerticalGap: 14,
    shortcutMetrics: {
      columns: 5,
      rowGap: 16,
      columnGap: 6,
      targetTileSize: 52,
      minimumTileSize: 44,
      fallbackColumnWidth: 72,
      titleTopGap: 4,
      titleBlockHeight: 18
    }
  };
}

export default function centeredHomeShortcutLayoutPolicyTest(): void {
  describe('CenteredHomeShortcutLayoutPolicy', () => {
    it('keeps unknown homepage styles on the classic frame', 0, () => {
      expect(normalizeBrowserHomePageStyle(undefined)).assertEqual('classic');
      expect(normalizeBrowserHomePageStyle('')).assertEqual('classic');
      expect(normalizeBrowserHomePageStyle('split')).assertEqual('classic');
      expect(normalizeBrowserHomePageStyle('centered')).assertEqual('centered');
      expect(normalizeBrowserHomePageStyle('minimal')).assertEqual('minimal');
    });

    it('shrinks the same shortcut grid without rewriting its column count', 0, () => {
      const source = classicLayout();
      const centered = applyCenteredHomeShortcutLayout(source);
      expect(centered.shortcutMetrics.columns).assertEqual(source.shortcutMetrics.columns);
      expect(centered.shortcutMetrics.targetTileSize < source.shortcutMetrics.targetTileSize).assertTrue();
      expect(centered.shortcutMetrics.targetTileSize >= 40).assertTrue();
      expect(centered.shortcutMetrics.columnGap >= source.shortcutMetrics.columnGap).assertTrue();
      expect(centered.contentTopPadding).assertEqual(source.contentTopPadding);
      expect(centered.recentlyClosedColumns).assertEqual(source.recentlyClosedColumns);
      expect(CENTERED_HOME_ICON_CORNER_RADIUS_RATIO).assertEqual(0.5);
    });

    it('pins the search field slightly above the vertical center of the screen', 0, () => {
      const frame = resolveCenteredHomeFrame({
        viewportHeight: 844,
        topSafeInset: 47,
        bottomChromeReserve: 112
      });
      expect(frame.headerTop + centeredHomeSearchCenterOffset())
        .assertEqual(422 - CENTERED_HOME_SEARCH_CENTER_LIFT_VP);
      expect(CENTERED_HOME_SEARCH_CENTER_LIFT_VP > 0).assertTrue();
      expect(frame.headerTop > 47).assertTrue();
      expect(frame.iconRegionHeight > 0).assertTrue();
    });

    it('does not let a stale surface height push the icon region off the window', 0, () => {
      expect(resolveMeasuredCenteredSurfaceHeight(0, 844)).assertEqual(844);
      expect(resolveMeasuredCenteredSurfaceHeight(800, 844)).assertEqual(800);
      expect(resolveMeasuredCenteredSurfaceHeight(2400, 844)).assertEqual(844);
      expect(resolveMeasuredCenteredSurfaceHeight(Number.NaN, 844)).assertEqual(844);
      expect(resolveMeasuredCenteredSurfaceHeight(900, 0)).assertEqual(900);
    });

    it('packs an incomplete shortcut row from the leading edge in touch mode', 0, () => {
      expect(shouldCenterCenteredHomePartialRows(false)).assertFalse();
      expect(shouldCenterCenteredHomePartialRows(true)).assertTrue();
    });

    it('caps the centered search field on a large screen', 0, () => {
      expect(resolveCenteredHomeSearchFieldWidth(false, 900)).assertEqual(900);
      expect(resolveCenteredHomeSearchFieldWidth(true, 900))
        .assertEqual(CENTERED_HOME_LARGE_SCREEN_SEARCH_MAX_WIDTH);
      expect(resolveCenteredHomeSearchFieldWidth(true, 400)).assertEqual(400);
      expect(resolveCenteredHomeSearchFieldWidth(true, -20)).assertEqual(0);
    });

    it('keeps the fixed header below the status bar on a short screen', 0, () => {
      const frame = resolveCenteredHomeFrame({
        viewportHeight: 240,
        topSafeInset: 40,
        bottomChromeReserve: 80
      });
      expect(frame.headerTop >= 40).assertTrue();
      expect(frame.iconRegionHeight >= 0).assertTrue();
    });

    // The logo size slider grows the header block, so the frame has to reserve the taller mark
    // or the pinned search field would drift off the vertical center.
    it('reserves_the_user_logo_height_in_the_header_block', 0, () => {
      const shipped = centeredHomeHeaderBlockHeight();
      const taller = centeredHomeHeaderBlockHeight(106);
      expect(taller).assertEqual(shipped + 53);
      expect(centeredHomeSearchCenterOffset(106)).assertEqual(centeredHomeSearchCenterOffset() + 53);

      const input = {
        viewportHeight: 800,
        topSafeInset: 40,
        bottomChromeReserve: 80
      };
      const shippedFrame = resolveCenteredHomeFrame(input);
      const tallerFrame = resolveCenteredHomeFrame({
        viewportHeight: 800,
        topSafeInset: 40,
        bottomChromeReserve: 80,
        logoHeightVp: 106
      });
      // A taller mark starts the header higher so the search field stays where it was.
      expect(tallerFrame.headerTop < shippedFrame.headerTop).assertTrue();
      expect(shippedFrame.headerTop - tallerFrame.headerTop).assertEqual(53);
      expect(shippedFrame.headerTop + centeredHomeSearchCenterOffset())
        .assertEqual(tallerFrame.headerTop + centeredHomeSearchCenterOffset(106));
      // An invalid height falls back to the shipped one instead of collapsing the header.
      expect(resolveCenteredHomeFrame({
        viewportHeight: 800,
        topSafeInset: 40,
        bottomChromeReserve: 80,
        logoHeightVp: 0
      }).headerTop).assertEqual(shippedFrame.headerTop);
    });
  });
}
