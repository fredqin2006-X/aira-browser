import {
  DEFAULT_SEARCH_ENGINE_ID,
  SearchEngineId,
  SearchEngineRecord,
  SearchEngineSettings,
  SearchSuggestionPreferences
} from '../../common/models/BrowserModels';
import { SearchEngineTemplateService } from '../../services/search/SearchEngineTemplateService';
import { resolveAppResourceText } from '../resources/AppResourceText';

export interface SearchEngineRowView {
  id: SearchEngineId;
  title: string;
  subtitle: string;
  isDefault: boolean;
  isEditable: boolean;
}

export interface SearchEngineManagementState {
  defaultEngineName: string;
  fallbackEnabled: boolean;
  fallbackEngineName: string;
  fallbackEngineSelectable: boolean;
  fallbackNoticeEnabled: boolean;
  fallbackInfoText: string;
  builtInEngines: SearchEngineRowView[];
  customEngines: SearchEngineRowView[];
  historySuggestionsEnabled: boolean;
  browsingHistorySuggestionsEnabled: boolean;
  bookmarkSuggestionsEnabled: boolean;
  openTabSuggestionsEnabled: boolean;
  remoteSuggestionsEnabled: boolean;
}

export interface BuiltInSearchEngineVisibilityRowView {
  id: SearchEngineId;
  title: string;
  isEnabled: boolean;
  isDefault: boolean;
  canDisable: boolean;
}

export interface SearchEngineEditorState {
  title: ResourceStr;
  name: string;
  searchUrlTemplate: string;
  errorMessage: string;
  saveEnabled: boolean;
  deleteEnabled: boolean;
}

export class SearchEngineManagementViewModel {
  private templateService: SearchEngineTemplateService = new SearchEngineTemplateService();

  buildState(settings: SearchEngineSettings, engines: SearchEngineRecord[]): SearchEngineManagementState {
    const defaultEngine = engines.find((engine: SearchEngineRecord) => engine.id === settings.defaultSearchEngineId) ??
      engines.find((engine: SearchEngineRecord) => engine.id === DEFAULT_SEARCH_ENGINE_ID);
    const fallbackEngine = engines.find((engine: SearchEngineRecord): boolean => {
      return engine.id === settings.fallbackSearch.fallbackSearchEngineId;
    });
    const rows = engines.map((engine: SearchEngineRecord): SearchEngineRowView => {
      return {
        id: engine.id,
        title: engine.name,
        subtitle: this.buildEngineSubtitle(engine),
        isDefault: engine.id === (defaultEngine?.id ?? DEFAULT_SEARCH_ENGINE_ID),
        isEditable: engine.isEditable
      };
    });
    return {
      defaultEngineName: defaultEngine?.name ?? 'Bing',
      fallbackEnabled: settings.fallbackSearch.enabled,
      fallbackEngineName: fallbackEngine?.name ?? this.resolveFallbackEngineName(settings, engines),
      fallbackEngineSelectable: engines.some((engine: SearchEngineRecord): boolean => {
        return engine.id !== (defaultEngine?.id ?? DEFAULT_SEARCH_ENGINE_ID);
      }),
      fallbackNoticeEnabled: settings.fallbackSearch.noticeEnabled !== false,
      fallbackInfoText: this.buildFallbackInfoText(),
      builtInEngines: rows.filter((row: SearchEngineRowView) => {
        return !row.isEditable;
      }),
      customEngines: rows.filter((row: SearchEngineRowView) => {
        return row.isEditable;
      }),
      historySuggestionsEnabled: settings.searchSuggestions.historyEnabled,
      browsingHistorySuggestionsEnabled: settings.searchSuggestions.browsingHistoryEnabled,
      bookmarkSuggestionsEnabled: settings.searchSuggestions.bookmarksEnabled,
      openTabSuggestionsEnabled: settings.searchSuggestions.openTabsEnabled,
      remoteSuggestionsEnabled: settings.searchSuggestions.remoteEnabled
    };
  }

  buildEditorState(engine: SearchEngineRecord | undefined, name: string, template: string): SearchEngineEditorState {
    const trimmedName = name.trim();
    const trimmedTemplate = template.trim();
    const validation = trimmedTemplate.length > 0 ? this.templateService.validateTemplate(trimmedTemplate) : undefined;
    const errorMessage = validation !== undefined && !validation.valid ? validation.errorMessage : '';
    const hasUsableName = trimmedName.length > 0 || (validation?.suggestedName ?? '').length > 0;
    return {
      title: engine === undefined ? resolveAppResourceText($r('app.string.settings_search_engine_add')) : resolveAppResourceText($r('app.string.settings_search_engine_edit')),
      name: name,
      searchUrlTemplate: template,
      errorMessage: errorMessage,
      saveEnabled: hasUsableName && trimmedTemplate.length > 0 && errorMessage.length === 0,
      deleteEnabled: engine?.isEditable === true
    };
  }

  buildEditorSubmitError(name: string, template: string): string {
    const trimmedTemplate = template.trim();
    if (trimmedTemplate.length === 0) {
      return resolveAppResourceText($r('app.string.settings_search_engine_url_required'));
    }
    const validation = this.templateService.validateTemplate(trimmedTemplate);
    if (!validation.valid) {
      return validation.errorMessage;
    }
    if (name.trim().length === 0 && validation.suggestedName.length === 0) {
      return resolveAppResourceText($r('app.string.settings_search_engine_name_required'));
    }
    return '';
  }

  buildDefaultEngineValue(state: SearchEngineManagementState): string {
    return state.defaultEngineName.length > 0 ? state.defaultEngineName : 'Bing';
  }

  buildFallbackEngineValue(state: SearchEngineManagementState): string {
    if (!state.fallbackEnabled) {
      return resolveAppResourceText($r('app.string.settings_search_engine_off'));
    }
    return state.fallbackEngineName.length > 0 ? state.fallbackEngineName : resolveAppResourceText($r('app.string.settings_search_engine_not_selected'));
  }

  buildBuiltInVisibilityRows(
    settings: SearchEngineSettings,
    builtInEngines: SearchEngineRecord[]
  ): BuiltInSearchEngineVisibilityRowView[] {
    return builtInEngines.map((engine: SearchEngineRecord): BuiltInSearchEngineVisibilityRowView => {
      const isDefault = engine.id === settings.defaultSearchEngineId;
      return {
        id: engine.id,
        title: engine.name,
        isEnabled: settings.enabledBuiltInEngineIds.indexOf(engine.id) >= 0 || isDefault,
        isDefault: isDefault,
        canDisable: !isDefault
      };
    });
  }

  buildFallbackEngineRows(settings: SearchEngineSettings, engines: SearchEngineRecord[]): SearchEngineRowView[] {
    return engines.filter((engine: SearchEngineRecord): boolean => {
      return engine.id !== settings.defaultSearchEngineId;
    }).map((engine: SearchEngineRecord): SearchEngineRowView => {
      return {
        id: engine.id,
        title: engine.name,
        subtitle: this.buildEngineSubtitle(engine),
        isDefault: engine.id === settings.fallbackSearch.fallbackSearchEngineId,
        isEditable: engine.isEditable
      };
    });
  }

  moveBuiltInEngineToIndex(
    rows: SearchEngineRowView[],
    engineId: SearchEngineId,
    targetIndex: number
  ): SearchEngineId[] {
    const orderedIds = rows.map((row: SearchEngineRowView): SearchEngineId => row.id);
    const currentIndex = orderedIds.indexOf(engineId);
    const normalizedTargetIndex = Math.max(0, Math.min(orderedIds.length - 1, targetIndex));
    if (currentIndex < 0 || currentIndex === normalizedTargetIndex) {
      return orderedIds;
    }
    orderedIds.splice(currentIndex, 1);
    orderedIds.splice(normalizedTargetIndex, 0, engineId);
    return orderedIds;
  }

  buildDeleteConfirmationMessage(engine: SearchEngineRecord): string {
    return resolveAppResourceText($r('app.string.settings_search_engine_delete_message'), engine.name);
  }

  buildSearchSuggestionPreferences(
    historyEnabled: boolean,
    remoteEnabled: boolean,
    browsingHistoryEnabled: boolean,
    bookmarksEnabled: boolean,
    openTabsEnabled: boolean
  ): SearchSuggestionPreferences {
    return {
      regularEnabled: true,
      privateEnabled: false,
      openTabsEnabled: openTabsEnabled,
      bookmarksEnabled: bookmarksEnabled,
      shortcutsEnabled: false,
      historyEnabled: historyEnabled,
      browsingHistoryEnabled: browsingHistoryEnabled,
      navigationSuggestionsChosen: true,
      remoteEnabled: remoteEnabled
    };
  }

  private buildFallbackInfoText(): string {
    return resolveAppResourceText($r('app.string.settings_search_engine_fallback_info_text'));
  }

  private buildEngineSubtitle(engine: SearchEngineRecord): string {
    const homepage = engine.homepageUrl.trim();
    if (homepage.length > 0) {
      return homepage;
    }
    return engine.searchUrlTemplate;
  }

  private resolveFallbackEngineName(settings: SearchEngineSettings, engines: SearchEngineRecord[]): string {
    const fallbackEngine = engines.find((engine: SearchEngineRecord): boolean => {
      return engine.id === settings.fallbackSearch.fallbackSearchEngineId;
    });
    if (fallbackEngine !== undefined) {
      return fallbackEngine.name;
    }
    const candidate = engines.find((engine: SearchEngineRecord): boolean => {
      return engine.id !== settings.defaultSearchEngineId;
    });
    return candidate?.name ?? '';
  }
}
