import {
  BROWSER_THEME_STORAGE_DIVIDER_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY,
  BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_SETTINGS_ICON_FOREGROUND_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import {
  CrossDeviceLinkActionId,
  CrossDeviceLinkDeviceRowState,
  CrossDeviceLinkViewState,
  localizeCrossDeviceLinkCopy
} from '../../../core/sync/CrossDeviceLinkViewModel';
import { CrossDeviceBrowserIconKind } from '../../../core/sync/CrossDeviceBrowserIcon';
import { CrossDeviceBrowserIconResources } from '../../../core/resources/CrossDeviceBrowserIconResources';
import {
  buildCrossDeviceLinkOrbitLayout,
  capCrossDeviceLinkOrbitStageWidth,
  crossDeviceLinkOrbitPageFadeColor,
  crossDeviceLinkOrbitSpinPeriodMs,
  resolveCrossDeviceLinkOrbitCoverHeight,
  resolveCrossDeviceLinkOrbitScrollOpacity,
  CrossDeviceLinkOrbitLayout,
  CrossDeviceLinkOrbitMarkPlacement
} from '../../../core/sync/CrossDeviceLinkOrbitLayout';
import { AiraRenderableIconId } from '../../../core/resources/GeneratedAiraIconCatalog';
import { AiraIcon } from '../common/AiraIcon';
import { SettingsContentKind } from '../../../core/settings/SettingsContentLayoutPolicy';
import { DEFAULT_THEME_PALETTE } from '../../../features/theme/palettes/DefaultThemePalette';
import {
  BrowserSettingsIconBackgroundTokenSet,
  BrowserSyncProviderIconBackgroundTokenSet,
  DEFAULT_BROWSER_SETTINGS_ICON_BACKGROUND_TOKENS,
  DEFAULT_BROWSER_SYNC_PROVIDER_ICON_BACKGROUND_TOKENS
} from '../../../features/theme/BrowserThemePaletteModels';
import { SettingsHdsScaffold } from '../settings/SettingsHdsScaffold';
import {
  SettingsGroupCard,
  SettingsGroupDivider,
  SettingsPresentationScrollBody,
  SettingsSection
} from '../settings/SettingsLayout';
import {
  SettingsNavigationRow,
  SettingsRowPosition,
  SettingsStaticValueRow,
  SettingsSwitchRow
} from '../settings/SettingsRows';

const DEVICE_GLYPH: AiraRenderableIconId = 'browser.toolbar.tabs';
const ADD_DEVICE_GLYPH: AiraRenderableIconId = 'browser.toolbar.scanQr';
const EXTENSION_GLYPH: AiraRenderableIconId = 'site.setting.externalActions';
const SELF_HOSTED_GLYPH: AiraRenderableIconId = 'settings.webdav';
const LOCAL_DEVICE_GLYPH: AiraRenderableIconId = 'crossDeviceLink.localDevice';

/** Same 34 slot as the phone row and the add-device row, so the brand mark is not smaller than those badges. */
const DEVICE_BROWSER_ICON_SLOT: number = 34;
const DEVICE_BROWSER_ICON_SIZE: number = 34;
/** Neutral, low-contrast lines. No hue in either mode. */
const ORBIT_RING_COLOR_LIGHT: string = '#1A000000';
const ORBIT_RING_COLOR_DARK: string = '#1FFFFFFF';
const ORBIT_SHADOW_COLOR_LIGHT: string = '#14303A60';
const ORBIT_SHADOW_COLOR_DARK: string = '#99000000';
const ORBIT_CENTER_SHADOW_COLOR_LIGHT: string = '#1C303A60';
const ORBIT_RING_WIDTH: number = 1;

@Component
export struct CrossDeviceLinkScreen {
  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY) private storedDividerColor: string = DEFAULT_THEME_PALETTE.light.divider;
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string =
    DEFAULT_THEME_PALETTE.light.pageBackground;
  @StorageProp(BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY) private storedPressedBackgroundColor: string =
    DEFAULT_THEME_PALETTE.light.pressedBackground;
  @StorageProp(BROWSER_THEME_STORAGE_SETTINGS_ICON_FOREGROUND_KEY) private storedSettingsIconForegroundColor: string =
    DEFAULT_THEME_PALETTE.light.settingsIconForeground;
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private storedSurfaceBackgroundColor: string =
    DEFAULT_THEME_PALETTE.light.surfaceBackground;
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string =
    DEFAULT_THEME_PALETTE.light.textPrimary;
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string =
    DEFAULT_THEME_PALETTE.light.textSecondary;
  @StorageProp(BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY) private storedResolvedThemeMode: string = 'light';
  @Prop state: CrossDeviceLinkViewState;
  @Prop isBusy: boolean = false;
  /**
   * Bumped once a switch attempt settles. A refused change leaves the authoritative boolean
   * untouched, so without this the toggle would keep the flipped look the user just gave it.
   */
  @Prop switchSettledRevision: number = 0;
  @Prop showBackButton: boolean = true;
  @Prop showTitleBar: boolean = true;
  @Prop useTopSafeInset: boolean = true;
  @Prop contentKind: SettingsContentKind = 'standard';
  @Prop desktopPresentation: boolean = false;
  @Prop settingsIconBackgrounds: BrowserSettingsIconBackgroundTokenSet =
    DEFAULT_BROWSER_SETTINGS_ICON_BACKGROUND_TOKENS;
  @Prop syncProviderIconBackgrounds: BrowserSyncProviderIconBackgroundTokenSet =
    DEFAULT_BROWSER_SYNC_PROVIDER_ICON_BACKGROUND_TOKENS;
  scrollers: Array<Scroller> = [];
  onBack: () => void = (): void => {};
  onOpenSetup: () => void = (): void => {};
  onOpenDeviceTabs: (deviceId: string) => void = (_deviceId: string): void => {};
  /** This page's own cross-device switch; it never writes data-sync state. */
  onToggleLink: (enabled: boolean) => void = (_enabled: boolean): void => {};
  onAction: (action: CrossDeviceLinkActionId) => void = (_action: CrossDeviceLinkActionId) => {};
  private contentScroller: Scroller = new Scroller();
  @State private orbitStageWidth: number = 0;
  @State private orbitSpin0: number = 0;
  @State private orbitSpin1: number = 0;
  @State private orbitSpin2: number = 0;
  @State private orbitScrollOffset: number = 0;
  private orbitSpinStarted: boolean = false;
  private orbitSpinAlive: boolean = true;

  build() {
    Column() {
      SettingsHdsScaffold({
        title: $r('app.string.settings_sync_cross_device'),
        backIconKind: 'back',
        pageBackground: this.storedPageBackgroundColor,
        headerButtonBackground: this.storedPressedBackgroundColor,
        primaryTextColor: this.storedPrimaryTextColor,
        dividerColor: this.storedDividerColor,
        showBackButton: this.showBackButton,
        showTitleBar: this.showTitleBar,
        useTopSafeInset: this.useTopSafeInset,
        contentKind: this.contentKind,
        desktopPresentation: this.desktopPresentation,
        scrollers: [this.contentScroller],
        onBack: (): void => {
          this.onBack();
        }
      }) {
        Stack({ alignContent: Alignment.TopStart }) {
          this.buildOrbitHeader()

          Column() {
            SettingsPresentationScrollBody({
              desktopPresentation: this.desktopPresentation,
              expandToParent: true,
              contentSpace: 0,
              topPadding: 0,
              bottomPadding: 28,
              scroller: this.contentScroller,
              onScrollOffset: (offset: number): void => {
                this.noteOrbitScrollOffset(offset);
              }
            }) {
              this.buildOrbitCoverSpacer()
              this.buildScrollingCover()
            }
          }
          .width('100%')
          .height('100%')
          .zIndex(1)
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.storedPageBackgroundColor)
  }

  /**
   * The rings stay put as a background. The list starts over the logo's lower edge
   * and scrolls over the rings. It has no sheet of its own. This spacer stays in
   * the scroll hit test: None would let the drag fall through to the rings.
   */
  @Builder
  private buildOrbitCoverSpacer() {
    Column()
      .width('100%')
      .height(this.resolveOrbitCoverHeight())
  }

  @Builder
  private buildScrollingCover() {
    Column({ space: 16 }) {
      if (this.state.providerNotice.length > 0) {
        Text(localizeCrossDeviceLinkCopy(this.state.providerNotice))
          .width('100%')
          .fontSize(13)
          .lineHeight(19)
          .fontColor(this.storedSecondaryTextColor)
          .textAlign(TextAlign.Center)
      }
      this.buildDeviceSection()
      this.buildSyncSection()
      this.buildSetupSection()
      this.buildSelfHostedSection()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 8 })
  }

  /**
   * Three full rings share the Aira logo's center. The top dissolves into the page
   * background — light and dark each use their own — and the lower half fades out
   * instead of being clipped.
   */
  @Builder
  private buildOrbitHeader() {
    Column() {
      if (this.orbitStageWidth > 0) {
        this.buildOrbitStage(buildCrossDeviceLinkOrbitLayout(this.orbitStageWidth))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .opacity(this.resolveOrbitScrollOpacity())
    .zIndex(0)
    // None still lets the rings take the touch. Block the whole decoration so a
    // drag on the illustration scrolls the page instead of dying here.
    .hitTestBehavior(HitTestMode.BLOCK_DESCENDANTS)
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const stageWidth = capCrossDeviceLinkOrbitStageWidth(this.parseStageWidth(newArea.width));
      if (stageWidth > 0 && Math.abs(stageWidth - this.orbitStageWidth) > 0.5) {
        this.orbitStageWidth = stageWidth;
      }
      this.startOrbitSpin();
    })
  }

  @Builder
  private buildOrbitStage(layout: CrossDeviceLinkOrbitLayout) {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildOrbitRings(layout)

      ForEach(layout.marks, (mark: CrossDeviceLinkOrbitMarkPlacement) => {
        this.buildOrbitMark(mark, layout)
      }, (mark: CrossDeviceLinkOrbitMarkPlacement): string => `${mark.kind}:${layout.stageWidth}`)

      this.buildOrbitCenter(layout)
      this.buildOrbitTopFade(layout)
    }
    .width(layout.stageWidth)
    .height(layout.stageHeight)
    .hitTestBehavior(HitTestMode.BLOCK_DESCENDANTS)
  }

  /**
   * Painted with the live page background, not a fixed wash, so a dark page does
   * not keep a light seam and a light page does not keep a dark one.
   */
  @Builder
  private buildOrbitTopFade(layout: CrossDeviceLinkOrbitLayout) {
    Column()
      .width(layout.stageWidth)
      .height(layout.stageHeight)
      .hitTestBehavior(HitTestMode.None)
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [
          [crossDeviceLinkOrbitPageFadeColor(this.storedPageBackgroundColor, 'FF'), 0],
          [crossDeviceLinkOrbitPageFadeColor(this.storedPageBackgroundColor, 'FF'), layout.topFadeHold],
          [crossDeviceLinkOrbitPageFadeColor(this.storedPageBackgroundColor, '00'), layout.topFadeEnd],
          [crossDeviceLinkOrbitPageFadeColor(this.storedPageBackgroundColor, '00'), 1]
        ]
      })
  }

  @Builder
  private buildOrbitRings(layout: CrossDeviceLinkOrbitLayout) {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(layout.orbits, (radius: number) => {
        Circle()
          .width(radius * 2)
          .height(radius * 2)
          .fill(Color.Transparent)
          .stroke(this.resolveOrbitRingColor())
          .strokeWidth(ORBIT_RING_WIDTH)
          .position({ x: layout.centerX - radius, y: layout.centerY - radius })
      }, (radius: number): string => `${radius}`)

      Column()
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [Color.Black, 0],
            [Color.Black, layout.fadeHold],
            [Color.Transparent, layout.fadeEnd],
            [Color.Transparent, 1]
          ]
        })
        .blendMode(BlendMode.DST_IN, BlendApplyType.OFFSCREEN)
    }
    .width(layout.stageWidth)
    .height(layout.stageHeight)
    .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
  }

  @Builder
  private buildOrbitMark(mark: CrossDeviceLinkOrbitMarkPlacement, layout: CrossDeviceLinkOrbitLayout) {
    Stack() {
      Stack({ alignContent: Alignment.Center }) {
        Image(CrossDeviceBrowserIconResources.icon(mark.kind))
          .width(mark.size * 0.62)
          .height(mark.size * 0.62)
          .objectFit(ImageFit.Contain)
      }
      .width(mark.size)
      .height(mark.size)
      .borderRadius(mark.size / 2)
      .backgroundColor(this.storedSurfaceBackgroundColor)
      .borderWidth(this.isDarkOrbit() ? 1 : 0)
      .borderColor(this.storedDividerColor)
      .clip(true)
      .shadow({ radius: 16, color: this.resolveOrbitShadowColor(), offsetX: 0, offsetY: 6 })
      .position({ x: mark.x - mark.size / 2, y: mark.y - mark.size / 2 })
      .rotate({
        angle: -this.resolveOrbitSpinAngle(mark.orbitIndex),
        centerX: '50%',
        centerY: '50%'
      })
    }
    .width(layout.stageWidth)
    .height(layout.stageHeight)
    .hitTestBehavior(HitTestMode.None)
    .rotate({
      angle: this.resolveOrbitSpinAngle(mark.orbitIndex),
      centerX: layout.centerX,
      centerY: layout.centerY
    })
  }

  @Builder
  private buildOrbitCenter(layout: CrossDeviceLinkOrbitLayout) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.isDarkOrbit()) {
        Image($r('app.media.aira_logo_brand'))
          .width(layout.logoSize * 0.64)
          .height(layout.logoSize * 0.64)
          .objectFit(ImageFit.Contain)
          .fillColor(this.storedPrimaryTextColor)
      } else {
        Image($r('app.media.aira_logo_brand'))
          .width(layout.logoSize * 0.64)
          .height(layout.logoSize * 0.64)
          .objectFit(ImageFit.Contain)
      }
    }
    .width(layout.logoSize)
    .height(layout.logoSize)
    .borderRadius(layout.logoSize / 2)
    .backgroundColor(this.storedSurfaceBackgroundColor)
    .borderWidth(this.isDarkOrbit() ? 1 : 0)
    .borderColor(this.storedDividerColor)
    .clip(true)
    .shadow({
      radius: 22,
      color: this.isDarkOrbit() ? ORBIT_SHADOW_COLOR_DARK : ORBIT_CENTER_SHADOW_COLOR_LIGHT,
      offsetX: 0,
      offsetY: 8
    })
    .position({ x: layout.centerX - layout.logoSize / 2, y: layout.centerY - layout.logoSize / 2 })
  }

  private parseStageWidth(value: Length): number {
    const parsed = Number.parseFloat(`${value}`);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  private isDarkOrbit(): boolean {
    return this.storedResolvedThemeMode === 'dark';
  }

  private resolveOrbitRingColor(): string {
    return this.isDarkOrbit() ? ORBIT_RING_COLOR_DARK : ORBIT_RING_COLOR_LIGHT;
  }

  private resolveOrbitShadowColor(): string {
    return this.isDarkOrbit() ? ORBIT_SHADOW_COLOR_DARK : ORBIT_SHADOW_COLOR_LIGHT;
  }

  aboutToDisappear(): void {
    this.orbitSpinAlive = false;
  }

  private resolveOrbitSpinAngle(orbitIndex: number): number {
    if (orbitIndex === 0) {
      return this.orbitSpin0;
    }
    if (orbitIndex === 1) {
      return this.orbitSpin1;
    }
    return this.orbitSpin2;
  }

  private startOrbitSpin(): void {
    if (this.orbitSpinStarted || this.orbitStageWidth <= 0) {
      return;
    }
    this.orbitSpinStarted = true;
    this.advanceOrbitSpin(0);
    this.advanceOrbitSpin(1);
    this.advanceOrbitSpin(2);
  }

  /**
   * Each ring keeps turning while the page is open. A full turn lands on the same
   * pose, so restarting at 0 does not jump.
   */
  private advanceOrbitSpin(orbitIndex: number): void {
    if (!this.orbitSpinAlive) {
      return;
    }
    animateTo({
      duration: crossDeviceLinkOrbitSpinPeriodMs(orbitIndex),
      curve: Curve.Linear,
      onFinish: (): void => {
        this.setOrbitSpin(orbitIndex, 0);
        this.advanceOrbitSpin(orbitIndex);
      }
    }, (): void => {
      this.setOrbitSpin(orbitIndex, 360);
    });
  }

  private setOrbitSpin(orbitIndex: number, degrees: number): void {
    if (orbitIndex === 0) {
      this.orbitSpin0 = degrees;
    } else if (orbitIndex === 1) {
      this.orbitSpin1 = degrees;
    } else {
      this.orbitSpin2 = degrees;
    }
  }

  private resolveOrbitCoverHeight(): number {
    if (this.orbitStageWidth <= 0) {
      return 0;
    }
    return resolveCrossDeviceLinkOrbitCoverHeight(buildCrossDeviceLinkOrbitLayout(this.orbitStageWidth));
  }

  private noteOrbitScrollOffset(offset: number): void {
    const next = offset > 0 ? offset : 0;
    if (Math.abs(next - this.orbitScrollOffset) < 0.5) {
      return;
    }
    this.orbitScrollOffset = next;
  }

  private resolveOrbitScrollOpacity(): number {
    return resolveCrossDeviceLinkOrbitScrollOpacity(this.orbitScrollOffset, this.resolveOrbitCoverHeight());
  }

  /**
   * Two different things, deliberately kept apart: 与电脑互联 is this page's own switch (tab
   * handoff and page push), while 同步设置 only hands the user to the sync owner for data
   * sync. Pausing bookmarks and history must not break tab handoff, so this page never carries
   * a second data-sync master switch of its own.
   */
  @Builder
  private buildSyncSection() {
    SettingsSection({
      title: localizeCrossDeviceLinkCopy(this.state.linkSwitchTitle),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      SettingsGroupCard({
        surfaceColor: this.storedSurfaceBackgroundColor,
        desktopPresentation: this.desktopPresentation
      }) {
        // Rebuilt from the authoritative value whenever an attempt settles, because a refused
        // change cannot move the boolean and ArkUI would not re-apply `isOn` on its own.
        ForEach([`${this.state.linkEnabled}:${this.switchSettledRevision}`], (_key: string) => {
          SettingsSwitchRow({
            title: localizeCrossDeviceLinkCopy(this.state.linkSwitchTitle),
            checked: this.state.linkEnabled,
            rowPosition: 'first',
            isEnabled: this.state.linkSwitchEnabled && !this.isBusy,
            primaryTextColor: this.storedPrimaryTextColor,
            secondaryTextColor: this.storedSecondaryTextColor,
            desktopPresentation: this.desktopPresentation,
            onChange: (checked: boolean): void => {
              this.onToggleLink(checked);
            }
          })
        }, (key: string): string => key)

        SettingsGroupDivider({ dividerColor: this.storedDividerColor })

        SettingsNavigationRow({
          title: $r('app.string.settings_sync_settings'),
          value: localizeCrossDeviceLinkCopy(this.state.syncSettingsValue),
          rowPosition: 'last',
          isEnabled: !this.isBusy,
          primaryTextColor: this.storedPrimaryTextColor,
          secondaryTextColor: this.storedSecondaryTextColor,
          pressedBackgroundColor: this.storedPressedBackgroundColor,
          desktopPresentation: this.desktopPresentation,
          onAction: (): void => {
            this.onAction('open_sync_settings');
          }
        })
      }

      Text(localizeCrossDeviceLinkCopy(this.state.linkSwitchDescription))
        .width('100%')
        .fontSize(13)
        .lineHeight(19)
        .fontColor(this.storedSecondaryTextColor)
        .padding({ left: 6, right: 6, top: 8 })
    }
  }

  @Builder
  private buildDeviceSection() {
    SettingsSection({
      title: $r('app.string.settings_link_online_devices'),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      SettingsGroupCard({
        surfaceColor: this.storedSurfaceBackgroundColor,
        desktopPresentation: this.desktopPresentation
      }) {
        // This phone is always here, because the user is holding it while reading the row.
        SettingsStaticValueRow({
          title: localizeCrossDeviceLinkCopy(this.state.localDeviceRow.title),
          value: localizeCrossDeviceLinkCopy(this.state.localDeviceRow.subtitle),
          airaIconId: LOCAL_DEVICE_GLYPH,
          iconColor: this.storedSettingsIconForegroundColor,
          // Same round badge the computer rows use, so the whole list reads as one list.
          iconBackgroundColor: this.settingsIconBackgrounds.userAgent,
          rowPosition: 'first',
          primaryTextColor: this.storedPrimaryTextColor,
          secondaryTextColor: this.storedSecondaryTextColor,
          desktopPresentation: this.desktopPresentation
        })

        SettingsGroupDivider({ dividerColor: this.storedDividerColor })

        if (this.state.devicesPlaceholderVisible) {
          this.buildPlaceholderDeviceRow()
        } else {
          ForEach(this.state.devices, (row: CrossDeviceLinkDeviceRowState, index: number) => {
            if (index > 0) {
              SettingsGroupDivider({ dividerColor: this.storedDividerColor })
            }
            SettingsNavigationRow({
              title: localizeCrossDeviceLinkCopy(row.title),
              description: localizeCrossDeviceLinkCopy(row.subtitle),
              useCustomLeading: true,
              rowPosition: this.resolveRowPosition(index + 1, this.state.devices.length + 2),
              isEnabled: !this.isBusy,
              primaryTextColor: this.storedPrimaryTextColor,
              secondaryTextColor: this.storedSecondaryTextColor,
              pressedBackgroundColor: this.storedPressedBackgroundColor,
              desktopPresentation: this.desktopPresentation,
              onAction: (): void => {
                this.onOpenDeviceTabs(row.deviceId);
              },
              customLeading: (): void => {
                this.buildBrowserBrandLeading(row.browserIconKind);
              }
            })
          }, (row: CrossDeviceLinkDeviceRowState): string => row.deviceId)
        }

        SettingsGroupDivider({ dividerColor: this.storedDividerColor })

        // The list always ends with the way to grow it, so pairing is never hidden behind
        // an empty state that the user cannot act on.
        SettingsNavigationRow({
          title: localizeCrossDeviceLinkCopy(this.state.addDeviceTitle),
          description: localizeCrossDeviceLinkCopy(this.state.addDeviceDetail),
          airaIconId: ADD_DEVICE_GLYPH,
          iconBackgroundColor: this.settingsIconBackgrounds.addDevice,
          iconColor: this.storedSettingsIconForegroundColor,
          rowPosition: 'last',
          isEnabled: !this.isBusy,
          primaryTextColor: this.storedPrimaryTextColor,
          secondaryTextColor: this.storedSecondaryTextColor,
          pressedBackgroundColor: this.storedPressedBackgroundColor,
          desktopPresentation: this.desktopPresentation,
          onAction: (): void => {
            this.onAction('add_device');
          }
        })
      }
    }
  }

  /**
   * The empty list is the very same row the populated list uses, only with different
   * text, and it opens whatever fixes the empty state.
   */
  @Builder
  private buildPlaceholderDeviceRow() {
    SettingsNavigationRow({
      title: localizeCrossDeviceLinkCopy(this.state.devicesPlaceholderTitle),
      description: localizeCrossDeviceLinkCopy(this.state.devicesPlaceholderDetail),
      airaIconId: DEVICE_GLYPH,
      iconBackgroundColor: this.settingsIconBackgrounds.userAgent,
      iconColor: this.storedSettingsIconForegroundColor,
      rowPosition: 'middle',
      isEnabled: !this.isBusy,
      primaryTextColor: this.storedPrimaryTextColor,
      secondaryTextColor: this.storedSecondaryTextColor,
      pressedBackgroundColor: this.storedPressedBackgroundColor,
      desktopPresentation: this.desktopPresentation,
      onAction: (): void => {
        this.onAction(this.state.devicesPlaceholderAction);
      }
    })
  }

  /**
   * The recipe lives one level down, so the overview stays a status page.
   */
  @Builder
  private buildSetupSection() {
    SettingsSection({
      title: $r('app.string.settings_link_setup_section'),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      SettingsGroupCard({
        surfaceColor: this.storedSurfaceBackgroundColor,
        desktopPresentation: this.desktopPresentation
      }) {
        SettingsNavigationRow({
          title: $r('app.string.settings_link_tutorial'),
          value: $r('app.string.settings_link_view_steps'),
          airaIconId: EXTENSION_GLYPH,
          iconBackgroundColor: this.settingsIconBackgrounds.siteCustomization,
          iconColor: this.storedSettingsIconForegroundColor,
          rowPosition: 'single',
          isEnabled: !this.isBusy,
          primaryTextColor: this.storedPrimaryTextColor,
          secondaryTextColor: this.storedSecondaryTextColor,
          pressedBackgroundColor: this.storedPressedBackgroundColor,
          desktopPresentation: this.desktopPresentation,
          onAction: (): void => {
            this.onOpenSetup();
          }
        })
      }
    }
  }

  @Builder
  private buildSelfHostedSection() {
    SettingsSection({
      title: localizeCrossDeviceLinkCopy(this.state.selfHostedSectionTitle),
      secondaryTextColor: this.storedSecondaryTextColor
    }) {
      SettingsGroupCard({
        surfaceColor: this.storedSurfaceBackgroundColor,
        desktopPresentation: this.desktopPresentation
      }) {
        SettingsNavigationRow({
          title: localizeCrossDeviceLinkCopy(this.state.selfHostedTitle),
          airaIconId: SELF_HOSTED_GLYPH,
          iconBackgroundColor: this.syncProviderIconBackgrounds.webdav,
          iconColor: this.storedSettingsIconForegroundColor,
          rowPosition: 'single',
          isEnabled: !this.isBusy,
          primaryTextColor: this.storedPrimaryTextColor,
          secondaryTextColor: this.storedSecondaryTextColor,
          pressedBackgroundColor: this.storedPressedBackgroundColor,
          desktopPresentation: this.desktopPresentation,
          onAction: (): void => {
            this.onAction(this.state.selfHostedAction);
          }
        })
      }

      this.buildSectionFooter(localizeCrossDeviceLinkCopy(this.state.selfHostedFooter))
    }
  }

  @Builder
  private buildSectionFooter(text: ResourceStr) {
    Text(text)
      .width('100%')
      .fontSize(13)
      .lineHeight(19)
      .fontColor(this.storedSecondaryTextColor)
      .padding({ left: 4, right: 4 })
  }

  @Builder
  private buildBrowserBrandLeading(kind: CrossDeviceBrowserIconKind) {
    Stack({ alignContent: Alignment.Center }) {
      Image(CrossDeviceBrowserIconResources.icon(kind))
        .width(DEVICE_BROWSER_ICON_SIZE)
        .height(DEVICE_BROWSER_ICON_SIZE)
        .objectFit(ImageFit.Contain)
    }
    .width(DEVICE_BROWSER_ICON_SLOT)
    .height(DEVICE_BROWSER_ICON_SLOT)
  }

  private resolveRowPosition(index: number, total: number): SettingsRowPosition {
    if (total <= 1) {
      return 'single';
    }
    if (index === 0) {
      return 'first';
    }
    return index === total - 1 ? 'last' : 'middle';
  }
}
