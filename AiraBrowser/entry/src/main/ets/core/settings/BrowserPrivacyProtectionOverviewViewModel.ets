import { AdBlockDailyProtectionActivity } from '../../common/models/BrowserModels';
import { resolveAppResourceText } from '../resources/AppResourceText';
import { i18n } from '@kit.LocalizationKit';

function resolveWeekdayShortLabel(weekdayIndex: number): string {
  switch (weekdayIndex) {
    case 0:
      return resolveAppResourceText($r('app.string.settings_privacy_protection_weekday_short_sun'));
    case 1:
      return resolveAppResourceText($r('app.string.settings_privacy_protection_weekday_short_mon'));
    case 2:
      return resolveAppResourceText($r('app.string.settings_privacy_protection_weekday_short_tue'));
    case 3:
      return resolveAppResourceText($r('app.string.settings_privacy_protection_weekday_short_wed'));
    case 4:
      return resolveAppResourceText($r('app.string.settings_privacy_protection_weekday_short_thu'));
    case 5:
      return resolveAppResourceText($r('app.string.settings_privacy_protection_weekday_short_fri'));
    default:
      return resolveAppResourceText($r('app.string.settings_privacy_protection_weekday_short_sat'));
  }
}

function resolveWeekdayDetailLabel(weekdayIndex: number): string {
  switch (weekdayIndex) {
    case 0:
      return resolveAppResourceText($r('app.string.settings_privacy_protection_weekday_detail_sun'));
    case 1:
      return resolveAppResourceText($r('app.string.settings_privacy_protection_weekday_detail_mon'));
    case 2:
      return resolveAppResourceText($r('app.string.settings_privacy_protection_weekday_detail_tue'));
    case 3:
      return resolveAppResourceText($r('app.string.settings_privacy_protection_weekday_detail_wed'));
    case 4:
      return resolveAppResourceText($r('app.string.settings_privacy_protection_weekday_detail_thu'));
    case 5:
      return resolveAppResourceText($r('app.string.settings_privacy_protection_weekday_detail_fri'));
    default:
      return resolveAppResourceText($r('app.string.settings_privacy_protection_weekday_detail_sat'));
  }
}

export interface BrowserPrivacyProtectionOverviewInput {
  activities: AdBlockDailyProtectionActivity[];
  selectedDayIndex: number;
  filterEnabled: boolean;
  enhancedTrackingProtectionEnabled: boolean;
}

export interface BrowserPrivacyProtectionDayState {
  dayStartedAt: number;
  shortLabel: string;
  detailLabel: string;
  requestBlockingCount: number;
  linkCleaningCount: number;
  elementHidingCount: number;
  totalActionCount: number;
  barHeight: number;
}

export interface BrowserPrivacyProtectionOverviewState {
  days: BrowserPrivacyProtectionDayState[];
  selectedDayIndex: number;
  selectedDay: BrowserPrivacyProtectionDayState;
  lastSevenDaysTotalLabel: string;
  filterEnabled: boolean;
  filterStatusLabel: string;
  trackingModeLabel: string;
  detailBreakdownLabel: string;
}

export class BrowserPrivacyProtectionOverviewViewModel {
  buildState(input: BrowserPrivacyProtectionOverviewInput): BrowserPrivacyProtectionOverviewState {
    const rawDays: BrowserPrivacyProtectionDayState[] = input.activities.map(
      (activity: AdBlockDailyProtectionActivity, index: number): BrowserPrivacyProtectionDayState =>
        this.buildDayState(activity, index === input.activities.length - 1)
    );
    const normalizedDays: BrowserPrivacyProtectionDayState[] = rawDays.length > 0 ? rawDays : [
      this.buildDayState({
        dayStartedAt: Date.now(),
        networkBlockedCount: 0,
        urlParameterRemovedCount: 0,
        cosmeticElementHiddenCount: 0,
        manualElementHiddenCount: 0,
        totalProtectionActionCount: 0
      }, true)
    ];
    let maximumCount: number = 0;
    let lastSevenDaysTotal: number = 0;
    for (let index: number = 0; index < normalizedDays.length; index += 1) {
      maximumCount = Math.max(maximumCount, normalizedDays[index].totalActionCount);
      lastSevenDaysTotal += normalizedDays[index].totalActionCount;
    }
    const days: BrowserPrivacyProtectionDayState[] = normalizedDays.map(
      (day: BrowserPrivacyProtectionDayState): BrowserPrivacyProtectionDayState => {
        return {
          dayStartedAt: day.dayStartedAt,
          shortLabel: day.shortLabel,
          detailLabel: day.detailLabel,
          requestBlockingCount: day.requestBlockingCount,
          linkCleaningCount: day.linkCleaningCount,
          elementHidingCount: day.elementHidingCount,
          totalActionCount: day.totalActionCount,
          barHeight: this.resolveBarHeight(day.totalActionCount, maximumCount)
        };
      }
    );
    const selectedDayIndex: number = this.normalizeSelectedDayIndex(input.selectedDayIndex, days.length);
    const selectedDay: BrowserPrivacyProtectionDayState = days[selectedDayIndex];
    return {
      days: days,
      selectedDayIndex: selectedDayIndex,
      selectedDay: selectedDay,
      lastSevenDaysTotalLabel: this.formatCount(lastSevenDaysTotal),
      filterEnabled: input.filterEnabled,
      filterStatusLabel: input.filterEnabled ?
        resolveAppResourceText($r('app.string.settings_privacy_protection_overview_filter_on')) :
        resolveAppResourceText($r('app.string.settings_privacy_protection_overview_filter_off')),
      trackingModeLabel: input.enhancedTrackingProtectionEnabled ?
        resolveAppResourceText($r('app.string.settings_privacy_protection_tracking_enhanced')) :
        resolveAppResourceText($r('app.string.settings_site_info_fingerprint_standard')),
      detailBreakdownLabel: this.buildBreakdownLabel(selectedDay)
    };
  }

  private buildDayState(
    activity: AdBlockDailyProtectionActivity,
    isToday: boolean
  ): BrowserPrivacyProtectionDayState {
    const requestBlockingCount: number = Math.max(0, Math.floor(activity.networkBlockedCount));
    const linkCleaningCount: number = Math.max(0, Math.floor(activity.urlParameterRemovedCount));
    const elementHidingCount: number = Math.max(
      0,
      Math.floor(activity.cosmeticElementHiddenCount) + Math.floor(activity.manualElementHiddenCount)
    );
    const totalActionCount: number = requestBlockingCount + linkCleaningCount +
      elementHidingCount;
    const date: Date = new Date(activity.dayStartedAt);
    const weekdayIndex: number = date.getDay();
    return {
      dayStartedAt: activity.dayStartedAt,
      shortLabel: isToday
        ? resolveAppResourceText($r('app.string.settings_privacy_protection_today_short'))
        : resolveWeekdayShortLabel(weekdayIndex),
      detailLabel: isToday
        ? resolveAppResourceText($r('app.string.settings_privacy_protection_today'))
        : resolveWeekdayDetailLabel(weekdayIndex),
      requestBlockingCount: requestBlockingCount,
      linkCleaningCount: linkCleaningCount,
      elementHidingCount: elementHidingCount,
      totalActionCount: totalActionCount,
      barHeight: 4
    };
  }

  private buildBreakdownLabel(day: BrowserPrivacyProtectionDayState): string {
    return resolveAppResourceText(
      $r('app.string.settings_privacy_protection_overview_breakdown'),
      this.formatCount(day.requestBlockingCount),
      this.formatCount(day.linkCleaningCount),
      this.formatCount(day.elementHidingCount)
    );
  }

  private resolveBarHeight(value: number, maximumCount: number): number {
    if (value <= 0 || maximumCount <= 0) {
      return 4;
    }
    return Math.max(4, Math.round(value / maximumCount * 88));
  }

  private normalizeSelectedDayIndex(index: number, dayCount: number): number {
    if (index < 0) {
      return 0;
    }
    if (index >= dayCount) {
      return dayCount - 1;
    }
    return Math.floor(index);
  }

  private formatCount(value: number): string {
    const normalized: number = Math.max(0, Math.floor(value));
    if (!i18n.System.getSystemLanguage().toLowerCase().startsWith('zh')) {
      return normalized.toLocaleString();
    }
    if (normalized >= 100000000) {
      return resolveAppResourceText(
        $r('app.string.settings_privacy_protection_count_yi'),
        Math.floor(normalized / 100000000)
      );
    }
    if (normalized >= 10000) {
      const whole: number = Math.floor(normalized / 10000);
      const decimal: number = Math.floor((normalized % 10000) / 1000);
      if (decimal > 0) {
        return resolveAppResourceText($r('app.string.settings_privacy_protection_count_wan_decimal'), whole, decimal);
      }
      return resolveAppResourceText($r('app.string.settings_privacy_protection_count_wan'), whole);
    }
    return `${normalized}`;
  }
}
