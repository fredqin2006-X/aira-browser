import { CrossDeviceBrowserIconKind } from './CrossDeviceBrowserIcon';

/** Same size on every tile. Rounded rectangle, not a circle, and not the Aira logo. */
export const CROSS_DEVICE_LINK_MARQUEE_TILE: number = 64;
export const CROSS_DEVICE_LINK_MARQUEE_RADIUS: number = 16;
export const CROSS_DEVICE_LINK_MARQUEE_GAP: number = 18;
export const CROSS_DEVICE_LINK_MARQUEE_ROW_GAP: number = 16;
/** One copy of a row. The track paints this twice so the loop has no seam. */
const MARQUEE_COPIES: number = 2;

const MARQUEE_LEFT: CrossDeviceBrowserIconKind[] = [
  'chrome', 'firefox', 'edge', 'brave', 'opera', 'vivaldi'
];
const MARQUEE_RIGHT: CrossDeviceBrowserIconKind[] = [
  'zen', 'floorp', 'librewolf', 'waterfox', 'generic', 'chrome'
];

/** Left row is a little quicker. Right row runs the other way. */
export const CROSS_DEVICE_LINK_MARQUEE_DURATION_LEFT_MS: number = 22000;
export const CROSS_DEVICE_LINK_MARQUEE_DURATION_RIGHT_MS: number = 26000;

export interface CrossDeviceLinkMarqueeTile {
  kind: CrossDeviceBrowserIconKind;
  key: string;
}

export function crossDeviceLinkMarqueeRowCount(): number {
  return 2;
}

export function crossDeviceLinkMarqueeTiles(rowIndex: number): CrossDeviceLinkMarqueeTile[] {
  const source = rowIndex === 0 ? MARQUEE_LEFT : MARQUEE_RIGHT;
  const tiles: CrossDeviceLinkMarqueeTile[] = [];
  for (let copy = 0; copy < MARQUEE_COPIES; copy++) {
    for (let index = 0; index < source.length; index++) {
      tiles.push({
        kind: source[index],
        key: `${rowIndex}:${copy}:${index}`
      });
    }
  }
  return tiles;
}

/** Width of one copy, including the gap after every tile, so a half-track shift is seamless. */
export function crossDeviceLinkMarqueeDistance(): number {
  return MARQUEE_LEFT.length * (CROSS_DEVICE_LINK_MARQUEE_TILE + CROSS_DEVICE_LINK_MARQUEE_GAP);
}

export function crossDeviceLinkMarqueeDurationMs(rowIndex: number): number {
  return rowIndex === 0
    ? CROSS_DEVICE_LINK_MARQUEE_DURATION_LEFT_MS
    : CROSS_DEVICE_LINK_MARQUEE_DURATION_RIGHT_MS;
}

/** -1 travels left. 1 travels right. */
export function crossDeviceLinkMarqueeDirection(rowIndex: number): number {
  return rowIndex === 0 ? -1 : 1;
}
