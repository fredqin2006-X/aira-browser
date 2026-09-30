import {
  AiraProOverviewBenefitState,
  AiraProOverviewPlanState,
  AiraProOverviewReachableDeviceState,
  AiraProOverviewViewState
} from '../../../core/membership/AiraProOverviewViewModel';
import { AiraProReachableDeviceGlyph } from '../../../core/membership/AiraProBenefitCatalog';
import {
  BrowserSettingsIconBackgroundTokenSet,
  BrowserSyncProviderIconBackgroundTokenSet,
  DEFAULT_BROWSER_SETTINGS_ICON_BACKGROUND_TOKENS,
  DEFAULT_BROWSER_SYNC_PROVIDER_ICON_BACKGROUND_TOKENS
} from '../../../features/theme/BrowserThemePaletteModels';
import { AiraRenderableIconId } from '../../../core/resources/GeneratedAiraIconCatalog';
import { AiraIcon } from '../common/AiraIcon';
import { SettingsColoredIconBackground } from '../settings/SettingsColoredIconBackground';
import { display, PathShape } from '@kit.ArkUI';
import {
  SettingsGroupCard,
  SettingsGroupDivider,
  SettingsScrollBody
} from '../settings/SettingsLayout';

const AIRA_PRO_HERO_TITLE_FONT_SIZE: number = 30;
const AIRA_PRO_HERO_SUBTITLE_FONT_SIZE: number = 14;
const AIRA_PRO_HERO_LOGO_SIZE: number = 72;
const AIRA_PRO_HERO_LOGO_SOURCE_SIZE: number = 256;
const AIRA_PRO_HERO_LOGO_COMMANDS: string =
  'M127.525 0C144.898 0 161.459 3.47408 176.552 9.7651C171.337 28.7857 160.726 52.3519 126.484 56.4223C87.6908 56.9792 56.4149 88.5996 56.4149 127.525C56.4149 166.798 88.252 198.635 127.525 198.635C166.798 198.635 198.635 166.798 198.635 127.525C198.635 120.982 197.751 114.646 196.097 108.63C195.2 105.37 193.626 102.3 191.414 99.7431C165.304 69.5584 125.7 96.3208 127.52 115.27C124.138 90.1186 147.703 70.0632 155.88 62.2974C155.891 62.3002 155.902 62.3029 155.913 62.3058C164.283 53.0726 181.338 33.0318 176.665 9.81262C222.701 29.0531 255.05 74.511 255.05 127.525C255.05 197.955 197.955 255.05 127.525 255.05C57.0949 255.05 0 197.955 0 127.525C0 57.0949 57.0949 4.37031e-05 127.525 0Z';

const AIRA_PRO_DEVICE_CHIP_HEIGHT: number = 38;
const AIRA_PRO_DEVICE_CHIP_ICON_SIZE: number = 18;
const AIRA_PRO_DEVICE_CHIP_CORNER_RADIUS: number = 19;

const AIRA_PRO_BENEFIT_ICON_TILE_SIZE: number = 34;
const AIRA_PRO_BENEFIT_ICON_IMAGE_SIZE: number = 18;
const AIRA_PRO_BENEFIT_ROW_HORIZONTAL_PADDING: number = 14;
const AIRA_PRO_BENEFIT_ROW_VERTICAL_PADDING: number = 14;
const AIRA_PRO_BENEFIT_ROW_CORNER_RADIUS: number = 18;

const AIRA_PRO_PLAN_CARD_MIN_HEIGHT: number = 146;
const AIRA_PRO_PLAN_CARD_CORNER_RADIUS: number = 22;
const AIRA_PRO_PLAN_CARD_SELECTED_BORDER_WIDTH: number = 2;
const AIRA_PRO_PLAN_AMOUNT_FONT_SIZE: number = 28;
const AIRA_PRO_PLAN_PERIOD_FONT_SIZE: number = 13;
const AIRA_PRO_PLAN_TITLE_ROW_HEIGHT: number = 22;
const AIRA_PRO_PLAN_BADGE_RIGHT_PADDING: number = 62;
const AIRA_PRO_PLAN_ORIGINAL_PRICE_RIGHT_PADDING: number = 96;
const AIRA_PRO_PLAN_ORIGINAL_PRICE_CAPSULE_INSET: number = 10;

const AIRA_PRO_SUBSCRIBE_BUTTON_HEIGHT: number = 52;
const AIRA_PRO_TRANSPARENT_COLOR: string = '#00000000';

@Component
export struct AiraProOverviewScreen {
  @Prop state: AiraProOverviewViewState = {
    title: 'Aira Pro',
    subtitle: '',
    benefits: [],
    reachableDevices: [],
    plans: [],
    showMembershipStatus: false,
    membershipStatusTitle: '',
    membershipStatusDetail: '',
    showManageSubscription: false,
    showPurchaseButton: true,
    showMembershipRedeem: true,
    complimentaryClaim: {
      entryVisible: false,
      entryTitle: '',
      title: '',
      days: 15,
      message: '',
      statusText: '',
      actionText: '',
      actionEnabled: false,
      availability: 'available'
    },
    proValue: $r('app.string.settings_pro_value_view'),
    proActivatedActionText: $r('app.string.settings_pro_activated'),
    proLegalPromptText: $r('app.string.settings_pro_legal_prompt'),
    proLegalAgreementTitle: $r('app.string.settings_pro_legal_membership'),
    proLegalRenewalTitle: $r('app.string.settings_pro_legal_renewal'),
    proActionsEnabled: true,
    proSubscribeEnabled: true,
    lifetimeUpgradePrompt: {
      title: $r('app.string.settings_pro_upgrade_title'),
      message: '',
      cancelLabel: $r('app.string.settings_pro_upgrade_cancel'),
      manageLabel: $r('app.string.settings_pro_manage_renewal')
    }
  };
  @Prop surfaceBackground: ResourceColor = '#FFFFFF';
  @Prop controlBackground: ResourceColor = '#EEF2F7';
  @Prop accentColor: ResourceColor = '#0A59F7';
  @Prop onAccentColor: ResourceColor = '#FFFFFF';
  @Prop primaryTextColor: ResourceColor = '#111318';
  @Prop secondaryTextColor: ResourceColor = '#5F6875';
  @Prop dividerColor: ResourceColor = '#E3E8EF';
  @Prop settingsIconForeground: ResourceColor = '#FFFFFF';
  @Prop settingsIconBackgrounds: BrowserSettingsIconBackgroundTokenSet =
    DEFAULT_BROWSER_SETTINGS_ICON_BACKGROUND_TOKENS;
  @Prop syncProviderIconBackgrounds: BrowserSyncProviderIconBackgroundTokenSet =
    DEFAULT_BROWSER_SYNC_PROVIDER_ICON_BACKGROUND_TOKENS;
  @Prop logoDark: boolean = false;
  @State private selectedPlanId: string = 'one_time';
  @State private proTermsAccepted: boolean = false;
  scroller?: Scroller;
  onSubscribe?: (planId: string) => void;
  onOpenMembershipRedeem?: () => void;
  onOpenSelfHostingGuide?: () => void;
  onOpenMembershipTerms?: () => void;
  onOpenAutoRenewalNotice?: () => void;
  onManageSubscription?: () => void;
  onOpenComplimentaryClaim?: () => void;

  build() {
    SettingsScrollBody({
      contentSpace: 18,
      topPadding: 8,
      bottomPadding: 28,
      scroller: this.scroller
    }) {
      this.buildHero()
      this.buildReachableDeviceRail()
      this.buildBenefitCard()
      if (this.state.showMembershipStatus) {
        this.buildMembershipStatusCard()
      }
      if (this.state.showMembershipRedeem) {
        this.buildMembershipRedeemRow()
      }
      this.buildSelfHostingRow()
      if (this.state.plans.length > 0) {
        Column({ space: 14 }) {
          this.buildPlanCards()
          this.buildLegalConsent()
        }
        .width('100%')
      }
      if (this.state.showPurchaseButton) {
        this.buildSubscriptionActions()
      }
    }
  }

  /**
   * The hero carries the page name and one line of positioning. The benefit list
   * below answers "what do I get", so the title does not repeat it.
   */
  @Builder
  private buildHero() {
    Column({ space: 8 }) {
      this.buildHeroLogo()

      Text(this.state.title)
        .width('100%')
        .fontSize(AIRA_PRO_HERO_TITLE_FONT_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryTextColor)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.hasVisibleText(this.state.subtitle)) {
        Text(this.state.subtitle)
          .width('100%')
          .fontSize(AIRA_PRO_HERO_SUBTITLE_FONT_SIZE)
          .lineHeight(20)
          .fontColor(this.secondaryTextColor)
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .padding({ top: 4, bottom: 2, left: 12, right: 12 })
    .alignItems(HorizontalAlign.Center)
  }

  /**
   * One mark for this page. Light and dark only swap the vertical gradient.
   */
  @Builder
  private buildHeroLogo() {
    Row()
      .width(AIRA_PRO_HERO_LOGO_SIZE)
      .height(AIRA_PRO_HERO_LOGO_SIZE)
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: this.resolveHeroLogoGradient()
      })
      .clipShape(new PathShape({
        commands: this.resolveHeroLogoCommands()
      }))
      .hitTestBehavior(HitTestMode.None)
  }

  private resolveHeroLogoGradient(): Array<[ResourceColor, number]> {
    if (this.logoDark) {
      return [['#DDDDDD', 0], ['#757575', 1]];
    }
    return [['#505050', 0], ['#000000', 1]];
  }

  private resolveHeroLogoCommands(): string {
    const scale = this.resolveHeroLogoSizePx() / AIRA_PRO_HERO_LOGO_SOURCE_SIZE;
    return AIRA_PRO_HERO_LOGO_COMMANDS.replace(/-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/g, (value: string): string => {
      const scaled = Number(value) * scale;
      const normalized = Math.abs(scaled) < 0.0001 ? 0 : scaled;
      return normalized.toFixed(4).replace(/\.?0+$/, '');
    });
  }

  private resolveHeroLogoSizePx(): number {
    try {
      return AIRA_PRO_HERO_LOGO_SIZE * display.getDefaultDisplaySync().densityPixels;
    } catch (_error) {
      return AIRA_PRO_HERO_LOGO_SIZE;
    }
  }

  /**
   * Which endpoints Pro reaches. It plays the same role as the model logos at
   * the top of a subscription page, and deliberately does not restate the
   * benefit list: the devices scroll, the capabilities live in the card.
   */
  @Builder
  private buildReachableDeviceRail() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.state.reachableDevices, (device: AiraProOverviewReachableDeviceState) => {
          this.buildReachableDeviceChip(device)
        }, (device: AiraProOverviewReachableDeviceState) => device.id)
      }
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  @Builder
  private buildReachableDeviceChip(device: AiraProOverviewReachableDeviceState) {
    Row({ space: 7 }) {
      Image(this.resolveBrowserBrandIcon(device.glyph))
        .width(AIRA_PRO_DEVICE_CHIP_ICON_SIZE)
        .height(AIRA_PRO_DEVICE_CHIP_ICON_SIZE)
        .objectFit(ImageFit.Contain)

      Text(device.label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor)
        .maxLines(1)
    }
    .height(AIRA_PRO_DEVICE_CHIP_HEIGHT)
    .padding({ left: 12, right: 14 })
    .backgroundColor(this.surfaceBackground)
    .borderRadius(AIRA_PRO_DEVICE_CHIP_CORNER_RADIUS)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildBenefitCard() {
    SettingsGroupCard({ surfaceColor: this.surfaceBackground }) {
      ForEach(this.state.benefits, (benefit: AiraProOverviewBenefitState, index: number) => {
        this.buildBenefitRow(benefit, index)
        if (index < this.state.benefits.length - 1) {
          SettingsGroupDivider({ dividerColor: this.dividerColor })
        }
      }, (benefit: AiraProOverviewBenefitState) => benefit.id)
    }
  }

  @Builder
  private buildBenefitRow(benefit: AiraProOverviewBenefitState, index: number) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        SettingsColoredIconBackground({
          color: this.resolveBenefitIconBackgroundColor(index),
          iconSize: AIRA_PRO_BENEFIT_ICON_TILE_SIZE
        })

        AiraIcon({
          airaIconId: benefit.iconId,
          iconSize: AIRA_PRO_BENEFIT_ICON_IMAGE_SIZE,
          iconColor: this.settingsIconForeground
        })
      }
      .width(AIRA_PRO_BENEFIT_ICON_TILE_SIZE)
      .height(AIRA_PRO_BENEFIT_ICON_TILE_SIZE)

      Text(benefit.title)
        .layoutWeight(1)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({
      left: AIRA_PRO_BENEFIT_ROW_HORIZONTAL_PADDING,
      right: AIRA_PRO_BENEFIT_ROW_HORIZONTAL_PADDING,
      top: AIRA_PRO_BENEFIT_ROW_VERTICAL_PADDING,
      bottom: AIRA_PRO_BENEFIT_ROW_VERTICAL_PADDING
    })
    .borderRadius(AIRA_PRO_BENEFIT_ROW_CORNER_RADIUS)
    .alignItems(VerticalAlign.Center)
  }

  /**
   * Two cards, equal height. The discount badge is pinned to the card's top-right
   * corner instead of sitting in the title row's flow, so a badged card and a
   * plain one keep the same title / price / caption baseline.
   */
  @Builder
  private buildPlanCards() {
    Column({ space: 12 }) {
      ForEach(this.lifetimePlans(), (plan: AiraProOverviewPlanState) => {
        this.buildPlanCard(plan, false)
      }, (plan: AiraProOverviewPlanState) => plan.id)

      Row({ space: 12 }) {
        ForEach(this.subscriptionPlans(), (plan: AiraProOverviewPlanState) => {
          this.buildPlanCard(plan, true)
        }, (plan: AiraProOverviewPlanState) => plan.id)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildPlanCard(plan: AiraProOverviewPlanState, stretch: boolean) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 0 }) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Row() {
            Text(plan.title)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.secondaryTextColor)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ right: this.resolvePlanTitleRightPadding(plan) })
          }
          .width('100%')
          .height(AIRA_PRO_PLAN_TITLE_ROW_HEIGHT)
          .alignItems(VerticalAlign.Center)

          if (this.hasVisibleText(plan.discountBadgeText)) {
            Text(plan.discountBadgeText)
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.accentColor)
              .padding({ left: 7, right: 7, top: 3, bottom: 3 })
              .backgroundColor(this.controlBackground)
              .borderRadius(7)
              .maxLines(1)
          }
        }
        .width('100%')
        .height(AIRA_PRO_PLAN_TITLE_ROW_HEIGHT)

        // One Text with two Spans, not a Row of two Texts: only inline spans share
        // a baseline, so ¥7.89 and / 年 sit on the same line however the ratio of
        // the two font sizes changes. A Row with alignItems(Bottom) aligns the two
        // text boxes' bottoms, which is not the same thing — the smaller cadence
        // carries descender space the amount does not, so its glyphs floated up.
        Text() {
          Span(plan.amountText)
            .fontSize(AIRA_PRO_PLAN_AMOUNT_FONT_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor)

          if (this.hasVisibleText(plan.periodText)) {
            Span(plan.periodText)
              .fontSize(AIRA_PRO_PLAN_PERIOD_FONT_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.secondaryTextColor)
          }
        }
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ top: 10 })

        Text(plan.description)
          .width('100%')
          .fontSize(12)
          .lineHeight(17)
          .fontColor(this.secondaryTextColor)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ top: 8 })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)

      if (this.hasVisibleText(plan.originalPriceText)) {
        this.buildOriginalPriceCapsule(plan.originalPriceText)
      }
    }
    .width(stretch ? 0 : '100%')
    .layoutWeight(stretch ? 1 : 0)
    .constraintSize({ minHeight: stretch ? AIRA_PRO_PLAN_CARD_MIN_HEIGHT : 0 })
    .backgroundColor(this.surfaceBackground)
    .borderRadius(AIRA_PRO_PLAN_CARD_CORNER_RADIUS)
    .border(this.resolvePlanCardBorder(plan))
    .clip(true)
    .enabled(this.canSelectPlan(plan))
    .opacity(this.canSelectPlan(plan) ? 1 : 0.52)
    .onClick(() => {
      if (this.canSelectPlan(plan)) {
        this.selectedPlanId = plan.id;
      }
    })
  }

  /**
   * List-price chip on the card corner. The line runs through the glyphs, and
   * the pill stays inside the rounded corner so the clip does not cut it.
   */
  @Builder
  private buildOriginalPriceCapsule(text: ResourceStr) {
    Text(text)
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.secondaryTextColor)
      .decoration({
        type: TextDecorationType.LineThrough,
        color: this.secondaryTextColor
      })
      .textAlign(TextAlign.Center)
      .maxLines(1)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor(this.controlBackground)
      .borderRadius(20)
      .margin({
        top: AIRA_PRO_PLAN_ORIGINAL_PRICE_CAPSULE_INSET,
        right: AIRA_PRO_PLAN_ORIGINAL_PRICE_CAPSULE_INSET
      })
      .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private buildMembershipRedeemRow() {
    this.buildFooterEntryRow(
      $r('app.string.settings_pro_redeem'),
      $r('app.string.settings_pro_redeem_hint'),
      'settings.membership',
      this.settingsIconBackgrounds.syncMethod,
      () => {
        this.onOpenMembershipRedeem?.();
      }
    )
  }

  /**
   * The free route stays on the page for every membership state. A status card
   * explains the current Pro grant; it does not replace this row.
   */
  @Builder
  private buildSelfHostingRow() {
    this.buildFooterEntryRow(
      $r('app.string.settings_pro_self_hosting'),
      $r('app.string.settings_pro_self_hosting_hint'),
      'settings.webdav',
      this.syncProviderIconBackgrounds.webdav,
      () => {
        this.onOpenSelfHostingGuide?.();
      }
    )
  }

  @Builder
  private buildFooterEntryRow(
    title: ResourceStr,
    subtitle: ResourceStr,
    airaIconId: AiraRenderableIconId,
    iconBackground: ResourceColor,
    onAction: () => void
  ) {
    SettingsGroupCard({ surfaceColor: this.surfaceBackground }) {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          SettingsColoredIconBackground({
            color: iconBackground,
            iconSize: AIRA_PRO_BENEFIT_ICON_TILE_SIZE
          })

          AiraIcon({
            airaIconId: airaIconId,
            iconSize: AIRA_PRO_BENEFIT_ICON_IMAGE_SIZE,
            iconColor: this.settingsIconForeground
          })
        }
        .width(AIRA_PRO_BENEFIT_ICON_TILE_SIZE)
        .height(AIRA_PRO_BENEFIT_ICON_TILE_SIZE)

        Column({ space: 2 }) {
          Text(title)
            .width('100%')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryTextColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(subtitle)
            .width('100%')
            .fontSize(12)
            .lineHeight(17)
            .fontColor(this.secondaryTextColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('›')
          .fontSize(20)
          .fontColor(this.secondaryTextColor)
      }
      .width('100%')
      .padding({
        left: AIRA_PRO_BENEFIT_ROW_HORIZONTAL_PADDING,
        right: AIRA_PRO_BENEFIT_ROW_HORIZONTAL_PADDING,
        top: AIRA_PRO_BENEFIT_ROW_VERTICAL_PADDING,
        bottom: AIRA_PRO_BENEFIT_ROW_VERTICAL_PADDING
      })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        onAction();
      })
    }
  }

  /**
   * A member who already holds Pro still sees the current entitlement here.
   * Purchasable plans, including a lifetime upgrade, stay on the purchase button.
   */
  @Builder
  private buildMembershipStatusCard() {
    Column({ space: 14 }) {
      Column({ space: 4 }) {
        Text(this.state.membershipStatusTitle)
          .width('100%')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.hasVisibleText(this.state.membershipStatusDetail)) {
          Text(this.state.membershipStatusDetail)
            .width('100%')
            .fontSize(13)
            .lineHeight(18)
            .fontColor(this.secondaryTextColor)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .backgroundColor(this.surfaceBackground)
    .borderRadius(AIRA_PRO_PLAN_CARD_CORNER_RADIUS)
  }

  @Builder
  private buildLegalConsent() {
    Column({ space: 6 }) {
      if (this.selectedPlanRequiresConsent()) {
        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
          Checkbox()
            .select(this.proTermsAccepted)
            .selectedColor(this.accentColor)
            .enabled(this.canUseSelectedPlan())
            .width(18)
            .height(18)
            .onChange((selected: boolean) => {
              if (this.canUseSelectedPlan()) {
                this.proTermsAccepted = selected;
              }
            })
            .margin({ right: 6, bottom: 4 })

          Text(this.state.proLegalPromptText)
            .fontSize(12)
            .lineHeight(20)
            .fontColor(this.secondaryTextColor)
            .maxLines(1)
            .onClick(() => {
              this.toggleTermsAccepted();
            })
            .margin({ right: 6, bottom: 4 })

          this.buildLegalTextLink(this.state.proLegalAgreementTitle, () => {
            this.onOpenMembershipTerms?.();
          })
          if (this.shouldShowAutoRenewalNotice()) {
            Text($r('app.string.settings_pro_legal_join'))
              .fontSize(12)
              .lineHeight(20)
              .fontColor(this.secondaryTextColor)
              .maxLines(1)
              .margin({ right: 2, bottom: 4 })
            this.buildLegalTextLink(this.state.proLegalRenewalTitle, () => {
              this.onOpenAutoRenewalNotice?.();
            })
          }
        }
        .width('100%')
      }

      Text(this.resolveSubscriptionFooterText())
        .width('100%')
        .fontSize(11)
        .lineHeight(16)
        .fontColor(this.secondaryTextColor)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 6, right: 6 })
  }

  @Builder
  private buildLegalTextLink(label: ResourceStr, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.accentColor)
        .lineHeight(20)
        .maxLines(2)
    }
    .buttonStyle(ButtonStyleMode.TEXTUAL)
    .backgroundColor($r('sys.color.ohos_id_color_background_transparent'))
    .padding(0)
    .margin({ right: 6, bottom: 4 })
    .enabled(this.canOpenLegal())
    .stateEffect(this.canOpenLegal())
    .onClick(action)
  }

  @Builder
  private buildSubscriptionActions() {
    Column({ space: 10 }) {
      Button() {
        Text(this.resolveSubscribeButtonLabel())
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.onAccentColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(AIRA_PRO_SUBSCRIBE_BUTTON_HEIGHT)
      .type(ButtonType.Normal)
      .buttonStyle(ButtonStyleMode.NORMAL)
      .backgroundColor(this.accentColor)
      .borderRadius(AIRA_PRO_SUBSCRIBE_BUTTON_HEIGHT / 2)
      .opacity(this.canSubscribe() ? 1 : 0.56)
      .enabled(this.canSubscribe())
      .stateEffect(this.canSubscribe())
      .onClick(() => {
        if (this.canSubscribe()) {
          const selectedPlan = this.resolveSelectedPlan();
          if (selectedPlan === undefined) {
            return;
          }
          if (selectedPlan.action === 'manage_subscription') {
            this.onManageSubscription?.();
            return;
          }
          this.onSubscribe?.(selectedPlan.id);
        }
      })

      if (this.state.complimentaryClaim.entryVisible) {
        Text(this.state.complimentaryClaim.entryTitle)
          .width('100%')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.accentColor)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ top: 6, bottom: 2 })
          .onClick(() => {
            this.onOpenComplimentaryClaim?.();
          })
      }
    }
    .width('100%')
  }

  private resolveBenefitIconBackgroundColor(index: number): ResourceColor {
    const colors: ResourceColor[] = [
      this.settingsIconBackgrounds.sync,
      this.settingsIconBackgrounds.crossDeviceLink,
      this.settingsIconBackgrounds.bookmarks,
      this.settingsIconBackgrounds.history,
      this.settingsIconBackgrounds.siteSettings,
      this.settingsIconBackgrounds.experiments
    ];
    return colors[index % colors.length];
  }

  /**
   * Selection is the border and nothing else. The unselected state keeps the
   * same border width in a transparent colour so switching plans changes no
   * geometry — a wider selected border would otherwise nudge the card's content
   * by a pixel on every tap.
   */
  private resolvePlanTitleRightPadding(plan: AiraProOverviewPlanState): number {
    if (this.hasVisibleText(plan.originalPriceText)) {
      return AIRA_PRO_PLAN_ORIGINAL_PRICE_RIGHT_PADDING;
    }
    if (this.hasVisibleText(plan.discountBadgeText)) {
      return AIRA_PRO_PLAN_BADGE_RIGHT_PADDING;
    }
    return 0;
  }

  private resolvePlanCardBorder(plan: AiraProOverviewPlanState): BorderOptions {
    const selected = this.selectedPlanId === plan.id;
    return {
      width: AIRA_PRO_PLAN_CARD_SELECTED_BORDER_WIDTH,
      color: selected ? this.accentColor : AIRA_PRO_TRANSPARENT_COLOR
    };
  }

  private resolveBrowserBrandIcon(glyph: AiraProReachableDeviceGlyph): Resource {
    if (glyph === 'edge') {
      return $r('app.media.sync_browser_edge');
    }
    if (glyph === 'firefox') {
      return $r('app.media.sync_browser_firefox');
    }
    return $r('app.media.sync_browser_chrome');
  }

  private canSelectPlan(plan: AiraProOverviewPlanState): boolean {
    return this.state.proActionsEnabled && plan.action !== 'unavailable';
  }

  private canUseSelectedPlan(): boolean {
    const selectedPlan = this.resolveSelectedPlan();
    return selectedPlan !== undefined && this.canSelectPlan(selectedPlan);
  }

  private canSubscribe(): boolean {
    const selectedPlan = this.resolveSelectedPlan();
    if (selectedPlan === undefined || !this.canSelectPlan(selectedPlan)) {
      return false;
    }
    return selectedPlan.action !== 'purchase' || this.proTermsAccepted;
  }

  private canOpenLegal(): boolean {
    return true;
  }

  private toggleTermsAccepted(): void {
    if (!this.canUseSelectedPlan() || !this.selectedPlanRequiresConsent()) {
      return;
    }
    this.proTermsAccepted = !this.proTermsAccepted;
  }

  private resolveSubscribeButtonLabel(): ResourceStr {
    if (!this.state.proActionsEnabled) {
      return $r('app.string.settings_pro_subscribe_blocked');
    }
    if (!this.state.proSubscribeEnabled) {
      return this.state.proActivatedActionText;
    }
    const selectedPlan = this.resolveSelectedPlan();
    if (selectedPlan?.action === 'purchase' && !this.proTermsAccepted) {
      return selectedPlan?.consentActionText ?? $r('app.string.settings_pro_consent_continue');
    }
    return selectedPlan?.actionText ?? $r('app.string.settings_pro_continue');
  }

  private resolveSubscriptionFooterText(): ResourceStr {
    if (!this.state.proActionsEnabled) {
      return $r('app.string.settings_pro_private_note');
    }
    if (!this.state.proSubscribeEnabled) {
      return this.state.proValue;
    }
    return this.resolveSelectedPlan()?.footerText ?? '';
  }

  private hasVisibleText(value: ResourceStr): boolean {
    return typeof value !== 'string' || value.length > 0;
  }

  private shouldShowAutoRenewalNotice(): boolean {
    return this.resolveSelectedPlan()?.purchaseKind === 'subscription';
  }

  private selectedPlanRequiresConsent(): boolean {
    return this.resolveSelectedPlan()?.action === 'purchase';
  }

  private lifetimePlans(): AiraProOverviewPlanState[] {
    return this.state.plans.filter((plan: AiraProOverviewPlanState) => plan.purchaseKind === 'one_time');
  }

  private subscriptionPlans(): AiraProOverviewPlanState[] {
    return this.state.plans.filter((plan: AiraProOverviewPlanState) => plan.purchaseKind !== 'one_time');
  }

  private resolveSelectedPlan(): AiraProOverviewPlanState | undefined {
    const selected = this.state.plans.find((plan: AiraProOverviewPlanState) => plan.id === this.selectedPlanId);
    if (selected !== undefined) {
      return selected;
    }
    return this.state.plans.length > 0 ? this.state.plans[0] : undefined;
  }
}
