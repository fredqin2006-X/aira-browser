import { ChromeHistoryPage } from '../chrome/ChromeHistoryPage';
import { vivaldiHistoryCopy } from './vivaldiHistorySpec';

export function VivaldiHistoryPage() {
  return <ChromeHistoryPage copyFor={vivaldiHistoryCopy} Logo={VivaldiLogo} />;
}

function VivaldiLogo(_props: { theme: 'light' | 'dark' }) {
  const src = globalThis.chrome?.runtime?.getURL?.('history-skins/vivaldi-logo.png')
    || '/history-skins/vivaldi-logo.png';
  return <img src={src} width={24} height={24} alt="" />;
}
