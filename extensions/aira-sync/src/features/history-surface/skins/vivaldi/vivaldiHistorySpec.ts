import { chromeHistoryCopy, type ChromeHistoryCopy } from '../chrome/chromeHistorySpec';

export function vivaldiHistoryCopy(language: string): ChromeHistoryCopy {
  const copy = chromeHistoryCopy(language);
  const zh = language.toLowerCase().startsWith('zh');
  return {
    ...copy,
    history: zh ? 'Vivaldi 历史记录' : 'Vivaldi History',
  };
}
