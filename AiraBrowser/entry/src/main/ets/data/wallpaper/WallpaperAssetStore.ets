import { fileIo, fileUri } from '@kit.CoreFileKit';
import { resolveAppResourceText } from '../../core/resources/AppResourceText';
import { AppRuntimeContext } from '../../app/runtime/AppRuntimeContext';
import {
  BrowserHomepageBackdropAppearanceState
} from '../../common/models/BackdropAppearanceModels';
import {
  HomeWallpaperForegroundAnalysis,
  WallpaperAsset
} from '../../common/models/WallpaperModels';

const WALLPAPER_ROOT_DIR: string = 'wallpapers';
const WALLPAPER_ORIGINAL_DIR: string = 'original';
const WALLPAPER_DOWNLOAD_DIR: string = 'downloads';
const MAX_IMPORTED_IMAGE_BYTES: number = 30 * 1024 * 1024;
const MAX_IMPORTED_VIDEO_BYTES: number = 100 * 1024 * 1024;

export class WallpaperAssetStore {
  async saveDownloadedImage(
    source: 'bing',
    assetId: string,
    payload: ArrayBuffer,
    title: string,
    attribution: string,
    foregroundAnalysis: HomeWallpaperForegroundAnalysis,
    appearanceLight?: BrowserHomepageBackdropAppearanceState,
    appearanceDark?: BrowserHomepageBackdropAppearanceState,
    nowMs: number = Date.now()
  ): Promise<WallpaperAsset> {
    if (assetId.trim().length === 0 || payload.byteLength <= 0 || payload.byteLength > MAX_IMPORTED_IMAGE_BYTES) {
      throw new Error(resolveAppResourceText($r('app.string.wallpaper_download_failed')));
    }

    await this.ensureDirectories();
    const id = this.sanitizeAssetId(assetId);
    const contentSignature = this.sanitizeAssetId(foregroundAnalysis.contentSignature);
    if (contentSignature.length <= 0) {
      throw new Error(resolveAppResourceText($r('app.string.wallpaper_signature_invalid')));
    }
    const fileName = `${id}-${contentSignature}.jpg`;
    const tempPath = `${this.getDownloadsDir()}/${fileName}.download`;
    const finalPath = `${this.getOriginalDir()}/${fileName}`;

    await this.deleteIfExists(tempPath);
    const file = await fileIo.open(tempPath, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      await fileIo.write(file.fd, payload);
    } finally {
      await fileIo.close(file);
    }

    if (await this.fileExists(finalPath)) {
      await this.deleteIfExists(tempPath);
    } else {
      await fileIo.rename(tempPath, finalPath);
    }
    const finalUri = fileUri.getUriFromPath(finalPath);
    return {
      id: id,
      source: source,
      mediaType: 'image',
      originalPath: finalUri,
      displayPath: finalUri,
      thumbPath: finalUri,
      contentSignature: foregroundAnalysis.contentSignature,
      foregroundTone: foregroundAnalysis.foregroundTone,
      foregroundToneContentSignature: foregroundAnalysis.contentSignature,
      foregroundToneCropSignature: foregroundAnalysis.cropSignature,
      foregroundToneSampleSignature: foregroundAnalysis.sampleSignature,
      foregroundToneAlgorithmVersion: foregroundAnalysis.algorithmVersion,
      appearanceLight: appearanceLight,
      appearanceDark: appearanceDark,
      width: 0,
      height: 0,
      mimeType: 'image/jpeg',
      byteSize: payload.byteLength,
      title: title.trim().length > 0 ? title.trim() : resolveAppResourceText($r('app.string.wallpaper_bing_daily')),
      attribution: attribution.trim(),
      createdAt: nowMs,
      updatedAt: nowMs,
      isFavorite: false
    };
  }

  async pruneObsoleteDownloadedImages(activeAsset: WallpaperAsset): Promise<void> {
    const activeFileName = `${this.sanitizeAssetId(activeAsset.id)}-${this.sanitizeAssetId(activeAsset.contentSignature)}.jpg`;
    const prefix = `${this.sanitizeAssetId(activeAsset.id)}-`;
    const fileNames = await fileIo.listFile(this.getOriginalDir());
    for (let index = 0; index < fileNames.length; index += 1) {
      const fileName = fileNames[index];
      if (fileName === activeFileName || !fileName.startsWith(prefix) || !fileName.endsWith('.jpg')) {
        continue;
      }
      await this.deleteIfExists(`${this.getOriginalDir()}/${fileName}`);
    }
  }

  async saveImportedImage(
    sourceUri: string,
    sourceFileName: string,
    assetId: string,
    width: number,
    height: number,
    foregroundAnalysis: HomeWallpaperForegroundAnalysis,
    nowMs: number = Date.now()
  ): Promise<WallpaperAsset> {
    const normalizedSourceUri = sourceUri.trim();
    if (normalizedSourceUri.length <= 0 || assetId.trim().length <= 0) {
      throw new Error(resolveAppResourceText($r('app.string.wallpaper_none_selected')));
    }
    await this.ensureDirectories();
    const id = this.sanitizeAssetId(assetId);
    const contentSignature = this.sanitizeAssetId(foregroundAnalysis.contentSignature);
    if (contentSignature.length <= 0) {
      throw new Error(resolveAppResourceText($r('app.string.wallpaper_signature_invalid')));
    }
    const extension = this.resolveImportedImageExtension(sourceFileName);
    const fileName = `${id}-${contentSignature}.${extension}`;
    const tempPath = `${this.getDownloadsDir()}/${fileName}.import`;
    const finalPath = `${this.getOriginalDir()}/${fileName}`;
    await this.deleteIfExists(tempPath);
    try {
      await fileIo.copy(normalizedSourceUri, fileUri.getUriFromPath(tempPath));
      const stat = await fileIo.stat(tempPath);
      if (stat.isDirectory() || stat.size <= 0) {
        throw new Error(resolveAppResourceText($r('app.string.wallpaper_unavailable')));
      }
      if (stat.size > MAX_IMPORTED_IMAGE_BYTES) {
        throw new Error(resolveAppResourceText($r('app.string.wallpaper_too_large')));
      }
      if (await this.fileExists(finalPath)) {
        await this.deleteIfExists(tempPath);
      } else {
        await fileIo.rename(tempPath, finalPath);
      }
      const finalUri = fileUri.getUriFromPath(finalPath);
      return {
        id: id,
        source: 'custom',
        mediaType: 'image',
        originalPath: finalUri,
        displayPath: finalUri,
        thumbPath: finalUri,
        contentSignature: foregroundAnalysis.contentSignature,
        foregroundTone: foregroundAnalysis.foregroundTone,
        foregroundToneContentSignature: foregroundAnalysis.contentSignature,
        foregroundToneCropSignature: foregroundAnalysis.cropSignature,
        foregroundToneSampleSignature: foregroundAnalysis.sampleSignature,
        foregroundToneAlgorithmVersion: foregroundAnalysis.algorithmVersion,
        width: Math.max(1, Math.floor(width)),
        height: Math.max(1, Math.floor(height)),
        mimeType: this.resolveImportedMimeType(extension),
        byteSize: Math.max(0, Math.floor(stat.size)),
        title: resolveAppResourceText($r('app.string.wallpaper_custom_title')),
        attribution: '',
        createdAt: nowMs,
        updatedAt: nowMs,
        isFavorite: false
      };
    } catch (error) {
      await this.deleteIfExists(tempPath);
      if (error instanceof Error && error.message.length > 0) {
        throw error;
      }
      throw new Error(resolveAppResourceText($r('app.string.wallpaper_save_failed')));
    }
  }

  async pruneObsoleteImportedImages(activeAsset: WallpaperAsset): Promise<void> {
    const prefix = `${this.sanitizeAssetId(activeAsset.id)}-`;
    const activeOriginal = activeAsset.originalPath;
    const activeDisplay = activeAsset.displayPath;
    const activeThumb = activeAsset.thumbPath;
    const fileNames = await fileIo.listFile(this.getOriginalDir());
    for (let index = 0; index < fileNames.length; index += 1) {
      const fileName = fileNames[index];
      const path = `${this.getOriginalDir()}/${fileName}`;
      const pathUri = fileUri.getUriFromPath(path);
      if (!fileName.startsWith(prefix) ||
        pathUri === activeOriginal ||
        pathUri === activeDisplay ||
        pathUri === activeThumb) {
        continue;
      }
      await this.deleteIfExists(path);
    }
  }

  async saveImportedVideo(
    sourceUri: string,
    sourceFileName: string,
    assetId: string,
    width: number,
    height: number,
    foregroundAnalysis: HomeWallpaperForegroundAnalysis,
    posterBytes: ArrayBuffer,
    nowMs: number = Date.now()
  ): Promise<WallpaperAsset> {
    const normalizedSourceUri = sourceUri.trim();
    if (normalizedSourceUri.length <= 0 || assetId.trim().length <= 0) {
      throw new Error(resolveAppResourceText($r('app.string.wallpaper_video_none')));
    }
    await this.ensureDirectories();
    const id = this.sanitizeAssetId(assetId);
    const contentSignature = this.sanitizeAssetId(foregroundAnalysis.contentSignature);
    if (contentSignature.length <= 0) {
      throw new Error(resolveAppResourceText($r('app.string.wallpaper_video_signature_invalid')));
    }
    const extension = this.resolveImportedVideoExtension(sourceFileName);
    const fileName = `${id}-${contentSignature}.${extension}`;
    const tempPath = `${this.getDownloadsDir()}/${fileName}.import`;
    const finalPath = `${this.getOriginalDir()}/${fileName}`;
    await this.deleteIfExists(tempPath);
    try {
      await fileIo.copy(normalizedSourceUri, fileUri.getUriFromPath(tempPath));
      const stat = await fileIo.stat(tempPath);
      if (stat.isDirectory() || stat.size <= 0) {
        throw new Error(resolveAppResourceText($r('app.string.wallpaper_video_unavailable')));
      }
      if (stat.size > MAX_IMPORTED_VIDEO_BYTES) {
        throw new Error(resolveAppResourceText($r('app.string.wallpaper_video_too_large')));
      }
      if (await this.fileExists(finalPath)) {
        await this.deleteIfExists(tempPath);
      } else {
        await fileIo.rename(tempPath, finalPath);
      }
      const finalUri = fileUri.getUriFromPath(finalPath);
      const thumbUri = await this.writeImportedPoster(id, foregroundAnalysis.contentSignature, posterBytes);
      return {
        id: id,
        source: 'custom',
        mediaType: 'video',
        originalPath: finalUri,
        displayPath: finalUri,
        thumbPath: thumbUri,
        contentSignature: foregroundAnalysis.contentSignature,
        foregroundTone: foregroundAnalysis.foregroundTone,
        foregroundToneContentSignature: foregroundAnalysis.contentSignature,
        foregroundToneCropSignature: foregroundAnalysis.cropSignature,
        foregroundToneSampleSignature: foregroundAnalysis.sampleSignature,
        foregroundToneAlgorithmVersion: foregroundAnalysis.algorithmVersion,
        width: Math.max(1, Math.floor(width)),
        height: Math.max(1, Math.floor(height)),
        mimeType: this.resolveImportedVideoMimeType(extension),
        byteSize: Math.max(0, Math.floor(stat.size)),
        title: resolveAppResourceText($r('app.string.wallpaper_video_title')),
        attribution: '',
        createdAt: nowMs,
        updatedAt: nowMs,
        isFavorite: false
      };
    } catch (error) {
      await this.deleteIfExists(tempPath);
      if (error instanceof Error && error.message.length > 0) {
        throw error;
      }
      throw new Error(resolveAppResourceText($r('app.string.wallpaper_video_save_failed')));
    }
  }

  async writeImportedPoster(
    assetId: string,
    contentSignature: string,
    posterBytes: ArrayBuffer
  ): Promise<string> {
    if (posterBytes.byteLength <= 0) {
      return '';
    }
    await this.ensureDirectories();
    const id = this.sanitizeAssetId(assetId);
    const signature = this.sanitizeAssetId(contentSignature);
    if (id.length <= 0 || signature.length <= 0) {
      return '';
    }
    const posterPath = `${this.getOriginalDir()}/${id}-${signature}.poster.jpg`;
    let file: fileIo.File | undefined = undefined;
    try {
      file = await fileIo.open(
        posterPath,
        fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
      );
      await fileIo.write(file.fd, posterBytes);
      return fileUri.getUriFromPath(posterPath);
    } catch (_error) {
      return '';
    } finally {
      if (file !== undefined) {
        try {
          await fileIo.close(file);
        } catch (_closeError) {
        }
      }
    }
  }

  async discardStoredImage(asset: WallpaperAsset): Promise<void> {
    await this.deleteIfExists(asset.originalPath);
    if (asset.thumbPath.length > 0 && asset.thumbPath !== asset.originalPath) {
      await this.deleteIfExists(asset.thumbPath);
    }
  }

  private async ensureDirectories(): Promise<void> {
    await this.ensureDirectory(this.getRootDir());
    await this.ensureDirectory(this.getOriginalDir());
    await this.ensureDirectory(this.getDownloadsDir());
  }

  private async ensureDirectory(path: string): Promise<void> {
    try {
      if (await fileIo.access(path)) {
        return;
      }
    } catch (_error) {
    }
    await fileIo.mkdir(path, true);
  }

  private async deleteIfExists(path: string): Promise<void> {
    try {
      if (await fileIo.access(path)) {
        await fileIo.unlink(path);
      }
    } catch (_error) {
    }
  }

  private async fileExists(path: string): Promise<boolean> {
    try {
      return await fileIo.access(path);
    } catch (_error) {
      return false;
    }
  }

  private getRootDir(): string {
    return `${AppRuntimeContext.getApplicationContext().filesDir}/${WALLPAPER_ROOT_DIR}`;
  }

  private getOriginalDir(): string {
    return `${this.getRootDir()}/${WALLPAPER_ORIGINAL_DIR}`;
  }

  private getDownloadsDir(): string {
    return `${this.getRootDir()}/${WALLPAPER_DOWNLOAD_DIR}`;
  }

  private sanitizeAssetId(value: string): string {
    const normalized = value
      .replace(/[^a-zA-Z0-9_-]/g, '-')
      .replace(/-+/g, '-')
      .replace(/^-|-$/g, '');
    return normalized.length > 0 ? normalized : `wallpaper-${Math.max(0, Math.floor(Date.now()))}`;
  }

  private resolveImportedImageExtension(fileName: string): string {
    const normalized = fileName.trim().toLowerCase().split('?')[0].split('#')[0];
    if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
      return 'jpg';
    }
    if (normalized.endsWith('.png')) {
      return 'png';
    }
    if (normalized.endsWith('.webp')) {
      return 'webp';
    }
    if (normalized.endsWith('.heic')) {
      return 'heic';
    }
    if (normalized.endsWith('.heif')) {
      return 'heif';
    }
    return 'image';
  }

  private resolveImportedVideoExtension(fileName: string): string {
    const normalized = fileName.trim().toLowerCase().split('?')[0].split('#')[0];
    if (normalized.endsWith('.mov')) {
      return 'mov';
    }
    if (normalized.endsWith('.m4v')) {
      return 'm4v';
    }
    if (normalized.endsWith('.webm')) {
      return 'webm';
    }
    if (normalized.endsWith('.mkv')) {
      return 'mkv';
    }
    if (normalized.endsWith('.3gp')) {
      return '3gp';
    }
    return 'mp4';
  }

  private resolveImportedVideoMimeType(extension: string): string {
    if (extension === 'mov') {
      return 'video/quicktime';
    }
    if (extension === 'webm') {
      return 'video/webm';
    }
    if (extension === 'mkv') {
      return 'video/x-matroska';
    }
    if (extension === '3gp') {
      return 'video/3gpp';
    }
    return 'video/mp4';
  }

  private resolveImportedMimeType(extension: string): string {
    if (extension === 'jpg') {
      return 'image/jpeg';
    }
    if (extension === 'png') {
      return 'image/png';
    }
    if (extension === 'webp') {
      return 'image/webp';
    }
    if (extension === 'heic' || extension === 'heif') {
      return 'image/heif';
    }
    return 'image/*';
  }
}
