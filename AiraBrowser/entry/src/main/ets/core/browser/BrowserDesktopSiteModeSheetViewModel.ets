import { BrowserDesktopSiteMode } from '../../services/web/BrowserUserAgentService';

export interface BrowserDesktopSiteModeOptionState {
  mode: BrowserDesktopSiteMode;
  title: ResourceStr;
  helperText: ResourceStr;
  isSelected: boolean;
}

export interface BrowserDesktopSiteModeSheetState {
  options: BrowserDesktopSiteModeOptionState[];
  defaultUserAgentSummary: string;
}

export class BrowserDesktopSiteModeSheetViewModel {
  buildState(
    selectedMode: BrowserDesktopSiteMode,
    defaultUserAgentSummary: string
  ): BrowserDesktopSiteModeSheetState {
    return {
      options: [
        this.buildOption(
          'default',
          $r('app.string.site_version_mode_default'),
          $r('app.string.site_version_mode_default_helper', defaultUserAgentSummary),
          selectedMode
        ),
        this.buildOption(
          'mobile',
          $r('app.string.site_version_mode_mobile'),
          $r('app.string.site_version_mode_mobile_helper'),
          selectedMode
        ),
        this.buildOption(
          'desktop',
          $r('app.string.site_version_mode_desktop'),
          $r('app.string.site_version_mode_desktop_helper'),
          selectedMode
        )
      ],
      defaultUserAgentSummary: defaultUserAgentSummary
    };
  }

  resolveToolbarLabel(mode: BrowserDesktopSiteMode): ResourceStr {
    if (mode === 'desktop') {
      return $r('app.string.site_version_mode_desktop');
    }
    if (mode === 'mobile') {
      return $r('app.string.site_version_mode_mobile');
    }
    return $r('app.string.site_version_mode_default');
  }

  private buildOption(
    mode: BrowserDesktopSiteMode,
    title: ResourceStr,
    helperText: ResourceStr,
    selectedMode: BrowserDesktopSiteMode
  ): BrowserDesktopSiteModeOptionState {
    return {
      mode: mode,
      title: title,
      helperText: helperText,
      isSelected: selectedMode === mode
    };
  }
}
