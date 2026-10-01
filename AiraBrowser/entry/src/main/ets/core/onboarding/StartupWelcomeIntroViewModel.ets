import { resolveAppResourceText } from '../resources/AppResourceText';

export type StartupWelcomeIntroActionId = 'personal_server' | 'webdav';

export interface StartupWelcomeIntroActionState {
  id: StartupWelcomeIntroActionId;
  label: string;
}

export interface StartupWelcomeIntroHeroState {
  title: string;
  subtitle: string;
}

export interface StartupWelcomeIntroFacts {
  /** Huawei account sign-in is an Official-only capability. */
  huaweiAccountAvailable: boolean;
  /** Basic service mode hides account and sync entirely. */
  optionalServiceAvailable: boolean;
}

export interface StartupWelcomeIntroViewState {
  hero: StartupWelcomeIntroHeroState;
  /** The real Huawei ID button is rendered inline, not as a plain action row. */
  showHuaweiLogin: boolean;
  actions: StartupWelcomeIntroActionState[];
  previousActionLabel: string;
  skipActionLabel: string;
}

const STARTUP_WELCOME_INTRO_HERO_SIGN_IN: StartupWelcomeIntroHeroState = {
  title: '登录账号',
  subtitle: '登录华为账号，或连接你自己的服务器。也可以先跳过，之后在设置里再登录。'
};

const STARTUP_WELCOME_INTRO_HERO_SELF_HOSTED: StartupWelcomeIntroHeroState = {
  title: '连接服务器',
  subtitle: '连接私有化部署或 WebDAV。也可以先跳过，之后在设置里再连接。'
};

const STARTUP_WELCOME_INTRO_HERO_BASIC_MODE: StartupWelcomeIntroHeroState = {
  title: '欢迎使用 Aira',
  subtitle: '当前处于精简模式，账号与同步功能需要切换到全量模式后使用。你可以先直接开始浏览。'
};

const STARTUP_WELCOME_INTRO_PREVIOUS_ACTION_LABEL: string = '上一步';
const STARTUP_WELCOME_INTRO_SKIP_ACTION_LABEL: string = '跳过';

export class StartupWelcomeIntroViewModel {
  buildState(facts: StartupWelcomeIntroFacts): StartupWelcomeIntroViewState {
    return {
      hero: this.resolveHero(facts),
      showHuaweiLogin: facts.optionalServiceAvailable && facts.huaweiAccountAvailable,
      actions: this.buildActions(facts),
      previousActionLabel: welcomeText($r('app.string.feature_intro_previous'), STARTUP_WELCOME_INTRO_PREVIOUS_ACTION_LABEL),
      skipActionLabel: welcomeText($r('app.string.onboarding_ui_feature_intro_skip_control_001'), STARTUP_WELCOME_INTRO_SKIP_ACTION_LABEL)
    };
  }

  private buildActions(facts: StartupWelcomeIntroFacts): StartupWelcomeIntroActionState[] {
    if (!facts.optionalServiceAvailable) {
      return [];
    }
    return [
      {
        id: 'personal_server',
        label: welcomeText($r('app.string.startup_welcome_personal_server'), '使用私有化部署同步')
      },
      {
        id: 'webdav',
        label: welcomeText($r('app.string.settings_sync_goal_webdav'), 'WebDAV 同步')
      }
    ];
  }

  private resolveHero(facts: StartupWelcomeIntroFacts): StartupWelcomeIntroHeroState {
    if (!facts.optionalServiceAvailable) {
      return this.localizeHero(STARTUP_WELCOME_INTRO_HERO_BASIC_MODE, 'basic');
    }
    return facts.huaweiAccountAvailable
      ? this.localizeHero(STARTUP_WELCOME_INTRO_HERO_SIGN_IN, 'sign_in')
      : this.localizeHero(STARTUP_WELCOME_INTRO_HERO_SELF_HOSTED, 'server');
  }

  private localizeHero(hero: StartupWelcomeIntroHeroState, kind: string): StartupWelcomeIntroHeroState {
    if (kind === 'basic') {
      return {
        title: welcomeText($r('app.string.startup_welcome_basic_title'), hero.title),
        subtitle: welcomeText($r('app.string.startup_welcome_basic_subtitle'), hero.subtitle)
      };
    }
    if (kind === 'server') {
      return {
        title: welcomeText($r('app.string.startup_welcome_server_title'), hero.title),
        subtitle: welcomeText($r('app.string.startup_welcome_server_subtitle'), hero.subtitle)
      };
    }
    return {
      title: welcomeText($r('app.string.startup_welcome_sign_in_title'), hero.title),
      subtitle: welcomeText($r('app.string.startup_welcome_sign_in_subtitle'), hero.subtitle)
    };
  }
}

function welcomeText(resource: Resource, fallback: string): string {
  const resolved = resolveAppResourceText(resource);
  return resolved.length > 0 ? resolved : fallback;
}
