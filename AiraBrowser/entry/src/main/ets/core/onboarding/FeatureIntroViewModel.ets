import { resolveAppResourceText } from '../resources/AppResourceText';

export interface FeatureIntroSlide {
  id: string;
  title: string;
  body: string;
}

const FEATURE_INTRO_SLIDES: FeatureIntroSlide[] = [
  {
    id: 'ad_block',
    title: '少一点广告打扰',
    body: '按你启用的规则过滤网页广告，也可以手动隐藏看不顺眼的元素。'
  },
  {
    id: 'video_takeover',
    title: '接管网页视频',
    body: '用 Aira 播放器控制网页里的真实视频，调倍速、切画面，也能下载。'
  },
  {
    id: 'user_scripts',
    title: '支持用户脚本',
    body: '导入脚本后，只在匹配的网站里改页面，也可以单独开关。'
  },
  {
    id: 'sync',
    title: '换一台，接着用',
    body: '书签和常用设置可以同步。配对电脑后，也能看到那边的标签页，把当前网页推过去。'
  }
];

const FEATURE_INTRO_NEXT_LABEL: string = '下一步';
const FEATURE_INTRO_DONE_LABEL: string = '下一步';
const FEATURE_INTRO_GATE_LABEL: string = '向右滑动开始使用';
const FEATURE_INTRO_GATE_SKIP_LABEL: string = '跳过';
const FEATURE_INTRO_SKIP_CONFIRM_TITLE: string = '跳过介绍';
const FEATURE_INTRO_SKIP_CONFIRM_MESSAGE: string = '跳过后将直接进入主页，不再显示这些介绍。';
const FEATURE_INTRO_SKIP_CONFIRM_CANCEL_LABEL: string = '取消';
const FEATURE_INTRO_SKIP_CONFIRM_ENTER_LABEL: string = '进入主页';

export class FeatureIntroViewModel {
  slides(): FeatureIntroSlide[] {
    return FEATURE_INTRO_SLIDES.map((slide: FeatureIntroSlide): FeatureIntroSlide => this.localizeSlide(slide));
  }

  actionLabel(index: number): string {
    return featureIntroText($r('app.string.settings_sync_next'),
      this.isLast(index) ? FEATURE_INTRO_DONE_LABEL : FEATURE_INTRO_NEXT_LABEL);
  }

  gateActionLabel(): string {
    return featureIntroText($r('app.string.feature_intro_gate_label'), FEATURE_INTRO_GATE_LABEL);
  }

  gateSkipLabel(): string {
    return featureIntroText($r('app.string.onboarding_ui_feature_intro_skip_control_001'), FEATURE_INTRO_GATE_SKIP_LABEL);
  }

  skipConfirmTitle(): string {
    return featureIntroText($r('app.string.feature_intro_skip_title'), FEATURE_INTRO_SKIP_CONFIRM_TITLE);
  }

  skipConfirmMessage(): string {
    return featureIntroText($r('app.string.feature_intro_skip_message'), FEATURE_INTRO_SKIP_CONFIRM_MESSAGE);
  }

  skipConfirmCancelLabel(): string {
    return featureIntroText($r('app.string.settings_custom_home_cancel'), FEATURE_INTRO_SKIP_CONFIRM_CANCEL_LABEL);
  }

  skipConfirmEnterLabel(): string {
    return featureIntroText($r('app.string.feature_intro_enter_home'), FEATURE_INTRO_SKIP_CONFIRM_ENTER_LABEL);
  }

  private localizeSlide(slide: FeatureIntroSlide): FeatureIntroSlide {
    switch (slide.id) {
      case 'ad_block':
        return {
          id: slide.id,
          title: featureIntroText($r('app.string.feature_intro_ad_block_title'), slide.title),
          body: featureIntroText($r('app.string.feature_intro_ad_block_body'), slide.body)
        };
      case 'video_takeover':
        return {
          id: slide.id,
          title: featureIntroText($r('app.string.feature_intro_video_title'), slide.title),
          body: featureIntroText($r('app.string.feature_intro_video_body'), slide.body)
        };
      case 'user_scripts':
        return {
          id: slide.id,
          title: featureIntroText($r('app.string.feature_intro_scripts_title'), slide.title),
          body: featureIntroText($r('app.string.feature_intro_scripts_body'), slide.body)
        };
      case 'sync':
        return {
          id: slide.id,
          title: featureIntroText($r('app.string.feature_intro_sync_title'), slide.title),
          body: featureIntroText($r('app.string.feature_intro_sync_body'), slide.body)
        };
      default:
        return slide;
    }
  }

  isLast(index: number): boolean {
    return index >= FEATURE_INTRO_SLIDES.length - 1;
  }
}

function featureIntroText(resource: Resource, fallback: string): string {
  const resolved = resolveAppResourceText(resource);
  return resolved.length > 0 ? resolved : fallback;
}
