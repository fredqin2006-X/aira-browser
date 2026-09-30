import { UserScriptPackageSuccessResult } from './UserScriptPackageLifecycleCoordinator';
import { resolveAppResourceText } from '../resources/AppResourceText';

export const USER_SCRIPT_FEATURE_TITLE: ResourceStr = $r('app.string.user_script_title');

export interface UserScriptPackageSuccessPromptCopy {
  title: string;
  subtitle: string;
}

export function formatOpenUserScriptsPageError(error: Error): string {
  return resolveAppResourceText($r('app.string.user_script_open_page_failed'), JSON.stringify(error));
}

export function formatUserScriptPackageCommitMessage(result: UserScriptPackageSuccessResult): string {
  const copy = buildUserScriptPackageSuccessPromptCopy(result);
  return resolveAppResourceText($r('app.string.user_script_commit_message'), copy.title, copy.subtitle);
}

export function buildUserScriptPackageSuccessPromptCopy(
  result: UserScriptPackageSuccessResult
): UserScriptPackageSuccessPromptCopy {
  return {
    title: result.status === 'updated'
      ? resolveAppResourceText($r('app.string.user_script_updated_title'))
      : resolveAppResourceText($r('app.string.user_script_installed_title')),
    subtitle: result.warnings.length > 0
      ? resolveAppResourceText($r('app.string.user_script_partial_capability'), result.scriptName)
      : result.scriptName
  };
}
