import { resolveAppResourceText } from '../resources/AppResourceText';
import {
  findHomeWallpaperChoice,
  HomeWallpaperChoice,
  HomeWallpaperChoiceKind,
  listHomeWallpaperChoices,
  normalizeHomeWallpaperSolidColorId,
  WallpaperAsset,
  WallpaperMode,
  WallpaperRepositorySnapshot,
  WallpaperSettings
} from '../../common/models/WallpaperModels';

export type WallpaperImageMode = 'bing' | 'custom' | 'video';
export type WallpaperBingPreviewStatus = 'idle' | 'loading' | 'ready' | 'error';

export interface WallpaperModeOptionViewState {
  id: WallpaperMode;
  title: string;
  summary: string;
  isSelected: boolean;
  isEnabled: boolean;
}

export interface WallpaperImageOptionViewState {
  id: WallpaperImageMode;
  title: string;
  previewPath: string;
  isSelected: boolean;
  isEmpty: boolean;
  isEnabled: boolean;
}

export interface WallpaperColorChoiceViewState {
  id: string;
  label: string;
  kind: HomeWallpaperChoiceKind;
  /** Empty for the auto and follow-theme choices, which paint more than one color. */
  color: string;
  isSelected: boolean;
  isEnabled: boolean;
}

export interface WallpaperSettingsViewState {
  mode: WallpaperMode;
  modeTitle: string;
  colorChoices: WallpaperColorChoiceViewState[];
  imageOptions: WallpaperImageOptionViewState[];
  bingPreviewStatus: WallpaperBingPreviewStatus;
  bingPreviewStatusText: string;
  bingRetryVisible: boolean;
  footerText: string;
}

export class WallpaperSettingsViewModel {
  buildState(
    snapshot: WallpaperRepositorySnapshot,
    bingPreviewStatus: WallpaperBingPreviewStatus = 'idle'
  ): WallpaperSettingsViewState {
    const settings = snapshot.settings;
    const hasBingPreview = this.findImageAsset('bing', snapshot) !== undefined;
    const bingPreviewStatusText = this.buildBingPreviewStatusText(bingPreviewStatus, hasBingPreview);
    const bingRetryVisible = bingPreviewStatus === 'error';
    const footerText = resolveAppResourceText($r('app.string.wallpaper_footer'));
    return {
      mode: settings.mode,
      modeTitle: this.resolveModeTitle(snapshot),
      colorChoices: this.buildColorChoices(settings),
      imageOptions: this.buildImageOptions(snapshot),
      bingPreviewStatus: bingPreviewStatus,
      bingPreviewStatusText: bingPreviewStatusText,
      bingRetryVisible: bingRetryVisible,
      footerText: footerText
    };
  }

  /** Auto black/white first, then the flat colors, then follow-theme last. */
  private buildColorChoices(settings: WallpaperSettings): WallpaperColorChoiceViewState[] {
    const choices: WallpaperColorChoiceViewState[] = [];
    listHomeWallpaperChoices().forEach((choice: HomeWallpaperChoice) => {
      choices.push({
        id: choice.id,
        label: choice.label,
        kind: choice.kind,
        color: choice.color,
        isSelected: this.isChoiceSelected(settings, choice),
        isEnabled: true
      });
    });
    return choices;
  }

  private isChoiceSelected(settings: WallpaperSettings, choice: HomeWallpaperChoice): boolean {
    if (choice.kind === 'auto') {
      return settings.mode === 'auto';
    }
    if (choice.kind === 'theme') {
      return settings.mode === 'theme';
    }
    return settings.mode === 'solid' &&
      normalizeHomeWallpaperSolidColorId(settings.solidColorId) === choice.id;
  }

  buildSettingsWithMode(settings: WallpaperSettings, mode: WallpaperMode): WallpaperSettings {
    return {
      mode: mode,
      solidColorId: settings.solidColorId,
      bingWallpaperId: settings.bingWallpaperId,
      customWallpaperId: settings.customWallpaperId,
      bing: settings.bing,
      updatedAt: Date.now()
    };
  }

  buildSettingsWithSolidColor(settings: WallpaperSettings, solidColorId: string): WallpaperSettings {
    return {
      mode: 'solid',
      solidColorId: normalizeHomeWallpaperSolidColorId(solidColorId),
      bingWallpaperId: settings.bingWallpaperId,
      customWallpaperId: settings.customWallpaperId,
      bing: settings.bing,
      updatedAt: Date.now()
    };
  }

  /** Names the current wallpaper, so the settings row can show what is actually painted. */
  private resolveModeTitle(snapshot: WallpaperRepositorySnapshot): string {
    const settings = snapshot.settings;
    if (settings.mode === 'solid') {
      const choice = findHomeWallpaperChoice(settings.solidColorId);
      return choice === undefined ? this.getModeTitle('solid') : choice.label;
    }
    if (settings.mode === 'custom' && this.findCustomMediaAsset(snapshot, 'video') !== undefined) {
      return resolveAppResourceText($r('app.string.wallpaper_video_title'));
    }
    return this.getModeTitle(settings.mode);
  }

  private buildImageOptions(snapshot: WallpaperRepositorySnapshot): WallpaperImageOptionViewState[] {
    return [
      this.buildImageOption('bing', snapshot),
      this.buildImageOption('custom', snapshot),
      this.buildImageOption('video', snapshot)
    ];
  }

  private buildImageOption(
    mode: WallpaperImageMode,
    snapshot: WallpaperRepositorySnapshot
  ): WallpaperImageOptionViewState {
    const asset = this.findImageAsset(mode, snapshot);
    const previewPath = this.resolvePreviewPath(asset);
    return {
      id: mode,
      title: this.resolveImageOptionTitle(mode),
      previewPath: previewPath,
      isSelected: this.isImageOptionSelected(mode, snapshot),
      isEmpty: mode === 'video' ?
        this.findCustomMediaAsset(snapshot, 'video') === undefined :
        previewPath.trim().length <= 0,
      isEnabled: true
    };
  }

  private isImageOptionSelected(mode: WallpaperImageMode, snapshot: WallpaperRepositorySnapshot): boolean {
    if (mode === 'bing') {
      return snapshot.settings.mode === 'bing';
    }
    if (snapshot.settings.mode !== 'custom') {
      return false;
    }
    const videoAsset = this.findCustomMediaAsset(snapshot, 'video');
    return mode === 'video' ? videoAsset !== undefined : videoAsset === undefined;
  }

  private findImageAsset(
    mode: WallpaperImageMode,
    snapshot: WallpaperRepositorySnapshot
  ): WallpaperAsset | undefined {
    if (mode === 'video') {
      return this.findCustomMediaAsset(snapshot, 'video');
    }
    if (mode === 'custom') {
      return this.findCustomMediaAsset(snapshot, 'image');
    }
    const selectedId = snapshot.settings.bingWallpaperId.trim().length > 0 ?
      snapshot.settings.bingWallpaperId :
      snapshot.settings.bing.currentAssetId;
    const selected = snapshot.assets.find((asset: WallpaperAsset) => {
      return asset.source === 'bing' && asset.id === selectedId && this.resolvePreviewPath(asset).length > 0;
    });
    if (selected !== undefined) {
      return selected;
    }
    return snapshot.assets.find((asset: WallpaperAsset) => {
      return asset.source === 'bing' && this.resolvePreviewPath(asset).length > 0;
    });
  }

  private findCustomMediaAsset(
    snapshot: WallpaperRepositorySnapshot,
    mediaType: 'image' | 'video'
  ): WallpaperAsset | undefined {
    const selectedId = snapshot.settings.customWallpaperId.trim();
    if (selectedId.length <= 0) {
      return undefined;
    }
    return snapshot.assets.find((asset: WallpaperAsset) => {
      return asset.source === 'custom' &&
        asset.id === selectedId &&
        asset.mediaType === mediaType &&
        asset.displayPath.trim().length > 0;
    });
  }

  private resolvePreviewPath(asset: WallpaperAsset | undefined): string {
    if (asset === undefined) {
      return '';
    }
    if (asset.mediaType === 'video') {
      const thumb = asset.thumbPath.trim();
      if (thumb.length <= 0 || thumb === asset.displayPath.trim()) {
        return '';
      }
      return thumb;
    }
    if (asset.thumbPath.trim().length > 0) {
      return asset.thumbPath;
    }
    return asset.displayPath.trim();
  }

  private resolveImageOptionTitle(mode: WallpaperImageMode): string {
    if (mode === 'video') {
      return resolveAppResourceText($r('app.string.wallpaper_video_title'));
    }
    return this.getModeTitle(mode);
  }

  private getModeTitle(mode: WallpaperMode): string {
    switch (mode) {
      case 'auto':
        return resolveAppResourceText($r('app.string.wallpaper_auto_mono'));
      case 'theme':
        return resolveAppResourceText($r('app.string.settings_home_01'));
      case 'solid':
        return resolveAppResourceText($r('app.string.wallpaper_solid'));
      case 'bing':
        return resolveAppResourceText($r('app.string.wallpaper_bing'));
      case 'custom':
        return resolveAppResourceText($r('app.string.wallpaper_custom_title'));
      default:
        return resolveAppResourceText($r('app.string.settings_home_01'));
    }
  }

  private buildBingPreviewStatusText(
    status: WallpaperBingPreviewStatus,
    hasBingPreview: boolean
  ): string {
    if (status === 'loading') {
      return hasBingPreview
        ? resolveAppResourceText($r('app.string.wallpaper_checking'))
        : resolveAppResourceText($r('app.string.wallpaper_fetching'));
    }
    if (status === 'error') {
      return hasBingPreview
        ? resolveAppResourceText($r('app.string.wallpaper_update_failed_cache'))
        : resolveAppResourceText($r('app.string.wallpaper_load_failed_network'));
    }
    return '';
  }

}
