/**
 * Page titles often glue a slogan or site name on with a divider. The page keeps its own
 * title; this is only the text we show on a tab.
 * 「知乎 - 有问题，就会有答案」→「知乎」. 「一篇文章_哔哩哔哩」→「一篇文章」.
 * 「一篇文章丨小红书」→「一篇文章」.
 *
 * ASCII "-" and "/" count only when spaces sit on both sides, so a date or a hyphenated
 * word stays whole. An underscore between two English words or digits stays, so hello_world
 * is not cut. A colon is part of the title, not a divider.
 */

const HARD_TITLE_SEPARATORS: string =
  '_＿|｜│∣¦丨·•・‧∙⋅–—－‐‑−‒―»›«‹>＞／';

export function shortenBrowserDisplayTitle(title: string): string {
  const trimmed = title.trim();
  if (trimmed.length === 0) {
    return trimmed;
  }
  const splitAt = findTitleSeparator(trimmed);
  if (splitAt <= 0) {
    return trimmed;
  }
  const head = trimmed.substring(0, splitAt).trim();
  let tailStart = splitAt;
  while (tailStart < trimmed.length && isTitleSeparatorOrSpace(trimmed.charAt(tailStart))) {
    tailStart++;
  }
  const tail = trimmed.substring(tailStart).trim();
  if (head.length === 0 || tail.length === 0) {
    return trimmed;
  }
  return head;
}

function findTitleSeparator(title: string): number {
  for (let index = 0; index < title.length; index++) {
    const mark = title.charAt(index);
    if (isHardTitleSeparator(mark)) {
      if (index <= 0 || !hasTitleTextAfter(title, index)) {
        continue;
      }
      if (isUnderscore(mark) && isAsciiWordJoin(title, index)) {
        continue;
      }
      return index;
    }
    if ((mark === '-' || mark === '/') && isSpacedSoftSeparator(title, index)) {
      return index - 1;
    }
  }
  return -1;
}

function isSpacedSoftSeparator(title: string, index: number): boolean {
  if (index <= 0 || !isTitleSpace(title.charAt(index - 1))) {
    return false;
  }
  let end = index;
  const mark = title.charAt(index);
  while (end < title.length && title.charAt(end) === mark) {
    end++;
  }
  if (end >= title.length || !isTitleSpace(title.charAt(end))) {
    return false;
  }
  return title.substring(0, index - 1).trim().length > 0 && hasTitleTextAfter(title, index);
}

function hasTitleTextAfter(title: string, separatorAt: number): boolean {
  let index = separatorAt;
  while (index < title.length && isTitleSeparatorOrSpace(title.charAt(index))) {
    index++;
  }
  return title.substring(index).trim().length > 0;
}

function isAsciiWordJoin(title: string, index: number): boolean {
  if (index <= 0 || index >= title.length - 1) {
    return false;
  }
  return isAsciiWordChar(title.charCodeAt(index - 1)) && isAsciiWordChar(title.charCodeAt(index + 1));
}

function isHardTitleSeparator(mark: string): boolean {
  return HARD_TITLE_SEPARATORS.indexOf(mark) >= 0;
}

function isUnderscore(mark: string): boolean {
  return mark === '_' || mark === '＿';
}

function isTitleSeparatorOrSpace(mark: string): boolean {
  return isTitleSpace(mark) || isHardTitleSeparator(mark) || mark === '-' || mark === '/';
}

function isTitleSpace(mark: string): boolean {
  return mark === ' ' || mark === '\t' || mark === '\u00A0' || mark === '\u3000';
}

function isAsciiWordChar(code: number): boolean {
  return (code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
}
