import {
  HOME_PAGE_PRESENTATION_HOME_LOGO_CUSTOM_HEIGHT_KEY,
  HOME_PAGE_PRESENTATION_HOME_LOGO_CUSTOM_URI_KEY,
  HOME_PAGE_PRESENTATION_HOME_LOGO_CUSTOM_WIDTH_KEY,
  HOME_PAGE_PRESENTATION_HOME_LOGO_ID_KEY,
  HOME_PAGE_PRESENTATION_HOME_LOGO_OPACITY_KEY,
  HOME_PAGE_PRESENTATION_HOME_LOGO_SCALE_RATIO_KEY
} from '../../../common/constants/HomePagePresentationStorageKeys';
import {
  HOME_LOGO_BUILTIN_ID,
  HOME_LOGO_BUILTIN_RAWFILE,
  HomeLogoColorMode,
  HomeLogoCustomAsset,
  HomeLogoDisplaySource,
  homeLogoFollowsWallpaper,
  resolveHomeLogoDisplaySource
} from '../../../common/models/HomeLogoModels';
import {
  HOME_LOGO_OPACITY_DEFAULT,
  HOME_LOGO_SCALE_DEFAULT_RATIO,
  normalizeHomeLogoOpacity,
  resolveHomeLogoCornerRadiusVp,
  resolveHomeLogoDisplayWidthVp,
  resolveHomeLogoHeightVp
} from '../../../core/settings/HomeLogoSettingsPolicy';
import { CENTERED_HOME_WORDMARK_HEIGHT } from '../../../features/newtab/CenteredHomeShortcutLayoutPolicy';

/**
 * Presentational only: it never handles touches. A picker card owns the tap for the whole
 * tile, and the homepage mark owns its own click, so a logo image inside a larger tap target
 * must not swallow the press.
 */
@Component
export struct HomeLogoAssetImage {
  @Prop fileUri: string = '';
  @Prop rawfileName: string = HOME_LOGO_BUILTIN_RAWFILE;
  @Prop intrinsicWidth: number = 546;
  @Prop intrinsicHeight: number = 163;
  @Prop heightVp: number = CENTERED_HOME_WORDMARK_HEIGHT;
  @Prop maxWidthVp: number = 0;
  @Prop colorMode: HomeLogoColorMode = 'authored';
  @Prop cornerRadiusVp: number = 0;
  @Prop tintColor: ResourceColor = '#111111';
  @Prop label: string = '';

  build() {
    // A user file is never a mask. Only a shipped wallpaper-mode SVG may take fillColor;
    // authored art keeps every color it was drawn with.
    if (this.fileUri.length > 0) {
      Image(this.fileUri)
        .width(this.resolveWidth())
        .height(this.heightVp)
        .objectFit(ImageFit.Contain)
        .draggable(false)
        .borderRadius(this.cornerRadiusVp)
        .clip(this.cornerRadiusVp > 0)
        .interpolation(ImageInterpolation.Medium)
        .accessibilityText(this.label)
        .hitTestBehavior(HitTestMode.None)
    } else if (homeLogoFollowsWallpaper(this.colorMode)) {
      Image(this.resolveRawfile())
        .width(this.resolveWidth())
        .height(this.heightVp)
        .objectFit(ImageFit.Contain)
        .fillColor(this.tintColor)
        .borderRadius(this.cornerRadiusVp)
        .clip(this.cornerRadiusVp > 0)
        .draggable(false)
        .interpolation(ImageInterpolation.Medium)
        .accessibilityText(this.label)
        .hitTestBehavior(HitTestMode.None)
    } else {
      Image(this.resolveRawfile())
        .width(this.resolveWidth())
        .height(this.heightVp)
        .objectFit(ImageFit.Contain)
        .borderRadius(this.cornerRadiusVp)
        .clip(this.cornerRadiusVp > 0)
        .draggable(false)
        .interpolation(ImageInterpolation.Medium)
        .accessibilityText(this.label)
        .hitTestBehavior(HitTestMode.None)
    }
  }

  private resolveWidth(): number {
    return resolveHomeLogoDisplayWidthVp(
      this.intrinsicWidth,
      this.intrinsicHeight,
      this.heightVp,
      this.maxWidthVp
    );
  }

  private resolveRawfile(): Resource {
    return $rawfile(this.rawfileName);
  }
}

@Component
export struct HomeLogoMark {
  @StorageProp(HOME_PAGE_PRESENTATION_HOME_LOGO_ID_KEY) private storedLogoId: string = HOME_LOGO_BUILTIN_ID;
  @StorageProp(HOME_PAGE_PRESENTATION_HOME_LOGO_CUSTOM_URI_KEY) private storedCustomUri: string = '';
  @StorageProp(HOME_PAGE_PRESENTATION_HOME_LOGO_CUSTOM_WIDTH_KEY) private storedCustomWidth: number = 0;
  @StorageProp(HOME_PAGE_PRESENTATION_HOME_LOGO_CUSTOM_HEIGHT_KEY) private storedCustomHeight: number = 0;
  @StorageProp(HOME_PAGE_PRESENTATION_HOME_LOGO_SCALE_RATIO_KEY)
  private storedScaleRatio: number = HOME_LOGO_SCALE_DEFAULT_RATIO;
  @StorageProp(HOME_PAGE_PRESENTATION_HOME_LOGO_OPACITY_KEY)
  private storedOpacity: number = HOME_LOGO_OPACITY_DEFAULT;
  @Prop heightVp: number = CENTERED_HOME_WORDMARK_HEIGHT;
  @Prop maxWidthVp: number = 0;
  @Prop tintColor: ResourceColor = '#111111';
  @Prop clickable: boolean = false;
  @Prop label: string = 'Aira';
  onLogoClick: () => void = () => {};

  build() {
    if (this.clickable) {
      Stack() {
        this.buildMark()
      }
      .onClick(() => {
        this.onLogoClick();
      })
    } else {
      this.buildMark()
    }
  }

  @Builder
  private buildMark() {
    HomeLogoAssetImage({
      fileUri: this.resolveSource().fileUri,
      rawfileName: this.resolveSource().rawfileName,
      intrinsicWidth: this.resolveSource().intrinsicWidth,
      intrinsicHeight: this.resolveSource().intrinsicHeight,
      // The caller hands in the base height for its own layout; the user's slider scales it.
      heightVp: resolveHomeLogoHeightVp(this.heightVp, this.storedScaleRatio),
      maxWidthVp: this.maxWidthVp,
      colorMode: this.resolveSource().colorMode,
      cornerRadiusVp: resolveHomeLogoCornerRadiusVp(
        resolveHomeLogoHeightVp(this.heightVp, this.storedScaleRatio),
        this.resolveSource().shape
      ),
      tintColor: this.tintColor,
      label: this.label
    })
      // 0 hides the mark but keeps its place, so the search field does not jump.
      .opacity(normalizeHomeLogoOpacity(this.storedOpacity))
  }

  /**
   * The repository publishes the selected custom asset through three keys, so the mark rebuilds
   * the one asset it needs instead of carrying the whole custom list in AppStorage.
   */
  private resolveSource(): HomeLogoDisplaySource {
    const customUri = this.storedCustomUri;
    const customAssets: HomeLogoCustomAsset[] = customUri.length > 0 ? [{
      id: this.storedLogoId,
      uri: customUri,
      fileName: '',
      width: this.storedCustomWidth,
      height: this.storedCustomHeight
    }] : [];
    return resolveHomeLogoDisplaySource({
      id: this.storedLogoId,
      customAssets: customAssets
    });
  }
}
