import { ReaderModeArticle, ReaderModeBlock } from './ReaderModeModels';
import { ReaderSpeechState } from './ReaderSpeechModels';

export interface ReaderSpeechPlayerSnapshot {
  title: ResourceStr;
  subtitle: ResourceStr;
  source: string;
  coverImageUrl: string;
  currentText: ResourceStr;
  progressLabel: ResourceStr;
  progressPercent: number;
  statusLabel: ResourceStr;
}

export class ReaderSpeechPlayerViewModel {
  buildSnapshot(article: ReaderModeArticle, chunks: string[], speechState: ReaderSpeechState): ReaderSpeechPlayerSnapshot {
    const currentIndex = this.resolveCurrentChunkIndex(speechState, chunks.length);
    return {
      title: this.resolveTitle(article),
      subtitle: this.resolveSubtitle(article),
      source: this.resolveSource(article),
      coverImageUrl: this.resolveCoverImageUrl(article),
      currentText: this.resolveCurrentText(chunks, currentIndex),
      progressLabel: this.resolveProgressLabel(speechState, chunks.length),
      progressPercent: this.resolveProgressPercent(speechState, chunks.length),
      statusLabel: this.resolveStatusLabel(speechState)
    };
  }

  resolvePreviousChunkIndex(speechState: ReaderSpeechState, totalChunks: number): number {
    const currentIndex = this.resolveCurrentChunkIndex(speechState, totalChunks);
    return Math.max(0, currentIndex - 1);
  }

  resolveNextChunkIndex(speechState: ReaderSpeechState, totalChunks: number): number {
    const currentIndex = this.resolveCurrentChunkIndex(speechState, totalChunks);
    return Math.min(Math.max(0, totalChunks - 1), currentIndex + 1);
  }

  resolveCurrentChunkStartIndex(speechState: ReaderSpeechState, totalChunks: number): number {
    return this.resolveCurrentChunkIndex(speechState, totalChunks);
  }

  private resolveCurrentChunkIndex(speechState: ReaderSpeechState, totalChunks: number): number {
    if (totalChunks <= 0) {
      return 0;
    }
    const index = speechState.currentChunkIndex > 0 ? speechState.currentChunkIndex - 1 : 0;
    return Math.max(0, Math.min(index, totalChunks - 1));
  }

  private resolveTitle(article: ReaderModeArticle): ResourceStr {
    const title = article.title.trim();
    return title.length > 0 ? title : $r('app.string.reader_speech_title');
  }

  private resolveSubtitle(article: ReaderModeArticle): ResourceStr {
    const parts: string[] = [];
    if (article.siteName.trim().length > 0) {
      parts.push(article.siteName.trim());
    }
    if (article.byline.trim().length > 0) {
      parts.push(article.byline.trim());
    }
    return parts.length > 0 ? parts.join(' · ') : $r('app.string.reader_reading_mode');
  }

  private resolveSource(article: ReaderModeArticle): string {
    if (article.url.trim().length <= 0) {
      return 'Aira';
    }
    const source = article.url.replace(/^https?:\/\//, '').split('/')[0];
    return source.length > 0 ? source : 'Aira';
  }

  private resolveCoverImageUrl(article: ReaderModeArticle): string {
    for (let index = 0; index < article.blocks.length; index += 1) {
      const block = article.blocks[index];
      if (block.type !== 'image') {
        continue;
      }
      const imageUrl = this.resolveBlockImageUrl(block);
      if (imageUrl.length > 0) {
        return imageUrl;
      }
    }
    return '';
  }

  private resolveBlockImageUrl(block: ReaderModeBlock): string {
    const urls: string[] = [];
    this.addImageUrl(urls, block.url ?? '');
    this.addImageUrl(urls, block.originalUrl ?? '');
    (block.fallbackUrls ?? []).forEach((url: string) => {
      this.addImageUrl(urls, url);
    });
    return urls.length > 0 ? urls[0] : '';
  }

  private addImageUrl(urls: string[], url: string): void {
    const normalized = url.trim();
    if (normalized.length <= 0 || urls.indexOf(normalized) >= 0) {
      return;
    }
    urls.push(normalized);
  }

  private resolveCurrentText(chunks: string[], currentIndex: number): ResourceStr {
    if (chunks.length <= 0) {
      return $r('app.string.reader_speech_ready_hint');
    }
    return chunks[currentIndex] ?? chunks[0];
  }

  private resolveProgressLabel(speechState: ReaderSpeechState, totalChunks: number): ResourceStr {
    if (totalChunks <= 0) {
      return $r('app.string.reader_speech_no_text');
    }
    const current = Math.max(1, Math.min(speechState.currentChunkIndex > 0 ? speechState.currentChunkIndex : 1, totalChunks));
    return $r('app.string.reader_speech_progress', current, totalChunks);
  }

  private resolveProgressPercent(speechState: ReaderSpeechState, totalChunks: number): number {
    if (totalChunks <= 0) {
      return 0;
    }
    const current = Math.max(0, Math.min(speechState.currentChunkIndex, totalChunks));
    return Math.round((current / totalChunks) * 100);
  }

  private resolveStatusLabel(speechState: ReaderSpeechState): ResourceStr {
    if (speechState.status === 'preparing') {
      return $r('app.string.reader_speech_status_preparing');
    }
    if (speechState.status === 'speaking') {
      return $r('app.string.reader_speech_status_speaking');
    }
    if (speechState.status === 'paused') {
      return $r('app.string.reader_speech_status_paused');
    }
    if (speechState.status === 'stopping') {
      return $r('app.string.reader_speech_status_stopping');
    }
    if (speechState.status === 'error') {
      return `${speechState.message}`.length > 0
        ? speechState.message
        : $r('app.string.reader_speech_status_failed');
    }
    return $r('app.string.reader_speech_status_idle');
  }
}
