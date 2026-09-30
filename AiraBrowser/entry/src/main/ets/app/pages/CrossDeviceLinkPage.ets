import { CrossDeviceLinkHost } from '../components/sync/CrossDeviceLinkHost';

/**
 * The page, not the host, owns the page lifecycle: only an @Entry component receives
 * onPageShow, and the host is an ordinary component inside it.
 */
@Entry
@Component
struct CrossDeviceLinkPage {
  @State private refreshToken: number = 0;
  @State private pageVisible: boolean = false;
  @State private guideVisible: boolean = false;
  @State private guideDismissToken: number = 0;

  onPageShow(): void {
    this.pageVisible = true;
    this.refreshToken += 1;
  }

  onPageHide(): void {
    this.pageVisible = false;
  }

  onBackPress(): boolean {
    if (!this.guideVisible) {
      return false;
    }
    this.guideDismissToken += 1;
    return true;
  }

  build() {
    Column() {
      CrossDeviceLinkHost({
        refreshToken: this.refreshToken,
        pageVisible: this.pageVisible,
        guideDismissToken: this.guideDismissToken,
        onGuideVisibility: (visible: boolean): void => {
          this.guideVisible = visible;
        }
      })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
