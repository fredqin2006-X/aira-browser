import { HomeContentSectionsPresentationState } from '../../core/browser/HomeContentPresentationState';
import { HomeShortcutViewModel } from './HomeShortcutViewModel';

const HOME_SECTION_CONTENT_INSET: number = 10;

/**
 * Width of the favorites block for one frame. Callers pass that frame's own view model.
 * A frame must not read another frame's measured width.
 */
export function resolveHomeFavoritesSectionWidth(
  presentation: HomeContentSectionsPresentationState,
  viewModel: HomeShortcutViewModel
): number {
  const shortcuts = presentation.shortcuts;
  const itemCount = shortcuts.shortcuts.length + (shortcuts.showAddEntry ? 1 : 0);
  const gridWidth = Math.max(1, shortcuts.gridWidth);
  const occupiedContentWidth = viewModel.getOccupiedGridContentWidth(
    itemCount,
    gridWidth,
    HOME_SECTION_CONTENT_INSET,
    shortcuts.metrics
  );
  return Math.min(gridWidth, occupiedContentWidth + HOME_SECTION_CONTENT_INSET * 2);
}

export function resolveHomeSectionRailWidth(
  presentation: HomeContentSectionsPresentationState,
  viewModel: HomeShortcutViewModel
): number {
  const favoritesWidth = resolveHomeFavoritesSectionWidth(presentation, viewModel);
  if (!presentation.useSharedSectionWidth) {
    return favoritesWidth;
  }
  return Math.max(1, presentation.shortcuts.gridWidth);
}

export function resolveHomeFullGridWidth(presentation: HomeContentSectionsPresentationState): number {
  return Math.max(1, presentation.shortcuts.gridWidth);
}
