export type ReaderSpeechPlaybackStatus = 'idle' | 'preparing' | 'speaking' | 'paused' | 'stopping' | 'error';

export interface ReaderSpeechState {
  status: ReaderSpeechPlaybackStatus;
  currentChunkIndex: number;
  totalChunks: number;
  message: ResourceStr;
}

export interface ReaderSpeechVoiceSelection {
  id: string;
  language: string;
  person: number;
  style: string;
}

export interface ReaderSpeechVoiceOption extends ReaderSpeechVoiceSelection {
  title: ResourceStr;
  helperText: ResourceStr;
  gender: string;
  status: string;
  isAvailable: boolean;
}

export function createDefaultReaderSpeechState(): ReaderSpeechState {
  return {
    status: 'idle',
    currentChunkIndex: 0,
    totalChunks: 0,
    message: ''
  };
}

export function isReaderSpeechActive(state: ReaderSpeechState): boolean {
  return state.status === 'preparing' || state.status === 'speaking' || state.status === 'stopping';
}

export function isReaderSpeechPaused(state: ReaderSpeechState): boolean {
  return state.status === 'paused';
}

export function shouldResetReaderSpeechStateOnStop(state: ReaderSpeechState): boolean {
  return state.status !== 'stopping' && state.status !== 'paused' && state.status !== 'preparing';
}

export function createDefaultReaderSpeechVoiceOption(): ReaderSpeechVoiceOption {
  return {
    id: buildReaderSpeechVoiceId('zh-CN', 0, 'interaction-broadcast'),
    title: $r('app.string.reader_voice_default'),
    helperText: $r('app.string.reader_voice_default_helper'),
    language: 'zh-CN',
    person: 0,
    style: 'interaction-broadcast',
    gender: '',
    status: '',
    isAvailable: true
  };
}

export function buildReaderSpeechVoiceId(language: string, person: number, style: string): string {
  return `${language.trim()}#${Math.floor(person)}#${style.trim()}`;
}
