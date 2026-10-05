import { describe, expect, it } from '@ohos/hypium';
import { MediaResourceTypeRules } from '../main/ets/features/mediaDiscovery/MediaResourceTypeRules';
import { MediaVideoTypeRules } from '../main/ets/features/mediaDiscovery/MediaVideoTypeRules';

export default function mediaTypeRulesTest(): void {
  describe('MediaTypeRules', () => {
    it('recognizes explicit and opaque video URLs', 0, () => {
      const rules = new MediaVideoTypeRules();

      expect(rules.classifyByUrl('https://cdn.example/video.mp4').kind).assertEqual('mp4');
      expect(rules.classifyByUrl('https://cdn.example/manifest.m3u8').kind).assertEqual('hls');
      expect(rules.classifyByUrl('https://cdn.example/download?file=episode.webm').kind).assertEqual('webm');
      expect(rules.classifyByUrl('https://cdn.example/stream/abcdefghijklmnopqrstuvwxyz').kind).assertEqual('mp4');
      expect(rules.classifyByUrl('https://cdn.example/page.html').kind).assertEqual('unknown');
    });

    it('keeps resource URL hints while rejecting known noise', 0, () => {
      const rules = new MediaResourceTypeRules();

      expect(rules.classifyByUrl('https://cdn.example/playlist/master.m3u8').family).assertEqual('manifest');
      expect(rules.classifyByUrl('https://cdn.example/video/episode').family).assertEqual('video');
      expect(rules.classifyByUrl('https://cdn.example/image.jpg').family).assertEqual('image');
      expect(rules.classifyByUrl('https://cdn.example/analytics/pixel.gif').noise).assertTrue();
      expect(rules.classifyByUrl('https://cdn.example/app.js').family).assertEqual('unknown');
    });
  });
}
