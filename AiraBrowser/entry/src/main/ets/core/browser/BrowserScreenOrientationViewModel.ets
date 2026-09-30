export type BrowserScreenOrientationMode = 'system' | 'portrait' | 'landscape';

export interface BrowserScreenOrientationOptionState {
  mode: BrowserScreenOrientationMode;
  title: ResourceStr;
  helperText: ResourceStr;
  icon: Resource;
  isSelected: boolean;
}

export class BrowserScreenOrientationViewModel {
  buildOptions(selectedMode: BrowserScreenOrientationMode): BrowserScreenOrientationOptionState[] {
    return [
      this.buildOption(
        'system',
        $r('app.string.settings_screen_orientation_system_title'),
        $r('app.string.settings_screen_orientation_system_helper'),
        $r('sys.symbol.gyroscope'),
        selectedMode
      ),
      this.buildOption(
        'portrait',
        $r('app.string.settings_screen_orientation_portrait_title'),
        $r('app.string.settings_screen_orientation_portrait_helper'),
        $r('sys.symbol.rectangle'),
        selectedMode
      ),
      this.buildOption(
        'landscape',
        $r('app.string.settings_screen_orientation_landscape_title'),
        $r('app.string.settings_screen_orientation_landscape_helper'),
        $r('sys.symbol.rectangle_on_rectangle_fill'),
        selectedMode
      )
    ];
  }

  resolveLabel(mode: BrowserScreenOrientationMode): ResourceStr {
    if (mode === 'portrait') {
      return $r('app.string.settings_screen_orientation_portrait_title');
    }
    if (mode === 'landscape') {
      return $r('app.string.settings_screen_orientation_landscape_title');
    }
    return $r('app.string.settings_screen_orientation_system_title');
  }

  resolveIcon(mode: BrowserScreenOrientationMode): Resource {
    if (mode === 'portrait') {
      return $r('sys.symbol.rectangle');
    }
    if (mode === 'landscape') {
      return $r('sys.symbol.rectangle_on_rectangle_fill');
    }
    return $r('sys.symbol.gyroscope');
  }

  private buildOption(
    mode: BrowserScreenOrientationMode,
    title: ResourceStr,
    helperText: ResourceStr,
    icon: Resource,
    selectedMode: BrowserScreenOrientationMode
  ): BrowserScreenOrientationOptionState {
    return {
      mode: mode,
      title: title,
      helperText: helperText,
      icon: icon,
      isSelected: mode === selectedMode
    };
  }
}
