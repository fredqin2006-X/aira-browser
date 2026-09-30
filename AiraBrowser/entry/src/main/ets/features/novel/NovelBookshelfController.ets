import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  cloneNovelBookshelfBook,
  NovelBookshelfBook,
  NovelBookshelfState
} from './NovelLibraryModels';
import {
  NovelLibraryRepository,
  sharedNovelLibraryRepository
} from '../../data/novel/NovelLibraryRepository';
import { NovelRuleCatalog, sharedNovelRuleCatalog } from '../../services/novel/NovelRuleCatalog';

const NOVEL_BOOKSHELF_LOG_DOMAIN: number = 0x0000;
const NOVEL_BOOKSHELF_LOG_TAG: string = 'AiraNovelShelf';

export interface NovelBookshelfRemovalResult {
  success: boolean;
  message: ResourceStr;
  state: NovelBookshelfState;
}

export class NovelBookshelfController {
  private readonly repository: NovelLibraryRepository;
  private readonly ruleCatalog: NovelRuleCatalog;

  constructor(
    repository: NovelLibraryRepository = sharedNovelLibraryRepository,
    ruleCatalog: NovelRuleCatalog = sharedNovelRuleCatalog
  ) {
    this.repository = repository;
    this.ruleCatalog = ruleCatalog;
  }

  async load(): Promise<NovelBookshelfState> {
    try {
      const books: NovelBookshelfBook[] = await this.repository.listBookshelf();
      const novels: NovelBookshelfBook[] = [];
      const comics: NovelBookshelfBook[] = [];
      books.forEach((book: NovelBookshelfBook): void => {
        const projection: NovelBookshelfBook = cloneNovelBookshelfBook(book);
        if (this.ruleCatalog.resolveContentKind(projection.detailUrl) === 'comic') {
          comics.push(projection);
        } else {
          novels.push(projection);
        }
      });
      return {
        loading: false,
        novels: novels,
        comics: comics,
        errorMessage: ''
      };
    } catch (error) {
      const errorCode: string = error instanceof Error ? error.message : 'unknown';
      hilog.error(
        NOVEL_BOOKSHELF_LOG_DOMAIN,
        NOVEL_BOOKSHELF_LOG_TAG,
        'Bookshelf load failed: %{public}s',
        errorCode
      );
      return {
        loading: false,
        novels: [],
        comics: [],
        errorMessage: $r('app.string.bookshelf_load_failed')
      };
    }
  }

  createLoadingState(): NovelBookshelfState {
    return {
      loading: true,
      novels: [],
      comics: [],
      errorMessage: ''
    };
  }

  async removeFromBookshelf(detailUrl: string): Promise<NovelBookshelfRemovalResult> {
    try {
      await this.repository.removeFromBookshelf(detailUrl);
      return {
        success: true,
        message: $r('app.string.bookshelf_removed'),
        state: await this.load()
      };
    } catch (error) {
      const errorCode: string = error instanceof Error ? error.message : 'unknown';
      hilog.error(
        NOVEL_BOOKSHELF_LOG_DOMAIN,
        NOVEL_BOOKSHELF_LOG_TAG,
        'Bookshelf removal failed: %{public}s',
        errorCode
      );
      return {
        success: false,
        message: $r('app.string.bookshelf_remove_failed'),
        state: await this.load()
      };
    }
  }
}
