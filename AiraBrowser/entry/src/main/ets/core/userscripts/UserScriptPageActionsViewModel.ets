import { webview } from '@kit.ArkWeb';
import { InstalledUserScriptState, UserScriptRunAt } from '../../features/userscripts/UserScriptMetadataModels';
import {
  UserScriptPageActionsState,
  UserScriptPageMenuCommandView,
  UserScriptPageScriptStatusView,
  UserScriptRuntimeEligibility
} from '../../features/userscripts/UserScriptRuntimeModels';
import {
  UserScriptRuntimeCompatibilityCommand,
  UserScriptRuntimeCompatibilityService
} from '../../services/userscripts/UserScriptRuntimeCompatibilityService';
import { normalizeUserScriptJavaScriptResult } from '../../services/userscripts/UserScriptJavaScriptResultCodec';
import { resolveAppResourceText } from '../resources/AppResourceText';

interface RawUserScriptPageMenuCommand {
  scriptId?: string;
  commandId?: string;
  commandName?: string;
}

export class UserScriptPageActionsViewModel {
  private readonly compatibilityService: UserScriptRuntimeCompatibilityService =
    new UserScriptRuntimeCompatibilityService();

  createInitialState(): UserScriptPageActionsState {
    return {
      url: '',
      message: resolveAppResourceText($r('app.string.user_script_page_actions_initial')),
      hasPage: false,
      hasMatchingScripts: false,
      hasMenuCommands: false,
      matchingScriptCount: 0,
      commands: [],
      scripts: []
    };
  }

  async buildState(
    url: string,
    controller: webview.WebviewController | undefined,
    eligibility: UserScriptRuntimeEligibility
  ): Promise<UserScriptPageActionsState> {
    const normalizedUrl = url.trim();
    if (normalizedUrl.length === 0) {
      return this.createInitialState();
    }
    const matchingScripts = eligibility.matchingScripts;
    const scriptStatuses = this.buildScriptViews(matchingScripts);
    if (eligibility.blockReason === 'private_mode') {
      return this.buildNoCommandsState(
        normalizedUrl,
        matchingScripts.length,
        resolveAppResourceText($r('app.string.user_script_page_actions_private_mode')),
        scriptStatuses
      );
    }
    if (!eligibility.executionAllowed) {
      return this.buildNoCommandsState(
        normalizedUrl,
        matchingScripts.length,
        resolveAppResourceText($r('app.string.user_script_page_actions_site_disabled')),
        scriptStatuses
      );
    }
    if (controller === undefined) {
      return this.buildNoCommandsState(
        normalizedUrl,
        matchingScripts.length,
        resolveAppResourceText($r('app.string.user_script_page_actions_no_controller')),
        scriptStatuses
      );
    }
    if (matchingScripts.length === 0) {
      return this.buildNoCommandsState(
        normalizedUrl,
        0,
        resolveAppResourceText($r('app.string.user_script_page_actions_no_match')),
        []
      );
    }

    const rawResult = await controller.runJavaScript(this.buildReadMenuCommandsScript());
    let commands = this.normalizeMenuCommands(rawResult, matchingScripts);
    commands = this.appendManualScriptCommands(commands, matchingScripts, ['main-menu', 'tool-menu']);
    commands = this.appendCompatibilityCommands(commands, matchingScripts);
    if (commands.length === 0) {
      return this.buildNoCommandsState(
        normalizedUrl,
        matchingScripts.length,
        resolveAppResourceText($r('app.string.user_script_page_actions_no_commands'), matchingScripts.length),
        scriptStatuses
      );
    }
    return {
      url: normalizedUrl,
      message: resolveAppResourceText(
        $r('app.string.user_script_page_actions_commands_available'),
        matchingScripts.length,
        commands.length
      ),
      hasPage: true,
      hasMatchingScripts: true,
      hasMenuCommands: true,
      matchingScriptCount: matchingScripts.length,
      commands: commands,
      scripts: scriptStatuses
    };
  }

  buildContextMenuCommands(eligibility: UserScriptRuntimeEligibility): UserScriptPageMenuCommandView[] {
    if (!eligibility.executionAllowed) {
      return [];
    }
    return this.buildManualScriptCommands(eligibility.matchingScripts, ['context-menu']);
  }

  private buildNoCommandsState(
    url: string,
    matchingScriptCount: number,
    message: string,
    scripts: UserScriptPageScriptStatusView[]
  ): UserScriptPageActionsState {
    return {
      url: url,
      message: message,
      hasPage: url.trim().length > 0,
      hasMatchingScripts: matchingScriptCount > 0,
      hasMenuCommands: false,
      matchingScriptCount: matchingScriptCount,
      commands: [],
      scripts: scripts
    };
  }

  private buildScriptViews(matchingScripts: InstalledUserScriptState[]): UserScriptPageScriptStatusView[] {
    return matchingScripts.map((script: InstalledUserScriptState): UserScriptPageScriptStatusView => {
      return {
        scriptId: script.id,
        scriptName: script.name,
        iconUrl: script.iconUrl
      };
    });
  }

  private buildReadMenuCommandsScript(): string {
    return `
;(function airaReadUserScriptMenus() {
  var menus = window.__airaUserScriptMenus || {};
  var results = [];
  Object.keys(menus).forEach(function(scriptId) {
    var commands = menus[scriptId] || {};
    Object.keys(commands).forEach(function(commandId) {
      var command = commands[commandId] || {};
      results.push({
        scriptId: String(scriptId || ''),
        commandId: String(commandId || ''),
        commandName: String(command.title || command.name || '')
      });
    });
  });
  return JSON.stringify(results);
})();
`;
  }

  private normalizeMenuCommands(
    rawResult: Object | string | number | boolean | undefined,
    matchingScripts: InstalledUserScriptState[]
  ): UserScriptPageMenuCommandView[] {
    const scriptMap = this.buildScriptMap(matchingScripts);
    const parsed = this.parseJsonArray(rawResult) as RawUserScriptPageMenuCommand[];
    const results: UserScriptPageMenuCommandView[] = [];
    parsed.forEach((value: RawUserScriptPageMenuCommand) => {
      const scriptId = String(value.scriptId ?? '').trim();
      const commandId = String(value.commandId ?? '').trim();
      const script = scriptMap[scriptId];
      if (scriptId.length === 0 || commandId.length === 0 || script === undefined) {
        return;
      }
      const commandName = String(value.commandName ?? '').trim();
      results.push({
        id: `${scriptId}:${commandId}`,
        scriptId: scriptId,
        commandId: commandId,
        scriptName: script.name,
        commandName: commandName.length > 0
          ? this.normalizeCommandDisplayName(script, commandName)
          : resolveAppResourceText($r('app.string.user_script_page_actions_default_command'))
      });
    });
    return results;
  }

  private normalizeCommandDisplayName(script: InstalledUserScriptState, name: string): string {
    const trimmedName = name.trim()
      .replace(/^[💡⚙️✅✔☑️❌✖✕]+\s*/u, '')
      .replace(/[✅✔☑️❌✖✕]\s*$/u, '')
      .trim();
    if (trimmedName.indexOf('已启用') >= 0 && trimmedName.indexOf('禁用') >= 0) {
      return resolveAppResourceText($r('app.string.user_script_page_actions_pause_site'));
    }
    if (trimmedName.indexOf('已禁用') >= 0 && trimmedName.indexOf('启用') >= 0) {
      return resolveAppResourceText($r('app.string.user_script_page_actions_allow_site'));
    }
    return this.compatibilityService.normalizeRegisteredMenuCommandDisplayName(script, trimmedName);
  }

  private appendManualScriptCommands(
    commands: UserScriptPageMenuCommandView[],
    matchingScripts: InstalledUserScriptState[],
    runAts: UserScriptRunAt[]
  ): UserScriptPageMenuCommandView[] {
    const results = commands.slice();
    this.buildManualScriptCommands(matchingScripts, runAts).forEach((command: UserScriptPageMenuCommandView) => {
      const exists = results.some((item: UserScriptPageMenuCommandView) => item.id === command.id);
      if (!exists) {
        results.push(command);
      }
    });
    return results;
  }

  private buildManualScriptCommands(
    matchingScripts: InstalledUserScriptState[],
    runAts: UserScriptRunAt[]
  ): UserScriptPageMenuCommandView[] {
    const results: UserScriptPageMenuCommandView[] = [];
    matchingScripts.forEach((script: InstalledUserScriptState) => {
      if (!runAts.includes(script.runAt)) {
        return;
      }
      results.push({
        id: `${script.id}:__aira_run_script__`,
        scriptId: script.id,
        commandId: '__aira_run_script__',
        scriptName: script.name,
        commandName: script.runAt === 'context-menu'
          ? script.name
          : resolveAppResourceText($r('app.string.user_script_page_actions_run_command'), script.name)
      });
    });
    return results;
  }

  private appendCompatibilityCommands(
    commands: UserScriptPageMenuCommandView[],
    matchingScripts: InstalledUserScriptState[]
  ): UserScriptPageMenuCommandView[] {
    const results = commands.slice();
    matchingScripts.forEach((script: InstalledUserScriptState) => {
      const hasScriptCommand = results.some((command: UserScriptPageMenuCommandView) => {
        return command.scriptId === script.id;
      });
      if (hasScriptCommand) {
        return;
      }
      const compatibilityCommand: UserScriptRuntimeCompatibilityCommand | undefined =
        this.compatibilityService.resolveFallbackMenuCommand(script);
      if (compatibilityCommand === undefined) {
        return;
      }
      results.push({
        id: `${script.id}:${compatibilityCommand.commandId}`,
        scriptId: script.id,
        commandId: compatibilityCommand.commandId,
        scriptName: script.name,
        commandName: compatibilityCommand.commandName
      });
    });
    return results;
  }

  private buildScriptMap(scripts: InstalledUserScriptState[]): Record<string, InstalledUserScriptState | undefined> {
    const results: Record<string, InstalledUserScriptState | undefined> = {};
    scripts.forEach((script: InstalledUserScriptState) => {
      results[script.id] = script;
    });
    return results;
  }

  private parseJsonArray(rawResult: Object | string | number | boolean | undefined): Object[] {
    const normalized = normalizeUserScriptJavaScriptResult(rawResult);
    if (normalized.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(normalized) as Object[];
      return Array.isArray(parsed) ? parsed : [];
    } catch (_error) {
      return [];
    }
  }
}
