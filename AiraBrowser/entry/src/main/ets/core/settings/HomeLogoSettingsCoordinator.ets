import {
  buildHomeLogoCustomAssetId,
  findHomeLogoCustomAsset,
  findHomeLogoPreset,
  HomeLogoCustomAsset,
  HomeLogoPickSource,
  HomeLogoSelection,
  normalizeHomeLogoSelection,
  withoutHomeLogoCustomAsset
} from '../../common/models/HomeLogoModels';
import { HomeLogoImageService } from '../../services/settings/HomeLogoImageService';
import {
  HOME_LOGO_MAX_CUSTOM_ASSETS,
  normalizeHomeLogoOpacity,
  normalizeHomeLogoScaleRatio
} from './HomeLogoSettingsPolicy';
import { HomePagePresentationSettingsRepository } from '../../data/preferences/HomePagePresentationSettingsRepository';

/**
 * Owns the logo choice. Adding an image appends it to the custom list and selects it, so the
 * tile it creates sits before the add tile and the add tile stays last.
 */
export class HomeLogoSettingsCoordinator {
  private repository: HomePagePresentationSettingsRepository;
  private imageService: HomeLogoImageService;

  constructor(
    repository: HomePagePresentationSettingsRepository,
    imageService: HomeLogoImageService = new HomeLogoImageService()
  ) {
    this.repository = repository;
    this.imageService = imageService;
  }

  getSelection(): HomeLogoSelection {
    const settings = this.repository.getSettings();
    return normalizeHomeLogoSelection({
      id: settings.homeLogoId,
      customAssets: settings.homeLogoCustomAssets
    });
  }

  async selectLogo(id: string): Promise<HomeLogoSelection> {
    const current = this.getSelection();
    const isPreset = findHomeLogoPreset(id) !== undefined;
    if (!isPreset && findHomeLogoCustomAsset(current.customAssets, id) === undefined) {
      throw new Error('这个 Logo 不可用。');
    }
    return this.writeSelection({ id: id, customAssets: current.customAssets });
  }

  async importCustomLogo(source: HomeLogoPickSource): Promise<HomeLogoSelection | undefined> {    const imported = await this.imageService.pickAndSave(source);
    if (imported === undefined) {
      return undefined;
    }
    const current = this.getSelection();
    const asset: HomeLogoCustomAsset = {
      id: buildHomeLogoCustomAssetId(Date.now()),
      uri: imported.uri,
      fileName: imported.fileName,
      width: imported.width,
      height: imported.height
    };
    const assets: HomeLogoCustomAsset[] = current.customAssets.slice();
    assets.push(asset);
    const dropped: HomeLogoCustomAsset[] = [];
    while (assets.length > HOME_LOGO_MAX_CUSTOM_ASSETS) {
      const evicted = assets.shift();
      if (evicted === undefined) {
        break;
      }
      dropped.push(evicted);
    }
    const selection = await this.writeSelection({ id: asset.id, customAssets: assets });
    for (let index = 0; index < dropped.length; index += 1) {
      // The tile is gone, so its file has no reader left.
      await this.imageService.removeStoredImage(dropped[index].uri);
    }
    return selection;
  }

  /** Removes one imported logo and its file. A selected import falls back to the shipped wordmark. */
  async removeCustomLogo(id: string): Promise<HomeLogoSelection> {
    const current = this.getSelection();
    const asset = findHomeLogoCustomAsset(current.customAssets, id);
    const next = withoutHomeLogoCustomAsset(current, id);
    if (asset === undefined || next === undefined) {
      throw new Error('这个 Logo 不可用。');
    }
    const selection = await this.writeSelection(next);
    await this.imageService.removeStoredImage(asset.uri);
    return selection;
  }

  getScaleRatio(): number {
    return normalizeHomeLogoScaleRatio(this.repository.getSettings().homeLogoScaleRatio);
  }

  /** The slider is dragged continuously but only committed on release, so this stays cheap. */
  async setScaleRatio(scaleRatio: number): Promise<number> {
    const next = await this.repository.setHomeLogoScaleRatio(scaleRatio);
    return normalizeHomeLogoScaleRatio(next.homeLogoScaleRatio);
  }

  getOpacity(): number {
    return normalizeHomeLogoOpacity(this.repository.getSettings().homeLogoOpacity);
  }

  /** Dragging updates the mark live; this only stores the value once the finger leaves. */
  async setOpacity(opacity: number): Promise<number> {
    const next = await this.repository.setHomeLogoOpacity(opacity);
    return normalizeHomeLogoOpacity(next.homeLogoOpacity);
  }

  private async writeSelection(selection: HomeLogoSelection): Promise<HomeLogoSelection> {
    await this.repository.setHomeLogoSelection(selection);
    return this.getSelection();
  }
}
