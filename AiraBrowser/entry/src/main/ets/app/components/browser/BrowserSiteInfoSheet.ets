import { DEFAULT_THEME_PALETTE } from '../../../features/theme/palettes/DefaultThemePalette';
import {
  SitePermissionKind,
  SitePermissionRule
} from '../../../common/models/BrowserModels';
import { curves } from '@kit.ArkUI';
import { i18n } from '@kit.LocalizationKit';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_CONTROL_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_DIVIDER_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../../core/theme/BrowserThemeStorageKeys';
import {
  BROWSER_FEATURE_SHEET_HEADER_BUTTON_SIZE,
  BROWSER_FEATURE_SHEET_HEADER_ICON_SIZE,
  BROWSER_IMMERSIVE_SHEET_HEADER_CONTENT_TOP_INSET,
  BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING,
  BROWSER_SHEET_MODAL_HEADER_BUTTON_TOP,
  resolveBrowserSheetHeaderBlurRadius,
  BrowserBottomSheetSurface,
  BrowserFeatureSheetHeader,
  BrowserImmersiveSheetLayout,
  BrowserSheetActionButton,
  BrowserSheetIconButton,
  browserSheetHeaderBlurModifier
} from './BrowserModalBottomSheet';
import {
  SettingsNavigationRow,
  SettingsOptionRow,
  SettingsRowPosition,
  SettingsStaticValueRow,
  SettingsSwitchRow
} from '../settings/SettingsRows';
import {
  SettingsGroupCard,
  SettingsGroupDivider
} from '../settings/SettingsLayout';
import {
  SiteCapabilityCatalogService,
  SitePermissionRuleOption
} from '../../../services/web/SiteCapabilityCatalogService';
import { resolveAppResourceText } from '../../../core/resources/AppResourceText';
import {
  BrowserSiteControlsApplicationSnapshot,
  BrowserSiteControlsUserAction,
  DEFAULT_BROWSER_SITE_CONTROLS_APPLICATION_SNAPSHOT
} from '../../../core/browser/BrowserSiteControlsRuntimeCoordinator';
const SITE_INFO_SHEET_MAX_WIDTH: number = 560;
const SITE_SECURITY_METRIC_VALUE_FONT_SIZE: number = 34;
const SITE_SECURITY_METRIC_UNIT_FONT_SIZE: number = 12;
const SITE_INFO_PAGE_TRANSITION_RESPONSE: number = 0.34;
const SITE_INFO_PAGE_TRANSITION_DAMPING: number = 0.84;
const SITE_INFO_PERMISSION_RADIO_GROUP: string = 'site-info-permission-rule';
const SITE_INFO_CONTENT_TOP_PADDING: number = BROWSER_IMMERSIVE_SHEET_HEADER_CONTENT_TOP_INSET;
const SITE_INFO_CONTENT_BOTTOM_PADDING: number = 84;

@Component
export struct BrowserSiteInfoSheet {
  private capabilityCatalog: SiteCapabilityCatalogService = new SiteCapabilityCatalogService();
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_CONTROL_BACKGROUND_KEY) private storedControlBackgroundColor: string = '#EEF2F6';
  @StorageProp(BROWSER_THEME_STORAGE_DIVIDER_KEY) private storedDividerColor: string = '#E3E8EF';
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string = DEFAULT_THEME_PALETTE.light.pageBackground;
  @StorageProp(BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY) private storedPressedBackgroundColor: string = '#DDE4EC';
  @StorageProp(BROWSER_THEME_STORAGE_SURFACE_BACKGROUND_KEY) private storedSurfaceBackgroundColor: string = '#FFFFFF';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  @Prop snapshot: BrowserSiteControlsApplicationSnapshot = DEFAULT_BROWSER_SITE_CONTROLS_APPLICATION_SNAPSHOT;
  onAction: (
    action: BrowserSiteControlsUserAction,
    permissionKind?: SitePermissionKind,
    permissionRule?: SitePermissionRule
  ) => void = (_action: BrowserSiteControlsUserAction) => {};
  @State private sheetHeaderBlurRadius: number = 0;
  @State private sheetScrollOffset: number = 0;

  build() {
    BrowserBottomSheetSurface({
      fullHeight: true,
      maxWidth: SITE_INFO_SHEET_MAX_WIDTH,
      horizontalPadding: 0,
      topPadding: 0,
      bottomPadding: 0,
      surfaceColor: this.storedPageBackgroundColor
    }) {
      Column() {
        this.buildPageHost()
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  private buildPageHost() {
    Stack({ alignContent: Alignment.Top }) {
      ForEach([this.resolvePageKey()], (pageKey: string) => {
        this.buildPage(this.resolvePageTransition())
      }, (pageKey: string) => pageKey)

      this.buildFixedCloseButton()
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }

  @Builder
  private buildFixedCloseButton() {
    Stack({ alignContent: Alignment.TopEnd }) {
      BrowserSheetIconButton({
        icon: $r('sys.symbol.xmark'),
        iconSize: BROWSER_FEATURE_SHEET_HEADER_ICON_SIZE,
        buttonSize: BROWSER_FEATURE_SHEET_HEADER_BUTTON_SIZE,
        accessibilityLabel: $r('app.string.settings_site_info_close'),
        immersiveMaterialEnabled: true,
        onAction: (): void => {
          this.onAction('close');
        }
      })
        .margin({ top: BROWSER_SHEET_MODAL_HEADER_BUTTON_TOP, right: 16 })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
    .zIndex(4)
  }

  @Builder
  private buildPage(pageTransition: TransitionEffect) {
    Stack() {
      BrowserImmersiveSheetLayout({
        footerVisible: this.shouldShowPageFooter(),
        scrollContent: () => {
          this.buildActivePageContent()
        },
        header: () => {
          this.buildFeatureHeader(this.resolveFeatureHeaderTitle(), this.isFeaturePageNested())
        },
        footer: () => {
          this.buildActivePageFooter()
        }
      })
    }
    .width('100%')
    .height('100%')
    .transition(pageTransition)
  }

  @Builder
  private buildActivePageContent() {
    if (this.snapshot.session.mode === 'security') {
      this.buildSecurityReportContent()
    } else if (this.snapshot.session.mode === 'certificate') {
      this.buildCertificateDetailList()
    } else if (this.snapshot.session.mode === 'adblock_log') {
      this.buildAdBlockLogContent()
    } else if (this.isPermissionPageMode(this.snapshot.session.mode)) {
      this.buildPermissionOptionList(this.resolvePermissionKindFromMode(this.snapshot.session.mode))
    } else {
      this.buildOverviewList()
    }
  }

  @Builder
  private buildActivePageFooter() {
    if (this.snapshot.session.mode === 'security') {
      this.buildSecurityReportActions()
    } else if (this.snapshot.session.mode === 'certificate') {
      this.buildSinglePrimaryAction($r('app.string.settings_site_info_done'))
    }
  }

  private sheetBlurScroller0: Scroller = new Scroller();
  private sheetBlurScroller1: Scroller = new Scroller();
  private sheetBlurScroller2: Scroller = new Scroller();
  private sheetBlurScroller3: Scroller = new Scroller();
  private sheetBlurScroller4: Scroller = new Scroller();

  private noteSheetScrollOffset(offset: number): void {
    if (!Number.isFinite(offset)) {
      return;
    }
    const next = Math.max(0, offset);
    if (next === this.sheetScrollOffset) {
      return;
    }
    this.sheetScrollOffset = next;
    this.sheetHeaderBlurRadius = resolveBrowserSheetHeaderBlurRadius(next);
  }

  private resetSheetHeaderBlur(): void {
    this.sheetScrollOffset = 0;
    this.sheetHeaderBlurRadius = 0;
  }

  private resolvePageKey(): string {
    return this.snapshot.session.mode.length > 0 ? this.snapshot.session.mode : 'overview';
  }

  private resolvePageTransition(): TransitionEffect {
    if (this.snapshot.session.navigationDirection === 'backward') {
      return TransitionEffect.move(TransitionEdge.START)
        .animation({ curve: curves.springMotion(SITE_INFO_PAGE_TRANSITION_RESPONSE, SITE_INFO_PAGE_TRANSITION_DAMPING) });
    }
    if (this.snapshot.session.navigationDirection === 'forward') {
      return TransitionEffect.move(TransitionEdge.END)
        .animation({ curve: curves.springMotion(SITE_INFO_PAGE_TRANSITION_RESPONSE, SITE_INFO_PAGE_TRANSITION_DAMPING) });
    }
    return TransitionEffect.OPACITY.animation({ duration: 1 });
  }

  @Builder
  private buildFeatureHeader(title: ResourceStr, nested: boolean) {
    BrowserFeatureSheetHeader({
      title: title,
      titleColor: this.storedPrimaryTextColor,
      showLeadingButton: nested,
      leadingAccessibilityLabel: $r('app.string.settings_site_info_back'),
      onLeadingAction: (): void => {
        this.onAction('navigate_back');
      }
    })
  }

  @Builder
  private buildSecurityReportContent() {
    List({ scroller: this.sheetBlurScroller0, space: 12 }) {
      ListItem() {
        this.buildSecurityMetricRow()
      }

      ListItem() {
        Text($r('app.string.settings_site_info_protection_note'))
          .width('100%')
          .padding({ left: 4, right: 4 })
          .fontSize(12)
          .lineHeight(18)
          .fontColor(this.storedSecondaryTextColor)
      }

      ListItem() {
        this.buildSecurityNavigationGroup()
      }

      ListItem() {
        this.buildSecurityProtectionSwitchGroup()
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      left: 16,
      right: 16
    })
    .contentStartOffset(SITE_INFO_CONTENT_TOP_PADDING)
    .contentEndOffset(this.resolveContentBottomOffset())
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .clip(false)
    .attributeModifier(browserSheetHeaderBlurModifier(this.sheetHeaderBlurRadius))
    .onAppear(() => {
      this.resetSheetHeaderBlur();
    })
    .onDidScroll((scrollOffset: number) => {
      this.noteSheetScrollOffset(this.sheetBlurScroller0.currentOffset().yOffset);
    })
  }

  @Builder
  private buildSecurityNavigationGroup() {
    SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
      SettingsNavigationRow({
        title: $r('app.string.settings_site_info_connection'),
        value: this.snapshot.connectionTitle,
        icon: this.snapshot.isSecureSite ? $r('sys.symbol.lock_fill') : $r('sys.symbol.exclamationmark_triangle_fill'),
        iconBackgroundColor: this.storedControlBackgroundColor,
        iconColor: this.snapshot.isSecureSite ? this.storedAccentColor : this.storedSecondaryTextColor,
        rowPosition: 'first',
        primaryTextColor: this.storedPrimaryTextColor,
        secondaryTextColor: this.storedSecondaryTextColor,
        pressedBackgroundColor: this.storedPressedBackgroundColor,
        onAction: () => {
          this.onAction('open_certificate');
        }
      })
      SettingsGroupDivider({ dividerColor: this.storedDividerColor })
      SettingsNavigationRow({
        title: $r('app.string.settings_site_info_content_filter'),
        value: this.getProtectionSummaryText(),
        icon: $r('sys.symbol.shield_checkered'),
        iconBackgroundColor: this.storedControlBackgroundColor,
        iconColor: this.storedAccentColor,
        rowPosition: 'middle',
        primaryTextColor: this.storedPrimaryTextColor,
        secondaryTextColor: this.storedSecondaryTextColor,
        pressedBackgroundColor: this.storedPressedBackgroundColor,
        onAction: () => {
          this.onAction('open_protection_log');
        }
      })
      SettingsGroupDivider({ dividerColor: this.storedDividerColor })
      SettingsNavigationRow({
        title: $r('app.string.settings_site_info_tracking_protection'),
        value: this.snapshot.trackingProtectionSummary,
        airaIconId: 'settings.privacySecurity',
        iconBackgroundColor: this.storedControlBackgroundColor,
        iconColor: this.snapshot.trackingProtectionEnhanced ? this.storedAccentColor : this.storedSecondaryTextColor,
        rowPosition: 'middle',
        primaryTextColor: this.storedPrimaryTextColor,
        secondaryTextColor: this.storedSecondaryTextColor,
        pressedBackgroundColor: this.storedPressedBackgroundColor,
        onAction: () => {
          this.onAction('open_tracking_protection_settings');
        }
      })
      SettingsGroupDivider({ dividerColor: this.storedDividerColor })
      SettingsNavigationRow({
        title: $r('app.string.settings_site_info_site_settings'),
        value: '',
        icon: $r('sys.symbol.person_shield_fill'),
        iconBackgroundColor: this.storedControlBackgroundColor,
        iconColor: this.storedAccentColor,
        rowPosition: 'last',
        primaryTextColor: this.storedPrimaryTextColor,
        secondaryTextColor: this.storedSecondaryTextColor,
        pressedBackgroundColor: this.storedPressedBackgroundColor,
        onAction: () => {
          this.onAction('open_site_customization');
        }
      })
    }
  }

  @Builder
  private buildSecurityProtectionSwitchGroup() {
    SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
      SettingsSwitchRow({
        title: $r('app.string.settings_site_info_site_protection_switch'),
        checked: this.snapshot.session.protection.siteEnabled,
        isEnabled: this.snapshot.session.protection.siteToggleEnabled,
        rowPosition: 'single',
        primaryTextColor: this.storedPrimaryTextColor,
        secondaryTextColor: this.storedSecondaryTextColor,
        pressedBackgroundColor: this.storedPressedBackgroundColor,
        onChange: (_checked: boolean) => {
          this.onAction('toggle_protection');
        }
      })
    }
  }

  @Builder
  private buildSecurityMetricRow() {
    Row({ space: 8 }) {
      this.buildSecurityMetricCard(
        this.formatMetricCount(this.resolveSecurityBlockedCount()), '', $r('app.string.settings_site_info_metric_page')
      )
      this.buildSecurityMetricCard(
        this.formatMetricCount(this.snapshot.todayProtectionActionCount), '', $r('app.string.settings_site_info_metric_today')
      )
      this.buildSecurityMetricCard(
        this.formatMetricCount(this.snapshot.sevenDayProtectionActionCount), '', $r('app.string.settings_site_info_metric_week')
      )
    }
    .width('100%')
  }

  @Builder
  private buildSecurityMetricCard(value: ResourceStr, unit: string, label: ResourceStr) {
    Column({ space: 4 }) {
      Row({ space: 2 }) {
        Text(value)
          .fontSize(SITE_SECURITY_METRIC_VALUE_FONT_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.storedPrimaryTextColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)

        if (unit.length > 0) {
          Text(unit)
            .fontSize(SITE_SECURITY_METRIC_UNIT_FONT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.storedSecondaryTextColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Bottom)

      Text(label)
        .width('100%')
        .fontSize(12)
        .fontColor(this.storedSecondaryTextColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .height(82)
    .padding({ top: 12, bottom: 10, left: 4, right: 4 })
    .backgroundColor(this.storedSurfaceBackgroundColor)
    .borderRadius(16)
  }

  @Builder
  private buildSecurityReportActions() {
    Column({ space: 8 }) {
      BrowserSheetActionButton({
        label: $r('app.string.settings_site_info_action_overview'),
        emphasis: 'primary',
        stacked: true,
        accentColor: this.storedAccentColor,
        onAction: () => {
          this.onAction('open_overview');
        }
      })

      BrowserSheetActionButton({
        label: $r('app.string.settings_site_info_action_log'),
        emphasis: 'ghost',
        stacked: true,
        onAction: () => {
          this.onAction('open_protection_log');
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildOverviewList() {
    List({ scroller: this.sheetBlurScroller1, space: 14 }) {
      if (this.snapshot.isPrivateMode) {
        ListItem() {
          this.buildPrivateSessionGroup()
        }
      }

      ListItem() {
        this.buildProtectionActionMetric()
      }

      ListItem() {
        this.buildProtectionCategoryGroup()
      }

      ListItem() {
        this.buildOverviewNavigationGroup()
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      left: 16,
      right: 16
    })
    .contentStartOffset(SITE_INFO_CONTENT_TOP_PADDING)
    .contentEndOffset(this.resolveContentBottomOffset())
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .clip(false)
    .attributeModifier(browserSheetHeaderBlurModifier(this.sheetHeaderBlurRadius))
    .onAppear(() => {
      this.resetSheetHeaderBlur();
    })
    .onDidScroll((scrollOffset: number) => {
      this.noteSheetScrollOffset(this.sheetBlurScroller1.currentOffset().yOffset);
    })
  }

  @Builder
  private buildPrivateSessionGroup() {
    SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
      SettingsStaticValueRow({
        title: $r('app.string.settings_site_info_private_session_only'),
        value: '',
        rowPosition: 'single',
        primaryTextColor: this.storedPrimaryTextColor,
        secondaryTextColor: this.storedSecondaryTextColor
      })
    }
  }

  @Builder
  private buildProtectionActionMetric() {
    Column({ space: 5 }) {
      Text(`${this.snapshot.session.protection.blockedCount}`)
        .width('100%')
        .fontSize(40)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.storedPrimaryTextColor)
        .textAlign(TextAlign.Center)

      Text(this.getProtectionActionMetricLabel())
        .width('100%')
        .fontSize(13)
        .fontColor(this.storedSecondaryTextColor)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 18, bottom: 18 })
    .backgroundColor(this.storedSurfaceBackgroundColor)
    .borderRadius(18)
  }

  @Builder
  private buildProtectionCategoryGroup() {
    SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
      SettingsStaticValueRow({
        title: $r('app.string.settings_site_info_request_blocking'),
        value: `${this.snapshot.session.protection.requestBlockingCount}`,
        rowPosition: 'first',
        primaryTextColor: this.storedPrimaryTextColor,
        secondaryTextColor: this.storedSecondaryTextColor
      })
      SettingsGroupDivider({ dividerColor: this.storedDividerColor })
      SettingsStaticValueRow({
        title: $r('app.string.settings_site_info_link_cleaning'),
        value: `${this.snapshot.session.protection.linkCleaningCount}`,
        rowPosition: 'middle',
        primaryTextColor: this.storedPrimaryTextColor,
        secondaryTextColor: this.storedSecondaryTextColor
      })
      SettingsGroupDivider({ dividerColor: this.storedDividerColor })
      SettingsStaticValueRow({
        title: $r('app.string.settings_site_info_element_hiding'),
        value: `${this.snapshot.session.protection.elementHidingCount}`,
        rowPosition: 'last',
        primaryTextColor: this.storedPrimaryTextColor,
        secondaryTextColor: this.storedSecondaryTextColor
      })
    }
  }

  @Builder
  private buildPermissionGroup() {
    SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
      ForEach(this.listPermissionKinds(), (kind: SitePermissionKind, index: number) => {
        this.buildPermissionRow(kind, this.getPermissionKindLabel(kind), index, this.listPermissionKinds().length)
        if (index < this.listPermissionKinds().length - 1) {
          SettingsGroupDivider({ dividerColor: this.storedDividerColor })
        }
      }, (kind: SitePermissionKind) => kind)
    }
  }

  @Builder
  private buildPermissionRow(kind: SitePermissionKind, title: ResourceStr, index: number, total: number) {
    SettingsNavigationRow({
      title: title,
      value: this.getPermissionRuleLabel(kind),
      description: this.getPermissionRuleDescription(kind),
      rowPosition: this.resolveRowPosition(index, total),
      primaryTextColor: this.storedPrimaryTextColor,
      secondaryTextColor: this.storedSecondaryTextColor,
      pressedBackgroundColor: this.storedPressedBackgroundColor,
      onAction: () => {
        this.onAction('open_permission', kind);
      }
    })
  }

  @Builder
  private buildPermissionOptionList(kind: SitePermissionKind) {
    Scroll(this.sheetBlurScroller2) {
      Column({ space: 12 }) {
        SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
          ForEach(this.getPermissionOptions(kind), (option: SitePermissionRuleOption, index: number) => {
            this.buildPermissionOptionRow(kind, option, index, 3)
            if (index < 2) {
              SettingsGroupDivider({ dividerColor: this.storedDividerColor })
            }
          }, (option: SitePermissionRuleOption) => `${kind}:${option.value}:${this.getPermissionRule(kind) === option.value ? 'selected' : 'idle'}`)
        }
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({
        left: 16,
        right: 16,
        top: SITE_INFO_CONTENT_TOP_PADDING,
        bottom: BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .clip(false)
    .attributeModifier(browserSheetHeaderBlurModifier(this.sheetHeaderBlurRadius))
    .onAppear(() => {
      this.resetSheetHeaderBlur();
    })
    .onDidScroll((_xOffset: number, yOffset: number) => {
      this.noteSheetScrollOffset(this.sheetBlurScroller2.currentOffset().yOffset);
    })
  }

  @Builder
  private buildPermissionOptionRow(kind: SitePermissionKind, option: SitePermissionRuleOption, index: number, total: number) {
    SettingsOptionRow({
      title: option.label,
      helperText: option.helperText,
      rowPosition: this.resolveRowPosition(index, total),
      isSelected: this.getPermissionRule(kind) === option.value,
      isEnabled: true,
      radioGroup: `${SITE_INFO_PERMISSION_RADIO_GROUP}-${kind}`,
      radioValue: option.value,
      primaryTextColor: this.storedPrimaryTextColor,
      secondaryTextColor: this.storedSecondaryTextColor,
      pressedBackgroundColor: this.storedPressedBackgroundColor,
      selectedIndicatorColor: this.storedAccentColor,
      onAction: (): void => {
        this.selectPermissionRule(kind, option.value);
      }
    })
  }

  @Builder
  private buildSiteDataGroup() {
    Column({ space: 8 }) {
      SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
        SettingsStaticValueRow({
          title: $r('app.string.settings_site_info_site_data'),
          value: this.snapshot.siteDataSummary,
          rowPosition: 'first',
          primaryTextColor: this.storedPrimaryTextColor,
          secondaryTextColor: this.storedSecondaryTextColor
        })
        SettingsGroupDivider({ dividerColor: this.storedDividerColor })
        SettingsNavigationRow({
          title: this.snapshot.isPrivateMode
            ? $r('app.string.settings_site_info_manage_private_data')
            : $r('app.string.settings_site_info_manage_all_data'),
          value: '',
          rowPosition: 'last',
          primaryTextColor: this.storedPrimaryTextColor,
          secondaryTextColor: this.storedSecondaryTextColor,
          pressedBackgroundColor: this.storedPressedBackgroundColor,
          onAction: () => {
            this.onAction('open_browsing_data_settings');
          }
        })
      }

      Text(this.snapshot.isPrivateMode
        ? $r('app.string.settings_site_info_private_storage_note')
        : $r('app.string.settings_site_info_storage_note'))
        .width('100%')
        .padding({ left: 4, right: 4 })
        .fontSize(12)
        .fontColor(this.storedSecondaryTextColor)

      Row() {
        BrowserSheetActionButton({
          label: $r('app.string.settings_site_info_clear_storage'),
          emphasis: 'destructive',
          actionEnabled: this.snapshot.canClearCurrentSiteStorage,
          onAction: () => {
            this.onAction('clear_site_data');
          }
        })
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private buildOverviewNavigationGroup() {
    Column({ space: 8 }) {
      SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
        SettingsNavigationRow({
          title: $r('app.string.settings_site_info_privacy_protection'),
          value: this.getPrivacyCoverageValue(),
          rowPosition: 'first',
          primaryTextColor: this.storedPrimaryTextColor,
          secondaryTextColor: this.storedSecondaryTextColor,
          pressedBackgroundColor: this.storedPressedBackgroundColor,
          onAction: () => {
            this.onAction('open_protection_settings');
          }
        })
        SettingsGroupDivider({ dividerColor: this.storedDividerColor })
        SettingsSwitchRow({
          title: this.snapshot.isPrivateMode
            ? $r('app.string.settings_site_info_site_protection_private')
            : $r('app.string.settings_site_info_site_protection'),
          checked: this.snapshot.session.protection.siteEnabled,
          isEnabled: this.snapshot.session.protection.siteToggleEnabled,
          rowPosition: 'middle',
          primaryTextColor: this.storedPrimaryTextColor,
          secondaryTextColor: this.storedSecondaryTextColor,
          pressedBackgroundColor: this.storedPressedBackgroundColor,
          onChange: (_checked: boolean) => {
            this.onAction('toggle_protection');
          }
        })
        SettingsGroupDivider({ dividerColor: this.storedDividerColor })
      SettingsNavigationRow({
          title: $r('app.string.settings_site_info_protection_summary'),
          value: $r('app.string.settings_site_info_item_count', this.snapshot.session.protection.blockedCount),
          rowPosition: 'middle',
          primaryTextColor: this.storedPrimaryTextColor,
          secondaryTextColor: this.storedSecondaryTextColor,
          pressedBackgroundColor: this.storedPressedBackgroundColor,
          onAction: () => {
            this.onAction('open_protection_log');
          }
        })
        SettingsGroupDivider({ dividerColor: this.storedDividerColor })
        SettingsNavigationRow({
          title: $r('app.string.settings_site_info_connection_certificate'),
          value: this.snapshot.connectionTitle,
          rowPosition: 'middle',
          primaryTextColor: this.storedPrimaryTextColor,
          secondaryTextColor: this.storedSecondaryTextColor,
          pressedBackgroundColor: this.storedPressedBackgroundColor,
          onAction: () => {
            this.onAction('open_certificate');
          }
        })
        SettingsGroupDivider({ dividerColor: this.storedDividerColor })
        SettingsNavigationRow({
          title: $r('app.string.settings_site_info_site_settings'),
          value: $r('app.string.settings_site_info_site_settings_value'),
          rowPosition: 'last',
          primaryTextColor: this.storedPrimaryTextColor,
          secondaryTextColor: this.storedSecondaryTextColor,
          pressedBackgroundColor: this.storedPressedBackgroundColor,
          onAction: () => {
            this.onAction('open_site_customization');
          }
        })
      }

      Text(this.snapshot.session.protection.privacyCoverageSummary)
        .width('100%')
        .padding({ left: 4, right: 4 })
        .fontSize(12)
        .fontColor(this.storedSecondaryTextColor)
    }
    .width('100%')
  }

  @Builder
  private buildAdBlockLogContent() {
    Scroll(this.sheetBlurScroller3) {
      Column({ space: 8 }) {
        SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
          this.buildAdBlockLogSummaryRow()
          SettingsGroupDivider({ dividerColor: this.storedDividerColor })
          SettingsStaticValueRow({
            title: $r('app.string.settings_site_info_request_blocking'),
            value: `${this.snapshot.session.protection.requestBlockingCount}`,
            rowPosition: 'middle',
            primaryTextColor: this.storedPrimaryTextColor,
            secondaryTextColor: this.storedSecondaryTextColor
          })
          SettingsGroupDivider({ dividerColor: this.storedDividerColor })
          SettingsStaticValueRow({
            title: $r('app.string.settings_site_info_link_cleaning'),
            value: `${this.snapshot.session.protection.linkCleaningCount}`,
            rowPosition: 'middle',
            primaryTextColor: this.storedPrimaryTextColor,
            secondaryTextColor: this.storedSecondaryTextColor
          })
          SettingsGroupDivider({ dividerColor: this.storedDividerColor })
          SettingsStaticValueRow({
            title: $r('app.string.settings_site_info_element_hiding'),
            value: `${this.snapshot.session.protection.elementHidingCount}`,
            rowPosition: 'last',
            primaryTextColor: this.storedPrimaryTextColor,
            secondaryTextColor: this.storedSecondaryTextColor
          })
        }

        Text($r('app.string.settings_site_info_log_note'))
          .width('100%')
          .padding({ left: 4, right: 4 })
          .fontSize(12)
          .fontColor(this.storedSecondaryTextColor)
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({
        left: 16,
        right: 16,
        top: SITE_INFO_CONTENT_TOP_PADDING,
        bottom: BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .clip(false)
    .attributeModifier(browserSheetHeaderBlurModifier(this.sheetHeaderBlurRadius))
    .onAppear(() => {
      this.resetSheetHeaderBlur();
    })
    .onDidScroll((_xOffset: number, yOffset: number) => {
      this.noteSheetScrollOffset(this.sheetBlurScroller3.currentOffset().yOffset);
    })
  }

  @Builder
  private buildAdBlockLogSummaryRow() {
    SettingsStaticValueRow({
      title: $r('app.string.settings_site_info_metric_actions'),
      value: `${this.snapshot.session.protection.blockedCount}`,
      rowPosition: 'first',
      primaryTextColor: this.storedPrimaryTextColor,
      secondaryTextColor: this.storedSecondaryTextColor
    })
  }

  private getProtectionHeaderTitle(): ResourceStr {
    const state = this.snapshot.session.protection.availabilityState;
    if (state === 'active_with_actions') {
      return this.snapshot.isPrivateMode
        ? $r('app.string.settings_site_info_header_protection_private')
        : $r('app.string.settings_site_info_header_protection_active');
    }
    if (state === 'active_without_actions') {
      return $r('app.string.settings_site_info_header_protection_enabled');
    }
    if (state === 'site_disabled') {
      return $r('app.string.settings_site_info_header_protection_site_off');
    }
    if (state === 'global_disabled_or_unconfigured') {
      return $r('app.string.settings_site_info_header_protection_unconfigured');
    }
    return $r('app.string.settings_site_info_header_protection_unavailable');
  }

  private getProtectionActionMetricLabel(): ResourceStr {
    const state = this.snapshot.session.protection.availabilityState;
    if (state === 'active_with_actions') {
      return $r('app.string.settings_site_info_metric_actions');
    }
    if (state === 'active_without_actions') {
      return $r('app.string.settings_site_info_metric_label_no_trigger');
    }
    if (state === 'site_disabled') {
      return $r('app.string.settings_site_info_metric_label_site_off');
    }
    if (state === 'global_disabled_or_unconfigured') {
      return $r('app.string.settings_site_info_metric_label_unconfigured');
    }
    return $r('app.string.settings_site_info_metric_label_unavailable');
  }

  private getPrivacyCoverageValue(): ResourceStr {
    if (this.snapshot.session.protection.privacyCoverageState === 'enabled') {
      return $r('app.string.settings_site_info_coverage_on');
    }
    if (this.snapshot.session.protection.privacyCoverageState === 'preparing') {
      return $r('app.string.settings_site_info_coverage_preparing');
    }
    if (this.snapshot.session.protection.privacyCoverageState === 'failed') {
      return $r('app.string.settings_site_info_coverage_attention');
    }
    if (this.snapshot.session.protection.privacyCoverageState === 'site_disabled') {
      return $r('app.string.settings_site_info_coverage_site_off');
    }
    if (this.snapshot.session.protection.privacyCoverageState === 'unavailable') {
      return $r('app.string.settings_site_info_coverage_unavailable');
    }
    return $r('app.string.settings_site_info_coverage_off');
  }


  @Builder
  private buildCertificateDetailList() {
    Scroll(this.sheetBlurScroller4) {
      Column() {
        SettingsGroupCard({ surfaceColor: this.storedSurfaceBackgroundColor }) {
          this.buildCertificateDetailRow(
            $r('app.string.settings_site_info_certificate_connection_status'),
            this.snapshot.session.certificate.detailStatus, 0, 9)
          SettingsGroupDivider({ dividerColor: this.storedDividerColor })
          this.buildCertificateDetailRow(
            $r('app.string.settings_site_info_certificate_site'), this.getSiteHostText(), 1, 9)
          SettingsGroupDivider({ dividerColor: this.storedDividerColor })
          this.buildCertificateDetailRow(
            $r('app.string.settings_site_info_certificate_subject'), this.snapshot.session.certificate.subject, 2, 9)
          SettingsGroupDivider({ dividerColor: this.storedDividerColor })
          this.buildCertificateDetailRow(
            $r('app.string.settings_site_info_certificate_issuer'), this.snapshot.session.certificate.issuer, 3, 9)
          SettingsGroupDivider({ dividerColor: this.storedDividerColor })
          this.buildCertificateDetailRow(
            $r('app.string.settings_site_info_certificate_valid_from'), this.snapshot.session.certificate.validFrom, 4, 9)
          SettingsGroupDivider({ dividerColor: this.storedDividerColor })
          this.buildCertificateDetailRow(
            $r('app.string.settings_site_info_certificate_valid_to'), this.snapshot.session.certificate.validTo, 5, 9)
          SettingsGroupDivider({ dividerColor: this.storedDividerColor })
          this.buildCertificateDetailRow(
            $r('app.string.settings_site_info_certificate_chain'), this.snapshot.certificateChainText, 6, 9)
          SettingsGroupDivider({ dividerColor: this.storedDividerColor })
          this.buildCertificateDetailRow(
            $r('app.string.settings_site_info_certificate_signature'), this.snapshot.session.certificate.signatureAlgorithm, 7, 9)
          SettingsGroupDivider({ dividerColor: this.storedDividerColor })
          this.buildCertificateDetailRow(
            $r('app.string.settings_site_info_certificate_serial'), this.snapshot.session.certificate.serialNumber, 8, 9)
        }
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({
        left: 16,
        right: 16,
        top: SITE_INFO_CONTENT_TOP_PADDING,
        bottom: SITE_INFO_CONTENT_BOTTOM_PADDING
      })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .clip(false)
    .attributeModifier(browserSheetHeaderBlurModifier(this.sheetHeaderBlurRadius))
    .onAppear(() => {
      this.resetSheetHeaderBlur();
    })
    .onDidScroll((_xOffset: number, yOffset: number) => {
      this.noteSheetScrollOffset(this.sheetBlurScroller4.currentOffset().yOffset);
    })
  }

  @Builder
  private buildCertificateDetailRow(label: ResourceStr, value: ResourceStr, index: number, total: number) {
    SettingsStaticValueRow({
      title: label,
      value: this.resolveDetailValue(value),
      valueMaxLines: 2,
      rowPosition: this.resolveRowPosition(index, total),
      primaryTextColor: this.storedPrimaryTextColor,
      secondaryTextColor: this.storedSecondaryTextColor
    })
  }

  @Builder
  private buildSinglePrimaryAction(label: ResourceStr) {
    Row() {
      BrowserSheetActionButton({
        label: label,
        emphasis: 'primary',
        accentColor: this.storedAccentColor,
        onAction: () => {
          this.onAction('close');
        }
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  private resolveFeatureHeaderTitle(): ResourceStr {
    if (this.snapshot.session.mode === 'security') {
      return this.snapshot.isSecureSite
        ? $r('app.string.settings_site_info_header_secure')
        : $r('app.string.settings_site_info_header_unverified');
    }
    if (this.snapshot.session.mode === 'certificate') {
      return $r('app.string.settings_site_info_header_certificate');
    }
    if (this.snapshot.session.mode === 'adblock_log') {
      return $r('app.string.settings_site_info_header_protection');
    }
    if (this.isPermissionPageMode(this.snapshot.session.mode)) {
      return this.resolvePermissionHeaderTitle(this.resolvePermissionKindFromMode(this.snapshot.session.mode));
    }
    return this.getProtectionHeaderTitle();
  }

  private isFeaturePageNested(): boolean {
    return this.snapshot.session.mode === 'certificate' || this.snapshot.session.mode === 'adblock_log' ||
      this.isPermissionPageMode(this.snapshot.session.mode);
  }

  private shouldShowPageFooter(): boolean {
    return this.snapshot.session.mode === 'security' || this.snapshot.session.mode === 'certificate';
  }

  private resolveContentBottomOffset(): number {
    return this.shouldShowPageFooter() ? SITE_INFO_CONTENT_BOTTOM_PADDING : BROWSER_SHEET_IMMERSIVE_BOTTOM_PADDING;
  }

  private getSiteHostText(): ResourceStr {
    return this.snapshot.siteHost.length > 0
      ? this.snapshot.siteHost
      : $r('app.string.settings_site_info_current_page');
  }

  private getProtectionSummaryText(): ResourceStr {
    const blockedCount = this.resolveSecurityBlockedCount();
    if (blockedCount > 0) {
      return $r('app.string.settings_site_info_blocked_count', blockedCount);
    }
    return this.snapshot.session.protection.summary;
  }

  /** 证书/站点明细里空值统一显示“暂无”，这里只对字符串做空判断，资源值原样透传。 */
  private resolveDetailValue(value: ResourceStr): ResourceStr {
    if (typeof value === 'string') {
      return value.length > 0 ? value : $r('app.string.settings_site_info_none');
    }
    return value;
  }

  private usesChineseNumberUnits(): boolean {
    return i18n.System.getSystemLanguage().toLowerCase().startsWith('zh');
  }

  private resolveSecurityBlockedCount(): number {
    return Math.max(0, Math.round(this.snapshot.session.protection.blockedCount));
  }

  private resolveGuardianDays(): number {
    return Math.max(0, Math.round(this.snapshot.siteGuardianDays));
  }

  /**
   * 中文习惯用「万 / 亿」缩写，其他语言直接给出原数值，避免把中文数量级单位带出去。
   */
  private formatMetricCount(value: number): ResourceStr {
    const normalized = Math.max(0, Math.floor(value));
    if (!this.usesChineseNumberUnits()) {
      return `${normalized}`;
    }
    if (normalized >= 100000000) {
      return $r('app.string.settings_site_info_metric_yi', Math.floor(normalized / 100000000));
    }
    if (normalized >= 10000) {
      const whole = Math.floor(normalized / 10000);
      const decimal = Math.floor((normalized % 10000) / 1000);
      return decimal > 0
        ? $r('app.string.settings_site_info_metric_wan_decimal', whole, decimal)
        : $r('app.string.settings_site_info_metric_wan', whole);
    }
    return `${normalized}`;
  }

  private getPermissionRule(kind: SitePermissionKind): SitePermissionRule {
    if (kind === 'camera') {
      return this.snapshot.session.permissionDraft.camera;
    }
    if (kind === 'microphone') {
      return this.snapshot.session.permissionDraft.microphone;
    }
    if (kind === 'location') {
      return this.snapshot.session.permissionDraft.location;
    }
    if (kind === 'sensor') {
      return this.snapshot.session.permissionDraft.sensor;
    }
    return this.snapshot.session.permissionDraft.clipboard;
  }

  private selectPermissionRule(kind: SitePermissionKind, rule: SitePermissionRule): void {
    if (this.getPermissionRule(kind) === rule) {
      return;
    }
    this.onAction('change_permission', kind, rule);
  }

  private listPermissionKinds(): SitePermissionKind[] {
    return this.capabilityCatalog.listDevicePermissionKinds();
  }

  private getPermissionRuleLabel(kind: SitePermissionKind): ResourceStr {
    return this.capabilityCatalog.getPermissionRuleLabel(this.getPermissionRule(kind));
  }

  private getPermissionRuleDescription(kind: SitePermissionKind): ResourceStr {
    return this.capabilityCatalog.getPermissionRuleDescription(kind, this.getPermissionRule(kind));
  }

  private getPermissionKindLabel(kind: SitePermissionKind): ResourceStr {
    return this.capabilityCatalog.getPermissionTitle(kind);
  }

  /** 权限页标题沿用「X 权限」的组合，权限名本身由能力目录提供。 */
  private resolvePermissionHeaderTitle(kind: SitePermissionKind): ResourceStr {
    return resolveAppResourceText(
      $r('app.string.settings_site_info_permission_header'),
      this.capabilityCatalog.getPermissionTitle(kind)
    );
  }

  private getPermissionOptions(kind: SitePermissionKind): SitePermissionRuleOption[] {
    return this.capabilityCatalog.buildSitePermissionOptions(kind);
  }

  private isPermissionPageMode(mode: string): boolean {
    return mode === 'permission_camera' || mode === 'permission_microphone' ||
      mode === 'permission_location' || mode === 'permission_sensor' || mode === 'permission_clipboard';
  }

  private resolvePermissionKindFromMode(mode: string): SitePermissionKind {
    return this.capabilityCatalog.resolvePermissionKind(mode.replace('permission_', ''));
  }

  private resolveRowPosition(index: number, total: number): SettingsRowPosition {
    if (total <= 1) {
      return 'single';
    }
    if (index === 0) {
      return 'first';
    }
    if (index === total - 1) {
      return 'last';
    }
    return 'middle';
  }
}


