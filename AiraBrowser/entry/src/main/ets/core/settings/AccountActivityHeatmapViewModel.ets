import {
  AiraActivityDailyAggregate,
  AiraActivityHeatmapCellState,
  AiraActivityHeatmapViewState
} from '../../common/models/ActivityModels';
import { ActivityScoreService } from '../../services/activity/ActivityScoreService';
import { localizeSettingsCopy } from '../../core/settings/SettingsCopy';

const DEFAULT_WEEK_COUNT: number = 12;
const DAYS_PER_WEEK: number = 7;

export class AccountActivityHeatmapViewModel {
  private scoreService: ActivityScoreService = new ActivityScoreService();

  buildState(
    totals: AiraActivityDailyAggregate[],
    weekCount: number = DEFAULT_WEEK_COUNT,
    now: number = Date.now()
  ): AiraActivityHeatmapViewState {
    const resolvedWeekCount = Math.max(4, Math.min(53, Math.round(weekCount)));
    const todayKey = this.scoreService.toLocalDateKey(now);
    const startKey = this.scoreService.shiftDateKey(todayKey, -((resolvedWeekCount * DAYS_PER_WEEK) - 1));
    const byDate = new Map<string, AiraActivityDailyAggregate>();
    totals.forEach((item: AiraActivityDailyAggregate) => byDate.set(item.date, item));
    const visibleScores = this.collectVisibleScores(byDate, startKey, resolvedWeekCount);
    const levelThresholds = this.resolveLevelThresholds(visibleScores);
    const cells: AiraActivityHeatmapCellState[] = [];
    let activeDays = 0;
    for (let index = 0; index < resolvedWeekCount * DAYS_PER_WEEK; index += 1) {
      const date = this.scoreService.shiftDateKey(startKey, index);
      const item = byDate.get(date);
      const count = item?.score ?? 0;
      const level = this.resolveLevel(count, levelThresholds);
      const isToday = date === todayKey;
      if (count > 0) {
        activeDays += 1;
      }
      cells.push({
        date,
        dayOfMonth: `${Number(date.slice(8, 10))}`,
        count,
        level,
        isToday,
        isFuture: date.localeCompare(todayKey) > 0,
        tooltipText: this.buildTooltipText(date, count, level, isToday),
        accessibilityText: this.buildAccessibilityText(date, count)
      });
    }
    return {
      title: localizeSettingsCopy('Aira 活跃'),
      summary: activeDays > 0
        ? $r('app.string.settings_activity_03', resolvedWeekCount, activeDays)
        : localizeSettingsCopy('开始使用 Aira 后，这里会点亮你的活跃日历'),
      cells,
      weekCount: resolvedWeekCount,
      legendLevels: [0, 1, 2, 3, 4],
      maxLevel: 4,
      hasActivity: activeDays > 0
    };
  }

  private collectVisibleScores(
    byDate: Map<string, AiraActivityDailyAggregate>,
    startKey: string,
    weekCount: number
  ): number[] {
    const scores: number[] = [];
    for (let index = 0; index < weekCount * DAYS_PER_WEEK; index += 1) {
      const date = this.scoreService.shiftDateKey(startKey, index);
      const count = byDate.get(date)?.score ?? 0;
      if (count > 0) {
        scores.push(count);
      }
    }
    return scores.sort((left: number, right: number) => left - right);
  }

  private resolveLevelThresholds(scores: number[]): number[] {
    if (scores.length <= 0) {
      return [6, 18, 40, 72];
    }
    return [
      this.resolvePercentile(scores, 0.35),
      this.resolvePercentile(scores, 0.6),
      this.resolvePercentile(scores, 0.8),
      this.resolvePercentile(scores, 0.93)
    ];
  }

  private resolveLevel(count: number, thresholds: number[]): number {
    if (count <= 0) {
      return 0;
    }
    if (count <= thresholds[0]) {
      return 1;
    }
    if (count <= thresholds[1]) {
      return 2;
    }
    if (count <= thresholds[2]) {
      return 3;
    }
    return 4;
  }

  private resolvePercentile(scores: number[], percentile: number): number {
    const index = Math.max(0, Math.min(scores.length - 1, Math.ceil(scores.length * percentile) - 1));
    return Math.max(1, scores[index]);
  }

  private buildAccessibilityText(date: string, count: number): Resource {
    if (count <= 0) {
      return $r('app.string.settings_account_activity_a11y_none', date);
    }
    return $r('app.string.settings_account_activity_a11y_points', date, count);
  }

  private buildTooltipText(date: string, count: number, level: number, isToday: boolean): ResourceStr {
    const month = Number(date.slice(5, 7));
    const day = Number(date.slice(8, 10));
    if (!Number.isFinite(month) || !Number.isFinite(day) || month <= 0 || day <= 0) {
      return this.buildRawActivityTooltip(date, count, isToday);
    }
    return this.buildDatedActivityTooltip(month, day, count, level, isToday);
  }

  private buildRawActivityTooltip(date: string, count: number, isToday: boolean): ResourceStr {
    if (count <= 0) {
      return isToday
        ? $r('app.string.settings_account_activity_today_empty_raw', date)
        : $r('app.string.settings_account_activity_day_empty_raw', date);
    }
    return isToday
      ? $r('app.string.settings_account_activity_today_points_raw', date, count)
      : $r('app.string.settings_account_activity_day_points_raw', date, count);
  }

  private buildDatedActivityTooltip(
    month: number,
    day: number,
    count: number,
    level: number,
    isToday: boolean
  ): ResourceStr {
    if (count <= 0) {
      return isToday
        ? $r('app.string.settings_account_activity_today_empty', month, day)
        : $r('app.string.settings_account_activity_day_empty', month, day);
    }
    if (level === 1) {
      return isToday
        ? $r('app.string.settings_account_activity_today_light', month, day, count)
        : $r('app.string.settings_account_activity_day_light', month, day, count);
    }
    if (level === 2) {
      return isToday
        ? $r('app.string.settings_account_activity_today_regular', month, day, count)
        : $r('app.string.settings_account_activity_day_regular', month, day, count);
    }
    if (level === 3) {
      return isToday
        ? $r('app.string.settings_account_activity_today_active', month, day, count)
        : $r('app.string.settings_account_activity_day_active', month, day, count);
    }
    if (level >= 4) {
      return isToday
        ? $r('app.string.settings_account_activity_today_high', month, day, count)
        : $r('app.string.settings_account_activity_day_high', month, day, count);
    }
    return isToday
      ? $r('app.string.settings_account_activity_today_points', month, day, count)
      : $r('app.string.settings_account_activity_day_points', month, day, count);
  }
}
