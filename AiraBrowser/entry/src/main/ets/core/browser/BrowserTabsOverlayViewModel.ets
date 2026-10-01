import { image } from '@kit.ImageKit';
import { BrowserTabPreviewState } from './BrowserTabPreviewCoordinator';
import { BrowserTabState } from '../tabs/TabManager';
import {
  BROWSER_TAB_PREVIEW_PIXEL_HEIGHT,
  BROWSER_TAB_PREVIEW_PIXEL_WIDTH
} from './BrowserTabPreviewMetrics';
import { BROWSER_TABS_OVERVIEW_GRID_TOP_CROP_FRACTION } from './BrowserTabsOverviewVisualTokens';
import {
  BrowserTabsOverviewSection,
  BrowserTabsOverviewSectionPolicy
} from './tabsOverview/BrowserTabsOverviewSectionPolicy';
import { SiteIdentityService } from '../../services/web/SiteIdentityService';
import { resolveSiteIconFallbackLabel } from '../../common/utils/SiteIconFallbackUtils';
import {
  SiteIconListPresenter,
  SiteIconListRenderState,
  SiteIconListResolvedIcon,
  SiteIconListTarget
} from '../siteicons/SiteIconListPresenter';

export type BrowserTabOverviewPreviewKind = 'snapshot' | 'home' | 'pending';

export interface BrowserTabOverviewCardPresentation {
  previewKind: BrowserTabOverviewPreviewKind;
  shouldBlurSnapshot: boolean;
  sharedSnapshotImageUri: string;
  sharedSnapshotPixelMap?: image.PixelMap;
  sharedSnapshotImageWidth: number;
  sharedSnapshotImageHeight: number;
}

export interface BrowserTabOverviewIdentityPresentation {
  label: string;
  iconUri: string;
  iconPixelMap?: image.PixelMap;
  fallbackLabel: string;
  fallbackAiraIconId?: 'browser.shortcut.home';
  sourceRevision: number;
}

export interface BrowserTabOverviewItemPresentation {
  identity: BrowserTabOverviewIdentityPresentation;
  preview: BrowserTabOverviewCardPresentation;
}

export interface BrowserTabsOverviewIdentityIconSnapshot {
  tabs: BrowserTabState[];
  section: BrowserTabsOverviewSection;
  iconStates: SiteIconListRenderState[];
}

export type BrowserTabsOverviewIdentityIconSnapshotProvider =
  () => BrowserTabsOverviewIdentityIconSnapshot;
export type BrowserTabsOverviewIdentityIconStatesChangedHandler =
  (states: SiteIconListRenderState[]) => void;

export type BrowserTabsSharedSnapshotDirection = 'enter' | 'exit';

export interface BrowserTabsOverlayRect {
  left: number;
  top: number;
  width: number;
  height: number;
}

export interface BrowserTabsOverlayPredictedPreviewRectInput {
  tabIds: string[];
  tabId: string;
  gridWidth: number;
  fallbackSheetWidth: number;
  viewportHeight?: number;
  horizontalPadding: number;
  columnCount: number;
  gridGap: number;
  topPadding: number;
  headerHeight: number;
  headerContentGap: number;
  identityHeaderHeight: number;
  identityPreviewGap: number;
  previewHeight: number;
}

export interface BrowserTabsSharedSnapshotInput {
  direction: BrowserTabsSharedSnapshotDirection;
  progress: number;
  sourceRect: BrowserTabsOverlayRect;
  targetRect: BrowserTabsOverlayRect;
  targetPreviewHeight?: number;
  sourceImageTopInset: number;
  previewCornerRadius: number;
  useFullWebSnapshot: boolean;
  imageWidth: number;
  imageHeight: number;
  /** Omitted, or true, grows the radius with the morph; false keeps the final radius throughout. */
  cornerRadiusFollowsProgress?: boolean;
  /**
   * List rows are a clip window, not a scaled card. The page picture stays on the full-screen
   * pixels it already occupies; only the frame moves, shrinks and rounds.
   */
  pinImageToSource?: boolean;
  /**
   * 卡片平铺专用。大于 0 时，容器在飞行前半段从底部裁掉这么多，再落入卡片。
   * 图片保持页面比例、顶边对齐，不压扁。
   */
  bottomCropFraction?: number;
}

export interface BrowserTabsSharedSnapshotVisualState {
  frame: BrowserTabsOverlayRect;
  imageFrame: BrowserTabsOverlayRect;
  cornerRadius: number;
}

/**
 * 裁切在行程走到 42% 之前完成，此时位置只走了 36%。之后裁完的容器再落入卡片。
 * 和演示的时间结构一致，只是去掉了开头那一拍停顿。
 */
const GRID_BOTTOM_CROP_DONE_AT: number = 0.42;
const GRID_BOTTOM_CROP_MOVE_AT_DONE: number = 0.36;

interface BrowserTabsGridBottomCropMotion {
  moveT: number;
  cropT: number;
}

export class BrowserTabsOverlayViewModel {
  private sectionPolicy: BrowserTabsOverviewSectionPolicy = new BrowserTabsOverviewSectionPolicy();
  private siteIdentityService: SiteIdentityService = new SiteIdentityService();
  private siteIconListPresenter: SiteIconListPresenter = new SiteIconListPresenter();

  buildItemPresentation(
    tab: BrowserTabState,
    previewState?: BrowserTabPreviewState,
    cachedIconState?: SiteIconListRenderState,
    blurPrivateTabPreviews: boolean = true
  ): BrowserTabOverviewItemPresentation {
    return {
      identity: this.buildIdentityPresentation(tab, previewState, cachedIconState),
      preview: this.buildCardPresentation(tab, previewState, blurPrivateTabPreviews)
    };
  }

  bindIdentityIconUpdates(
    provideSnapshot: BrowserTabsOverviewIdentityIconSnapshotProvider,
    onStatesChanged: BrowserTabsOverviewIdentityIconStatesChangedHandler
  ): void {
    this.siteIconListPresenter.bindDomainUpdates(
      (): SiteIconListTarget[] => this.buildIdentityIconTargets(provideSnapshot()),
      (result: SiteIconListResolvedIcon): void => {
        this.applyResolvedIdentityIcon(provideSnapshot, onStatesChanged, result);
      }
    );
  }

  syncIdentityIcons(
    provideSnapshot: BrowserTabsOverviewIdentityIconSnapshotProvider,
    onStatesChanged: BrowserTabsOverviewIdentityIconStatesChangedHandler
  ): void {
    const snapshot = provideSnapshot();
    const targets = this.buildIdentityIconTargets(snapshot);
    const retainedStates = snapshot.iconStates.filter((state: SiteIconListRenderState): boolean => {
      const target = targets.find((candidate: SiteIconListTarget): boolean => candidate.id === state.id);
      return target !== undefined && this.siteIconListPresenter.hasResolvedIcon([state], target);
    });
    onStatesChanged(retainedStates);
    this.siteIconListPresenter.resolveTargets(
      targets,
      (result: SiteIconListResolvedIcon): void => {
        this.applyResolvedIdentityIcon(provideSnapshot, onStatesChanged, result);
      },
      {
        resolutionPolicy: 'cacheOnly',
        shouldSkipTarget: (target: SiteIconListTarget): boolean =>
          this.siteIconListPresenter.hasResolvedIcon(retainedStates, target)
      }
    );
  }

  disposeIdentityIcons(): void {
    this.siteIconListPresenter.dispose();
  }

  resolveIdentityIconState(
    iconStates: SiteIconListRenderState[],
    tabId: string
  ): SiteIconListRenderState | undefined {
    return iconStates.find((state: SiteIconListRenderState): boolean => state.id === tabId);
  }

  buildCardPresentation(
    tab: BrowserTabState,
    previewState?: BrowserTabPreviewState,
    blurPrivateTabPreviews: boolean = true
  ): BrowserTabOverviewCardPresentation {
    return {
      previewKind: this.resolvePreviewKind(tab, previewState),
      shouldBlurSnapshot: this.shouldBlurSnapshot(tab, previewState, blurPrivateTabPreviews),
      sharedSnapshotImageUri: this.resolveSharedSnapshotImageUri(tab, previewState),
      sharedSnapshotPixelMap: this.resolveSharedSnapshotPixelMap(tab, previewState),
      sharedSnapshotImageWidth: this.resolveSharedSnapshotImageWidth(previewState),
      sharedSnapshotImageHeight: this.resolveSharedSnapshotImageHeight(previewState)
    };
  }

  buildPredictedPreviewRect(input: BrowserTabsOverlayPredictedPreviewRectInput): BrowserTabsOverlayRect | undefined {
    const index = input.tabIds.indexOf(input.tabId);
    if (index < 0) {
      return undefined;
    }
    const usableWidth = input.gridWidth > 0
      ? input.gridWidth
      : Math.max(1, input.fallbackSheetWidth - (input.horizontalPadding * 2));
    const columnCount = Math.max(1, Math.floor(input.columnCount));
    const totalGap = input.gridGap * Math.max(0, columnCount - 1);
    const cardWidth = Math.max(132, (usableWidth - totalGap) / columnCount);
    const row = Math.floor(index / columnCount);
    const column = index % columnCount;
    const previewHeight = Math.max(1, input.previewHeight);
    const identityTopInset = Math.max(0, input.identityHeaderHeight) +
      Math.max(0, input.identityPreviewGap);
    const itemHeight = identityTopInset + previewHeight;
    const rowHeight = itemHeight + input.gridGap;
    const rowCount = Math.max(1, Math.ceil(input.tabIds.length / columnCount));
    const contentHeight = input.topPadding + input.headerHeight + input.headerContentGap +
      (rowCount * itemHeight) + (Math.max(0, rowCount - 1) * input.gridGap);
    const bottomScrollOffset = input.viewportHeight === undefined
      ? 0
      : Math.max(0, contentHeight - Math.max(1, input.viewportHeight));
    return {
      left: input.horizontalPadding + (column * (cardWidth + input.gridGap)),
      top: input.topPadding + input.headerHeight + input.headerContentGap +
        identityTopInset + (row * rowHeight) - bottomScrollOffset,
      width: cardWidth,
      height: previewHeight
    };
  }

  buildSharedSnapshotVisualState(input: BrowserTabsSharedSnapshotInput): BrowserTabsSharedSnapshotVisualState {
    const progress = this.clampProgress(input.progress);
    if ((input.bottomCropFraction ?? 0) > 0 && input.pinImageToSource !== true) {
      return this.buildBottomCropVisualState(input, progress);
    }
    const sourceFrame = this.buildPositiveRect(input.sourceRect);
    const targetFrame = this.buildPositiveRect(input.targetRect);
    const startRect = input.direction === 'exit' ? targetFrame : sourceFrame;
    const endRect = input.direction === 'exit' ? sourceFrame : targetFrame;
    const sourceImageRect = input.useFullWebSnapshot
      ? this.buildFullWebSnapshotSourceImageRect(sourceFrame.width, sourceFrame.height,
        input.imageWidth, input.imageHeight, input.sourceImageTopInset)
      : this.buildCoverImageRect(sourceFrame.width, sourceFrame.height);
    const targetImageRect = input.useFullWebSnapshot
      ? this.buildSharedSnapshotPreviewImageRect(targetFrame.width, targetFrame.height,
        input.imageWidth, input.imageHeight)
      : this.buildCoverImageRect(targetFrame.width, targetFrame.height);
    const startImageRect = input.direction === 'exit' ? targetImageRect : sourceImageRect;
    const endImageRect = input.direction === 'exit' ? sourceImageRect : targetImageRect;

    const frame = this.interpolateRect(startRect, endRect, progress);
    const imageFrame = input.pinImageToSource === true ?
      this.buildPinnedSourceImageFrame(sourceFrame, sourceImageRect, frame) :
      this.resolveSharedSnapshotImageFrame(
        input,
        frame,
        this.interpolateRect(startImageRect, endImageRect, progress)
      );
    // A finger-driven morph is a card from its first frame, so it holds the radius it will settle
    // with. Anything else keeps the square-to-round growth that makes a page read as a page.
    const cornerRadius = input.cornerRadiusFollowsProgress === false ?
      input.previewCornerRadius :
      (input.direction === 'exit'
        ? this.lerp(input.previewCornerRadius, 0, progress)
        : this.lerp(0, input.previewCornerRadius, progress));
    return {
      frame: frame,
      imageFrame: imageFrame,
      cornerRadius: cornerRadius
    };
  }

  /**
   * 容器从整页大小飞向卡片。前半段同时裁掉底部 1/3 和顶部 1/9，再落入卡片。
   * 顶部那截是安全区或地址栏，留下的是中间的页面。退出时把这两头再放回来。
   */
  private buildBottomCropVisualState(
    input: BrowserTabsSharedSnapshotInput,
    progress: number
  ): BrowserTabsSharedSnapshotVisualState {
    const sourceFrame = this.buildPositiveRect(input.sourceRect);
    const targetFrame = this.buildPositiveRect(input.targetRect);
    const startRect = input.direction === 'exit' ? targetFrame : sourceFrame;
    const endRect = input.direction === 'exit' ? sourceFrame : targetFrame;
    const travel = input.direction === 'exit' ? 1 - progress : progress;
    const motion = this.resolveGridBottomCropMotion(travel);
    const moveParam = input.direction === 'exit' ? 1 - motion.moveT : motion.moveT;
    const width = this.lerp(startRect.width, endRect.width, moveParam);
    const pageAspect = sourceFrame.height / Math.max(1, sourceFrame.width);
    const imageAspect = Math.max(1, input.imageHeight) / Math.max(1, input.imageWidth);
    const endUncropped = Math.max(1, targetFrame.width * pageAspect);
    const endVisible = targetFrame.height / endUncropped;
    const visible = this.lerp(1, endVisible, motion.cropT);
    const frame: BrowserTabsOverlayRect = {
      left: this.lerp(startRect.left, endRect.left, moveParam),
      top: this.lerp(startRect.top, endRect.top, moveParam),
      width: width,
      height: Math.max(1, width * pageAspect * visible)
    };
    const sourceImageRect = input.useFullWebSnapshot
      ? this.buildFullWebSnapshotSourceImageRect(sourceFrame.width, sourceFrame.height,
        input.imageWidth, input.imageHeight, input.sourceImageTopInset)
      : this.buildCoverImageRect(sourceFrame.width, sourceFrame.height);
    // 图片宽度跟容器走，高度按截图自己的比例。裁切进度把图片上移，顶部 1/9 被容器切掉，底部由更矮的容器切掉。
    const imageHeight = width * imageAspect;
    const imageFrame: BrowserTabsOverlayRect = {
      left: 0,
      top: this.lerp(sourceImageRect.top, -imageHeight * BROWSER_TABS_OVERVIEW_GRID_TOP_CROP_FRACTION, motion.cropT),
      width: width,
      height: imageHeight
    };
    const cornerRadius = input.cornerRadiusFollowsProgress === false ?
      input.previewCornerRadius :
      (input.direction === 'exit' ?
        this.lerp(input.previewCornerRadius, 0, moveParam) :
        this.lerp(0, input.previewCornerRadius, moveParam));
    return {
      frame: frame,
      imageFrame: imageFrame,
      cornerRadius: cornerRadius
    };
  }

  private resolveGridBottomCropMotion(travel: number): BrowserTabsGridBottomCropMotion {
    const t = this.clampProgress(travel);
    if (t <= GRID_BOTTOM_CROP_DONE_AT) {
      const u = this.smoothStep(t / GRID_BOTTOM_CROP_DONE_AT);
      return {
        moveT: u * GRID_BOTTOM_CROP_MOVE_AT_DONE,
        cropT: u
      };
    }
    const u = this.smoothStep((t - GRID_BOTTOM_CROP_DONE_AT) / (1 - GRID_BOTTOM_CROP_DONE_AT));
    return {
      moveT: GRID_BOTTOM_CROP_MOVE_AT_DONE + u * (1 - GRID_BOTTOM_CROP_MOVE_AT_DONE),
      cropT: 1
    };
  }

  private smoothStep(value: number): number {
    const t = this.clampProgress(value);
    return t * t * (3 - 2 * t);
  }

  buildSharedSnapshotPreviewImageRect(
    containerWidth: number,
    containerHeight: number,
    imageWidth: number,
    imageHeight: number,
    _virtualTopInsetPixels: number = 0
  ): BrowserTabsOverlayRect {
    return this.buildAspectFillImageRect(containerWidth, containerHeight, imageWidth, imageHeight);
  }

  /**
   * 卡片平铺的预览图。整张按宽度等比画出，再上移 1/9，卡片框裁掉顶部地址栏和底部 1/3。
   */
  buildGridCroppedPreviewImageRect(
    containerWidth: number,
    containerHeight: number,
    imageWidth: number,
    imageHeight: number
  ): BrowserTabsOverlayRect {
    const filled = this.buildAspectFillImageRect(containerWidth, containerHeight, imageWidth, imageHeight);
    return {
      left: filled.left,
      top: filled.top - filled.height * BROWSER_TABS_OVERVIEW_GRID_TOP_CROP_FRACTION,
      width: filled.width,
      height: filled.height
    };
  }

  private buildIdentityPresentation(
    tab: BrowserTabState,
    previewState?: BrowserTabPreviewState,
    cachedIconState?: SiteIconListRenderState
  ): BrowserTabOverviewIdentityPresentation {
    const identityUrl = this.resolveIdentityUrl(tab);
    const label = this.resolveIdentityLabel(tab, identityUrl);
    if (tab.isHome) {
      return {
        label: label,
        iconUri: '',
        iconPixelMap: undefined,
        fallbackLabel: resolveSiteIconFallbackLabel(label, identityUrl),
        fallbackAiraIconId: 'browser.shortcut.home',
        sourceRevision: 0
      };
    }
    if (previewState?.favicon !== undefined) {
      return {
        label: label,
        // Keep the durable cached icon as a URI fallback. The favicon PixelMap
        // comes from the web engine and can be unrenderable by the time the card
        // grid paints (cold start), and a failed PixelMap with no URI falls all
        // the way through to the letter badge even though the site icon is on disk.
        iconUri: cachedIconState?.path ?? '',
        iconPixelMap: previewState.favicon,
        fallbackLabel: resolveSiteIconFallbackLabel(label, identityUrl),
        sourceRevision: Math.max(1, Math.floor(previewState.faviconRevision ?? 1))
      };
    }
    return {
      label: label,
      iconUri: cachedIconState?.path ?? '',
      iconPixelMap: cachedIconState?.pixelMap,
      fallbackLabel: resolveSiteIconFallbackLabel(label, identityUrl),
      sourceRevision: cachedIconState?.sourceRevision ?? 0
    };
  }

  private resolveIdentityLabel(tab: BrowserTabState, identityUrl: string): string {
    if (tab.isHome) {
      return '新标签页';
    }
    const title = tab.title.trim();
    if (title.length > 0) {
      return title;
    }
    const host = this.siteIdentityService.resolve(identityUrl).displayHost;
    return host.length > 0 ? host : '新标签页';
  }

  private resolveIdentityUrl(tab: BrowserTabState): string {
    const candidates: string[] = [
      tab.url,
      tab.pendingUrl,
      tab.lastRestorableUrl,
      tab.lastGoodUrl
    ];
    for (const candidate of candidates) {
      const normalized = candidate.trim();
      if (normalized.length > 0) {
        return normalized;
      }
    }
    return '';
  }

  private buildIdentityIconTargets(
    snapshot: BrowserTabsOverviewIdentityIconSnapshot
  ): SiteIconListTarget[] {
    return this.sectionPolicy.resolveTabsForSection(snapshot.tabs, snapshot.section)
      .filter((tab: BrowserTabState): boolean =>
        !tab.isHome && !this.sectionPolicy.isPrivateTab(tab) && this.resolveIdentityUrl(tab).length > 0)
      .map((tab: BrowserTabState): SiteIconListTarget => {
        return { id: tab.id, url: this.resolveIdentityUrl(tab) };
      });
  }

  private applyResolvedIdentityIcon(
    provideSnapshot: BrowserTabsOverviewIdentityIconSnapshotProvider,
    onStatesChanged: BrowserTabsOverviewIdentityIconStatesChangedHandler,
    result: SiteIconListResolvedIcon
  ): void {
    const snapshot = provideSnapshot();
    const target = this.buildIdentityIconTargets(snapshot)
      .find((candidate: SiteIconListTarget): boolean => candidate.id === result.id);
    if (target === undefined) {
      return;
    }
    const candidateState = this.siteIconListPresenter.applyResolvedIcon([], result);
    if (!this.siteIconListPresenter.hasResolvedIcon(candidateState, target)) {
      return;
    }
    onStatesChanged(this.siteIconListPresenter.applyResolvedIcon(snapshot.iconStates, result));
  }

  private resolvePreviewKind(
    tab: BrowserTabState,
    previewState?: BrowserTabPreviewState
  ): BrowserTabOverviewPreviewKind {
    if (tab.isHome) {
      return 'home';
    }
    if (this.hasRenderableSnapshot(previewState)) {
      return 'snapshot';
    }
    return 'pending';
  }

  private resolveSharedSnapshotImageUri(tab: BrowserTabState, previewState?: BrowserTabPreviewState): string {
    if (tab.isHome) {
      return '';
    }
    return previewState?.sharedSnapshotImageUri?.trim() ?? '';
  }

  private resolveSharedSnapshotPixelMap(
    tab: BrowserTabState,
    previewState?: BrowserTabPreviewState
  ): image.PixelMap | undefined {
    if (tab.isHome) {
      return undefined;
    }
    return previewState?.sharedSnapshotPixelMap;
  }

  private shouldBlurSnapshot(
    tab: BrowserTabState,
    previewState: BrowserTabPreviewState | undefined,
    blurPrivateTabPreviews: boolean
  ): boolean {
    if (!blurPrivateTabPreviews || !this.sectionPolicy.isPrivateTab(tab) || tab.isHome) {
      return false;
    }
    return this.hasRenderableSnapshot(previewState);
  }

  private hasRenderableSnapshot(previewState: BrowserTabPreviewState | undefined): boolean {
    return (previewState?.sharedSnapshotImageUri?.trim().length ?? 0) > 0 ||
      previewState?.sharedSnapshotPixelMap !== undefined;
  }

  private resolveSharedSnapshotImageWidth(previewState?: BrowserTabPreviewState): number {
    return Math.max(1, Math.floor(previewState?.sharedSnapshotImageWidth ?? BROWSER_TAB_PREVIEW_PIXEL_WIDTH));
  }

  private resolveSharedSnapshotImageHeight(previewState?: BrowserTabPreviewState): number {
    return Math.max(1, Math.floor(previewState?.sharedSnapshotImageHeight ?? BROWSER_TAB_PREVIEW_PIXEL_HEIGHT));
  }

  private buildCoverImageRect(containerWidth: number, containerHeight: number): BrowserTabsOverlayRect {
    const safeWidth = Math.max(1, containerWidth);
    const safeHeight = Math.max(1, containerHeight);
    const scale = Math.max(
      safeWidth / BROWSER_TAB_PREVIEW_PIXEL_WIDTH,
      safeHeight / BROWSER_TAB_PREVIEW_PIXEL_HEIGHT
    );
    const imageWidth = BROWSER_TAB_PREVIEW_PIXEL_WIDTH * scale;
    const imageHeight = BROWSER_TAB_PREVIEW_PIXEL_HEIGHT * scale;
    return {
      left: (safeWidth - imageWidth) / 2,
      top: (safeHeight - imageHeight) / 2,
      width: imageWidth,
      height: imageHeight
    };
  }

  private buildFullWebSnapshotSourceImageRect(
    containerWidth: number,
    containerHeight: number,
    imageWidth: number,
    imageHeight: number,
    sourceImageTopInset: number = 0
  ): BrowserTabsOverlayRect {
    const safeWidth = Math.max(1, containerWidth);
    const safeHeight = Math.max(1, containerHeight);
    const safeImageWidth = Math.max(1, imageWidth);
    const safeImageHeight = Math.max(1, imageHeight);
    const imageScale = Math.max(safeWidth / safeImageWidth, safeHeight / safeImageHeight);
    const renderedImageWidth = Math.max(1, safeImageWidth * imageScale);
    const renderedImageHeight = Math.max(1, safeImageHeight * imageScale);
    const minLeft = Math.min(0, safeWidth - renderedImageWidth);
    const minTop = Math.min(0, safeHeight - renderedImageHeight);
    const safeTopInset = Math.max(minTop, Math.min(0, Math.round(sourceImageTopInset)));
    return {
      left: Math.max(minLeft, Math.min(0, (safeWidth - renderedImageWidth) / 2)),
      top: safeTopInset,
      width: renderedImageWidth,
      height: renderedImageHeight
    };
  }

  /**
   * Keep the page picture on the screen pixels it had at full size. The moving frame is only a
   * clip, so its own motion is cancelled by the image offset.
   */
  private buildPinnedSourceImageFrame(
    sourceFrame: BrowserTabsOverlayRect,
    sourceImageRect: BrowserTabsOverlayRect,
    frame: BrowserTabsOverlayRect
  ): BrowserTabsOverlayRect {
    return {
      left: sourceFrame.left + sourceImageRect.left - frame.left,
      top: sourceFrame.top + sourceImageRect.top - frame.top,
      width: sourceImageRect.width,
      height: sourceImageRect.height
    };
  }

  private resolveSharedSnapshotImageFrame(
    input: BrowserTabsSharedSnapshotInput,
    frame: BrowserTabsOverlayRect,
    imageFrame: BrowserTabsOverlayRect
  ): BrowserTabsOverlayRect {
    if (!input.useFullWebSnapshot) {
      return imageFrame;
    }
    return this.expandImageRectToCoverFrame(imageFrame, frame);
  }

  private expandImageRectToCoverFrame(
    imageFrame: BrowserTabsOverlayRect,
    frame: BrowserTabsOverlayRect
  ): BrowserTabsOverlayRect {
    const frameWidth = Math.max(1, frame.width);
    const frameHeight = Math.max(1, frame.height);
    const imageWidth = Math.max(1, imageFrame.width);
    const imageHeight = Math.max(1, imageFrame.height);
    const scale = Math.max(1, frameWidth / imageWidth, frameHeight / imageHeight);
    const width = imageWidth * scale;
    const height = imageHeight * scale;
    const centerX = imageFrame.left + imageWidth / 2;
    const centerY = imageFrame.top + imageHeight / 2;
    const minLeft = frameWidth - width;
    const minTop = frameHeight - height;
    return {
      left: Math.min(0, Math.max(minLeft, centerX - width / 2)),
      top: Math.min(0, Math.max(minTop, centerY - height / 2)),
      width: width,
      height: height
    };
  }

  private buildAspectFillImageRect(
    containerWidth: number,
    containerHeight: number,
    imageWidth: number,
    imageHeight: number
  ): BrowserTabsOverlayRect {
    const safeWidth = Math.max(1, containerWidth);
    const safeHeight = Math.max(1, containerHeight);
    const safeImageWidth = Math.max(1, imageWidth);
    const safeImageHeight = Math.max(1, imageHeight);
    const imageScale = Math.max(safeWidth / safeImageWidth, safeHeight / safeImageHeight);
    const scaledWidth = safeImageWidth * imageScale;
    const scaledHeight = safeImageHeight * imageScale;
    return {
      left: Math.round((safeWidth - scaledWidth) / 2),
      top: 0,
      width: scaledWidth,
      height: scaledHeight
    };
  }

  private buildPositiveRect(rect: BrowserTabsOverlayRect): BrowserTabsOverlayRect {
    return {
      left: rect.left,
      top: rect.top,
      width: Math.max(1, rect.width),
      height: Math.max(1, rect.height)
    };
  }

  private interpolateRect(
    startRect: BrowserTabsOverlayRect,
    endRect: BrowserTabsOverlayRect,
    progress: number
  ): BrowserTabsOverlayRect {
    return {
      left: this.lerp(startRect.left, endRect.left, progress),
      top: this.lerp(startRect.top, endRect.top, progress),
      width: this.lerp(startRect.width, endRect.width, progress),
      height: this.lerp(startRect.height, endRect.height, progress)
    };
  }

  private clampProgress(value: number): number {
    return Math.max(0, Math.min(1, value));
  }

  private lerp(start: number, end: number, progress: number): number {
    return start + ((end - start) * this.clampProgress(progress));
  }

}
