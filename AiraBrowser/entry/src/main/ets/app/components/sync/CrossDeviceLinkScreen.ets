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
  CROSS_DEVICE_LINK_MARQUEE_GAP,
  CROSS_DEVICE_LINK_MARQUEE_RADIUS,
  CROSS_DEVICE_LINK_MARQUEE_ROW_GAP,
  CROSS_DEVICE_LINK_MARQUEE_TILE,
  crossDeviceLinkMarqueeDistance,
  crossDeviceLinkMarqueeDurationMs,
  crossDeviceLinkMarqueeTiles,
  CrossDeviceLinkMarqueeTile
} from '../../../core/sync/CrossDeviceLinkMarqueeLayout';
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
  @State private marqueeOffset0: number = 0;
  @State private marqueeOffset1: number = -crossDeviceLinkMarqueeDistance();
  private marqueeStarted: boolean = false;
  private marqueeAlive: boolean = true;

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
        SettingsPresentationScrollBody({
          desktopPresentation: this.desktopPresentation,
          expandToParent: true,
          contentSpace: 0,
          topPadding: 0,
          bottomPadding: 28,
          scroller: this.contentScroller
        }) {
          this.buildMarquee()
          this.buildScrollingCover()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.storedPageBackgroundColor)
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
   * Two rows of the other browsers, same rounded-rectangle size. The top row
   * travels left and the bottom row travels right. Each track is painted twice
   * so resetting at one copy width does not jump.
   */
  @Builder
  private buildMarquee() {
    Column({ space: CROSS_DEVICE_LINK_MARQUEE_ROW_GAP }) {
      this.buildMarqueeRow(0)
      this.buildMarqueeRow(1)
    }
    .width('100%')
    .padding({ top: 20, bottom: 12 })
    .hitTestBehavior(HitTestMode.None)
    .onAppear((): void => {
      this.startMarquee();
    })
  }

  @Builder
  private buildMarqueeRow(rowIndex: number) {
    Stack({ alignContent: Alignment.Start }) {
      Row() {
        ForEach(crossDeviceLinkMarqueeTiles(rowIndex), (tile: CrossDeviceLinkMarqueeTile) => {
          this.buildMarqueeTile(tile.kind)
        }, (tile: CrossDeviceLinkMarqueeTile): string => tile.key)
      }
      .translate({ x: this.resolveMarqueeOffset(rowIndex) })

      Column()
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .linearGradient({
          direction: GradientDirection.Right,
          colors: [
            [Color.Transparent, 0],
            [Color.Black, 0.08],
            [Color.Black, 0.92],
            [Color.Transparent, 1]
          ]
        })
        .blendMode(BlendMode.DST_IN, BlendApplyType.OFFSCREEN)
    }
    .width('100%')
    .height(CROSS_DEVICE_LINK_MARQUEE_TILE)
    .clip(true)
    .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
  }

  @Builder
  private buildMarqueeTile(kind: CrossDeviceBrowserIconKind) {
    Stack({ alignContent: Alignment.Center }) {
      Image(CrossDeviceBrowserIconResources.icon(kind))
        .width(CROSS_DEVICE_LINK_MARQUEE_TILE * 0.62)
        .height(CROSS_DEVICE_LINK_MARQUEE_TILE * 0.62)
        .objectFit(ImageFit.Contain)
    }
    .width(CROSS_DEVICE_LINK_MARQUEE_TILE)
    .height(CROSS_DEVICE_LINK_MARQUEE_TILE)
    .margin({ right: CROSS_DEVICE_LINK_MARQUEE_GAP })
    .borderRadius(CROSS_DEVICE_LINK_MARQUEE_RADIUS)
    .backgroundColor(this.storedSurfaceBackgroundColor)
    .borderWidth(this.storedResolvedThemeMode === 'dark' ? 1 : 0)
    .borderColor(this.storedDividerColor)
    .clip(true)
  }

  aboutToDisappear(): void {
    this.marqueeAlive = false;
  }

  private resolveMarqueeOffset(rowIndex: number): number {
    return rowIndex === 0 ? this.marqueeOffset0 : this.marqueeOffset1;
  }

  private startMarquee(): void {
    this.marqueeAlive = true;
    if (this.marqueeStarted) {
      return;
    }
    this.marqueeStarted = true;
    this.marqueeOffset1 = -crossDeviceLinkMarqueeDistance();
    this.advanceMarquee(0);
    this.advanceMarquee(1);
  }

  /**
   * A full copy width lands on the same tiles, so restarting there does not jump.
   * The left row runs toward negative x. The right row runs back toward zero.
   */
  private advanceMarquee(rowIndex: number): void {
    if (!this.marqueeAlive) {
      return;
    }
    const distance = crossDeviceLinkMarqueeDistance();
    const from = rowIndex === 0 ? 0 : -distance;
    const to = rowIndex === 0 ? -distance : 0;
    this.setMarqueeOffset(rowIndex, from);
    animateTo({
      duration: crossDeviceLinkMarqueeDurationMs(rowIndex),
      curve: Curve.Linear,
      onFinish: (): void => {
        this.advanceMarquee(rowIndex);
      }
    }, (): void => {
      this.setMarqueeOffset(rowIndex, to);
    });
  }

  private setMarqueeOffset(rowIndex: number, offset: number): void {
    if (rowIndex === 0) {
      this.marqueeOffset0 = offset;
    } else {
      this.marqueeOffset1 = offset;
    }
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
    // No heading of its own: the rows are the devices, and a 在线设备 title only repeated
    // what the surrounding section already said.
    SettingsSection({
      title: '',
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
