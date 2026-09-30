export interface SettingsChangelogState {
  title: ResourceStr;
}

export class SettingsChangelogViewModel {
  buildState(): SettingsChangelogState {
    return {
      title: $r('app.string.settings_about_changelog')
    };
  }
}
