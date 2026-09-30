import { BookmarkNode } from '../../common/models/BrowserModels';

const BOOKMARK_MANAGER_ROOT_TITLE: ResourceStr = $r('app.string.bookmark_manager');

export interface BookmarkFolderLocation {
  folderId: string;
  folderTitle: ResourceStr;
}

export class BookmarkFolderNavigationController {
  private currentFolderId: string = '';
  private currentFolderTitle: ResourceStr = BOOKMARK_MANAGER_ROOT_TITLE;
  private folderIdStack: string[] = [];
  private folderTitleStack: ResourceStr[] = [];

  reset(): void {
    this.currentFolderId = '';
    this.currentFolderTitle = BOOKMARK_MANAGER_ROOT_TITLE;
    this.folderIdStack = [];
    this.folderTitleStack = [];
  }

  enterFolder(folder: BookmarkNode): BookmarkFolderLocation {
    this.folderIdStack = this.folderIdStack.concat([this.currentFolderId]);
    this.folderTitleStack = this.folderTitleStack.concat([this.currentFolderTitle]);
    this.currentFolderId = folder.id;
    this.currentFolderTitle = folder.title;
    return this.getLocation();
  }

  canNavigateBack(): boolean {
    return this.folderIdStack.length > 0;
  }

  navigateBack(): BookmarkFolderLocation {
    if (!this.canNavigateBack()) {
      return this.getLocation();
    }
    const idStack = this.folderIdStack.slice();
    const titleStack = this.folderTitleStack.slice();
    const previousId = idStack.pop();
    const previousTitle = titleStack.pop();
    this.folderIdStack = idStack;
    this.folderTitleStack = titleStack;
    this.currentFolderId = previousId === undefined ? '' : previousId;
    this.currentFolderTitle = previousTitle === undefined ? BOOKMARK_MANAGER_ROOT_TITLE : previousTitle;
    return this.getLocation();
  }

  private getLocation(): BookmarkFolderLocation {
    return {
      folderId: this.currentFolderId,
      folderTitle: this.currentFolderTitle
    };
  }
}
