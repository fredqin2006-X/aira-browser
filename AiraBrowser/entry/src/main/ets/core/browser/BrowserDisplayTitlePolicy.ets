const BROWSER_DISPLAY_TITLE_SEPARATORS: string[] = [' - ', ' – ', ' — ', ' | ', ' · ', ' － '];

/**
 * Page titles often glue a slogan on after the site or article name. The page keeps its own
 * title; this is only the text we show on a tab.
 * 「知乎 - 有问题，就会有答案」→「知乎」. 「一篇文章 - 知乎」→「一篇文章」.
 */
export function shortenBrowserDisplayTitle(title: string): string {
  const trimmed = title.trim();
  if (trimmed.length === 0) {
    return trimmed;
  }
  let splitAt = -1;
  let separatorLength = 0;
  BROWSER_DISPLAY_TITLE_SEPARATORS.forEach((separator: string): void => {
    const found = trimmed.indexOf(separator);
    if (found > 0 && (splitAt < 0 || found < splitAt)) {
      splitAt = found;
      separatorLength = separator.length;
    }
  });
  if (splitAt <= 0) {
    return trimmed;
  }
  const head = trimmed.substring(0, splitAt).trim();
  const tail = trimmed.substring(splitAt + separatorLength).trim();
  if (head.length === 0 || tail.length === 0) {
    return trimmed;
  }
  return head;
}
