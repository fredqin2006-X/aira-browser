import { CrossDeviceBrowserIconKind } from './CrossDeviceBrowserIcon';

/**
 * The reviewed phone composition. Every later width is this drawing scaled down,
 * never a different arrangement, so a mark that sits on a ring stays on that ring.
 */
const DESIGN_WIDTH: number = 390;
/**
 * Sits high so the outer arc enters the top fade instead of leaving a gap
 * under the title. The list start follows this center.
 */
const DESIGN_CENTER_Y: number = 240;
const DESIGN_LOGO_SIZE: number = 88;
const DESIGN_MARK_SIZE: number = 46;
const DESIGN_ORBIT_RADII: number[] = [128, 188, 248];
/** Lower-half fade finishes at 78% of the full diameter, then the rest is gone. */
const DESIGN_FADE_END_FRACTION: number = 0.78;
/** Page-color wash at the top, in design vp. Solid through the hold, gone by the end. */
const DESIGN_TOP_FADE_HOLD: number = 16;
const DESIGN_TOP_FADE_END: number = 80;
const DESIGN_OUTER_RADIUS: number = 248;
const DESIGN_STAGE_HEIGHT: number = DESIGN_CENTER_Y + DESIGN_OUTER_RADIUS * 0.62 + 8;
/**
 * Negative so the list starts over the logo's lower edge instead of leaving a gap
 * under it. The marks stay above this line.
 */
const DESIGN_COVER_GAP: number = -36;

export const CROSS_DEVICE_LINK_ORBIT_DESIGN_WIDTH: number = DESIGN_WIDTH;
export const CROSS_DEVICE_LINK_ORBIT_RADII: number[] = DESIGN_ORBIT_RADII;
/** One revolution. Inner is fastest, outer is slowest, like planets on wider rings. */
export const CROSS_DEVICE_LINK_ORBIT_SPIN_PERIOD_INNER_MS: number = 11000;
export const CROSS_DEVICE_LINK_ORBIT_SPIN_PERIOD_MIDDLE_MS: number = 18000;
export const CROSS_DEVICE_LINK_ORBIT_SPIN_PERIOD_OUTER_MS: number = 29000;

interface CrossDeviceLinkOrbitMarkSpec {
  kind: CrossDeviceBrowserIconKind;
  /** Degrees from straight up. Positive is clockwise, matching the preview. */
  angleDegrees: number;
  orbitIndex: number;
}

/**
 * Spread across the visible upper arc. The outer ring is wider than the phone,
 * so only one mark sits on it; the rest use the rings that have room.
 */
const ORBIT_MARKS: CrossDeviceLinkOrbitMarkSpec[] = [
  { kind: 'chrome', angleDegrees: -90, orbitIndex: 0 },
  { kind: 'firefox', angleDegrees: -36, orbitIndex: 0 },
  { kind: 'vivaldi', angleDegrees: 36, orbitIndex: 0 },
  { kind: 'zen', angleDegrees: 90, orbitIndex: 0 },
  { kind: 'edge', angleDegrees: -60, orbitIndex: 1 },
  { kind: 'opera', angleDegrees: 60, orbitIndex: 1 },
  { kind: 'brave', angleDegrees: 0, orbitIndex: 2 }
];

export interface CrossDeviceLinkOrbitMarkPlacement {
  kind: CrossDeviceBrowserIconKind;
  x: number;
  y: number;
  size: number;
  orbitRadius: number;
  orbitIndex: number;
}

export interface CrossDeviceLinkOrbitLayout {
  stageWidth: number;
  stageHeight: number;
  centerX: number;
  centerY: number;
  logoSize: number;
  orbits: number[];
  marks: CrossDeviceLinkOrbitMarkPlacement[];
  /** Stage fraction where the top page-color fade is still solid. */
  topFadeHold: number;
  /** Stage fraction where the top page-color fade has finished. */
  topFadeEnd: number;
  /** Stage fraction where the rings are still fully visible: the logo center. */
  fadeHold: number;
  /** Stage fraction where the lower half has finished fading out. */
  fadeEnd: number;
}

/**
 * Top wash color. Light, dark, and any other palette each fade into their own
 * page background; a fixed wash would show a seam in the other mode.
 */
export function crossDeviceLinkOrbitPageFadeColor(pageBackground: string, alphaHex: string): string {
  const normalized = pageBackground.trim();
  if (!normalized.startsWith('#')) {
    return pageBackground;
  }
  const hex = normalized.substring(1);
  if (hex.length === 6 && isHexColor(hex)) {
    return `#${alphaHex}${hex}`;
  }
  if (hex.length === 8 && isHexColor(hex)) {
    return `#${alphaHex}${hex.substring(2)}`;
  }
  return pageBackground;
}

function isHexColor(value: string): boolean {
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index);
    const isDigit = code >= 48 && code <= 57;
    const isUpperHex = code >= 65 && code <= 70;
    const isLowerHex = code >= 97 && code <= 102;
    if (!isDigit && !isUpperHex && !isLowerHex) {
      return false;
    }
  }
  return true;
}

export function resolveCrossDeviceLinkOrbitCoverHeight(layout: CrossDeviceLinkOrbitLayout): number {
  return layout.centerY + layout.logoSize / 2 + DESIGN_COVER_GAP * (layout.stageWidth / DESIGN_WIDTH);
}

/**
 * Scroll-linked fade. Offset 0 keeps the illustration fully visible. Once the
 * list has scrolled up by the rest gap, the illustration is gone.
 */
export function resolveCrossDeviceLinkOrbitScrollOpacity(scrollOffset: number, coverHeight: number): number {
  if (!(coverHeight > 0) || !(scrollOffset > 0)) {
    return 1;
  }
  if (scrollOffset >= coverHeight) {
    return 0;
  }
  return 1 - scrollOffset / coverHeight;
}

export function capCrossDeviceLinkOrbitStageWidth(measuredWidth: number): number {
  if (!(measuredWidth > 0)) {
    return 0;
  }
  return measuredWidth > DESIGN_WIDTH ? DESIGN_WIDTH : measuredWidth;
}

export function buildCrossDeviceLinkOrbitLayout(stageWidth: number): CrossDeviceLinkOrbitLayout {
  const scale = stageWidth / DESIGN_WIDTH;
  const centerX = stageWidth / 2;
  const centerY = DESIGN_CENTER_Y * scale;
  const innerRadius = 128 * scale;
  const middleRadius = 188 * scale;
  const outerRadius = DESIGN_OUTER_RADIUS * scale;
  const orbits: number[] = [innerRadius, middleRadius, outerRadius];
  const marks = ORBIT_MARKS.map((spec: CrossDeviceLinkOrbitMarkSpec): CrossDeviceLinkOrbitMarkPlacement => {
    const radius = spec.orbitIndex === 0 ? innerRadius : (spec.orbitIndex === 1 ? middleRadius : outerRadius);
    const radians = spec.angleDegrees * Math.PI / 180;
    return {
      kind: spec.kind,
      x: centerX + radius * Math.sin(radians),
      y: centerY - radius * Math.cos(radians),
      size: DESIGN_MARK_SIZE * scale,
      orbitRadius: radius,
      orbitIndex: spec.orbitIndex
    };
  });
  const stageHeight = DESIGN_STAGE_HEIGHT * scale;
  const diameterTop = centerY - outerRadius;
  const diameter = outerRadius * 2;
  return {
    stageWidth: stageWidth,
    stageHeight: stageHeight,
    centerX: centerX,
    centerY: centerY,
    logoSize: DESIGN_LOGO_SIZE * scale,
    orbits: orbits,
    marks: marks,
    topFadeHold: DESIGN_TOP_FADE_HOLD * scale / stageHeight,
    topFadeEnd: DESIGN_TOP_FADE_END * scale / stageHeight,
    fadeHold: centerY / stageHeight,
    fadeEnd: (diameterTop + diameter * DESIGN_FADE_END_FRACTION) / stageHeight
  };
}

export function crossDeviceLinkOrbitSpinPeriodMs(orbitIndex: number): number {
  if (orbitIndex === 0) {
    return CROSS_DEVICE_LINK_ORBIT_SPIN_PERIOD_INNER_MS;
  }
  if (orbitIndex === 1) {
    return CROSS_DEVICE_LINK_ORBIT_SPIN_PERIOD_MIDDLE_MS;
  }
  return CROSS_DEVICE_LINK_ORBIT_SPIN_PERIOD_OUTER_MS;
}

/**
 * Continuous revolution around the logo. Degrees since the reviewed pose, same
 * direction on every ring. Elapsed 0 is that pose; there is no entrance sweep.
 */
export function crossDeviceLinkOrbitSpinAngle(orbitIndex: number, elapsedMs: number): number {
  if (!(elapsedMs > 0)) {
    return 0;
  }
  const turns = elapsedMs / crossDeviceLinkOrbitSpinPeriodMs(orbitIndex);
  return (turns - Math.floor(turns)) * 360;
}
