import { resolveAppResourceText } from '../resources/AppResourceText';

export type FeatureIntroSearchEngineChoiceId =
  'bing' |
  'baidu' |
  'google' |
  'sogou' |
  'qihoo' |
  'shenma';

export interface FeatureIntroSearchEngineChoice {
  id: FeatureIntroSearchEngineChoiceId;
  label: string;
}

const FEATURE_INTRO_SEARCH_ENGINE_TITLE: string = '选择默认搜索引擎';
const FEATURE_INTRO_SEARCH_ENGINE_SUBTITLE: string = '在地址栏搜索时会用它。之后也可以在设置里更改。';
const FEATURE_INTRO_SEARCH_ENGINE_CONTINUE_LABEL: string = '下一步';
const FEATURE_INTRO_SEARCH_ENGINE_SKIP_LABEL: string = '跳过';
const FEATURE_INTRO_SEARCH_ENGINE_DEFAULT_ID: FeatureIntroSearchEngineChoiceId = 'bing';
const FEATURE_INTRO_SEARCH_ENGINE_CHOICES: FeatureIntroSearchEngineChoice[] = [
  { id: 'bing', label: '必应' },
  { id: 'baidu', label: '百度' },
  { id: 'google', label: '谷歌' },
  { id: 'sogou', label: '搜狗' },
  { id: 'qihoo', label: '360搜索' },
  { id: 'shenma', label: '神马' }
];

export function resolveFeatureIntroSearchEngineChoice(value: string): FeatureIntroSearchEngineChoiceId {
  if (value === 'baidu') {
    return 'baidu';
  }
  if (value === 'google') {
    return 'google';
  }
  if (value === 'sogou') {
    return 'sogou';
  }
  if (value === 'qihoo') {
    return 'qihoo';
  }
  if (value === 'shenma') {
    return 'shenma';
  }
  return 'bing';
}

export class FeatureIntroSearchEngineViewModel {
  title(): string {
    return searchIntroText($r('app.string.search_intro_title'), FEATURE_INTRO_SEARCH_ENGINE_TITLE);
  }

  subtitle(): string {
    return searchIntroText($r('app.string.search_intro_subtitle'), FEATURE_INTRO_SEARCH_ENGINE_SUBTITLE);
  }

  continueLabel(): string {
    return searchIntroText($r('app.string.settings_sync_next'), FEATURE_INTRO_SEARCH_ENGINE_CONTINUE_LABEL);
  }

  skipLabel(): string {
    return searchIntroText($r('app.string.onboarding_ui_feature_intro_skip_control_001'), FEATURE_INTRO_SEARCH_ENGINE_SKIP_LABEL);
  }

  defaultChoiceId(): FeatureIntroSearchEngineChoiceId {
    return FEATURE_INTRO_SEARCH_ENGINE_DEFAULT_ID;
  }

  choices(): FeatureIntroSearchEngineChoice[] {
    return FEATURE_INTRO_SEARCH_ENGINE_CHOICES.map((choice: FeatureIntroSearchEngineChoice): FeatureIntroSearchEngineChoice => {
      return {
        id: choice.id,
        label: this.localizeChoiceLabel(choice)
      };
    });
  }

  private localizeChoiceLabel(choice: FeatureIntroSearchEngineChoice): string {
    switch (choice.id) {
      case 'baidu':
        return searchIntroText($r('app.string.search_engine_baidu'), choice.label);
      case 'google':
        return searchIntroText($r('app.string.search_engine_google'), choice.label);
      case 'sogou':
        return searchIntroText($r('app.string.search_engine_sogou'), choice.label);
      case 'qihoo':
        return searchIntroText($r('app.string.search_engine_360'), choice.label);
      case 'shenma':
        return searchIntroText($r('app.string.search_engine_shenma'), choice.label);
      default:
        return searchIntroText($r('app.string.search_engine_bing'), choice.label);
    }
  }
}

function searchIntroText(resource: Resource, fallback: string): string {
  const resolved = resolveAppResourceText(resource);
  return resolved.length > 0 ? resolved : fallback;
}
