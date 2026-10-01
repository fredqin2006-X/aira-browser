import { describe, expect, it } from '@ohos/hypium';
import { shortenBrowserDisplayTitle } from '../main/ets/core/browser/BrowserDisplayTitlePolicy';

export default function browserDisplayTitlePolicyTest(): void {
  describe('shortenBrowserDisplayTitle', () => {
    it('drops the slogan after a spaced separator', 0, () => {
      expect(shortenBrowserDisplayTitle('知乎 - 有问题，就会有答案')).assertEqual('知乎');
      expect(shortenBrowserDisplayTitle('少数派 - 高效工作，品质生活')).assertEqual('少数派');
      expect(shortenBrowserDisplayTitle('一篇文章 - 知乎')).assertEqual('一篇文章');
      expect(shortenBrowserDisplayTitle('少数派 | 高效工作，品质生活')).assertEqual('少数派');
      expect(shortenBrowserDisplayTitle('少数派 · 高效工作，品质生活')).assertEqual('少数派');
    });

    it('drops the part after an underscore, bar, dot, or dash used as a separator', 0, () => {
      expect(shortenBrowserDisplayTitle('一篇文章_哔哩哔哩_bilibili')).assertEqual('一篇文章');
      expect(shortenBrowserDisplayTitle('知乎_有问题，就会有答案')).assertEqual('知乎');
      expect(shortenBrowserDisplayTitle('少数派 _ 高效工作，品质生活')).assertEqual('少数派');
      expect(shortenBrowserDisplayTitle('一篇文章丨小红书')).assertEqual('一篇文章');
      expect(shortenBrowserDisplayTitle('一篇文章｜网站')).assertEqual('一篇文章');
      expect(shortenBrowserDisplayTitle('一篇文章|网站')).assertEqual('一篇文章');
      expect(shortenBrowserDisplayTitle('一篇文章·网站')).assertEqual('一篇文章');
      expect(shortenBrowserDisplayTitle('一篇文章・网站')).assertEqual('一篇文章');
      expect(shortenBrowserDisplayTitle('一篇文章－网站')).assertEqual('一篇文章');
      expect(shortenBrowserDisplayTitle('一篇文章—网站')).assertEqual('一篇文章');
      expect(shortenBrowserDisplayTitle('一篇文章 / 网站')).assertEqual('一篇文章');
      expect(shortenBrowserDisplayTitle('Home » Article')).assertEqual('Home');
      expect(shortenBrowserDisplayTitle('hello_world')).assertEqual('hello_world');
      expect(shortenBrowserDisplayTitle('iPhone_15 review')).assertEqual('iPhone_15 review');
      expect(shortenBrowserDisplayTitle('2024/10/01 发布')).assertEqual('2024/10/01 发布');
      expect(shortenBrowserDisplayTitle('新闻：今天的标题')).assertEqual('新闻：今天的标题');
    });

    it('keeps a title that has no spaced separator', 0, () => {
      expect(shortenBrowserDisplayTitle('知乎')).assertEqual('知乎');
      expect(shortenBrowserDisplayTitle('哔哩哔哩 (゜-゜)つロ 干杯~-bilibili')).assertEqual(
        '哔哩哔哩 (゜-゜)つロ 干杯~-bilibili');
      expect(shortenBrowserDisplayTitle('  知乎  ')).assertEqual('知乎');
      expect(shortenBrowserDisplayTitle('')).assertEqual('');
    });

    it('keeps the first segment when a title has more than one separator', 0, () => {
      expect(shortenBrowserDisplayTitle('一篇文章 - 知乎 - 有问题，就会有答案')).assertEqual('一篇文章');
    });
  });
}
