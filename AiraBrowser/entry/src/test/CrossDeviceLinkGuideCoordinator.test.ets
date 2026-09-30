import { describe, expect, it } from '@ohos/hypium';
import {
  CrossDeviceLinkGuideCoordinator,
  CrossDeviceLinkGuideShell,
  CrossDeviceLinkGuideSnapshot
} from '../main/ets/core/onboarding/CrossDeviceLinkGuideCoordinator';
import {
  buildEmptyCrossDeviceLinkGuideState,
  CrossDeviceLinkGuideRepository,
  CrossDeviceLinkGuideState
} from '../main/ets/data/onboarding/CrossDeviceLinkGuideRepository';

class FixtureCrossDeviceLinkGuideRepository extends CrossDeviceLinkGuideRepository {
  storedState: CrossDeviceLinkGuideState = buildEmptyCrossDeviceLinkGuideState();
  memory: CrossDeviceLinkGuideState = buildEmptyCrossDeviceLinkGuideState();

  async initialize(): Promise<void> {
    this.memory = {
      shownAt: this.storedState.shownAt,
      completedAt: this.storedState.completedAt
    };
  }

  getState(): CrossDeviceLinkGuideState {
    return {
      shownAt: this.memory.shownAt,
      completedAt: this.memory.completedAt
    };
  }

  hasCompleted(): boolean {
    return this.memory.shownAt > 0 || this.memory.completedAt > 0;
  }

  async markShown(now: number = Date.now()): Promise<CrossDeviceLinkGuideState> {
    if (this.memory.shownAt <= 0) {
      this.memory.shownAt = now;
    }
    return this.getState();
  }

  async markCompleted(now: number = Date.now()): Promise<CrossDeviceLinkGuideState> {
    if (this.memory.completedAt <= 0) {
      this.memory.completedAt = now;
    }
    if (this.memory.shownAt <= 0) {
      this.memory.shownAt = now;
    }
    return this.getState();
  }
}

class FixtureCrossDeviceLinkGuideShell implements CrossDeviceLinkGuideShell {
  snapshots: CrossDeviceLinkGuideSnapshot[] = [];
  openGuideCount: number = 0;

  publishState(snapshot: CrossDeviceLinkGuideSnapshot): void {
    this.snapshots.push(snapshot);
  }

  openGuide(): void {
    this.openGuideCount += 1;
  }
}

interface GuideFixture {
  repository: FixtureCrossDeviceLinkGuideRepository;
  shell: FixtureCrossDeviceLinkGuideShell;
  coordinator: CrossDeviceLinkGuideCoordinator;
}

function buildGuideFixture(storedState?: CrossDeviceLinkGuideState): GuideFixture {
  const repository = new FixtureCrossDeviceLinkGuideRepository();
  if (storedState !== undefined) {
    repository.storedState = storedState;
    repository.memory = storedState;
  }
  const shell = new FixtureCrossDeviceLinkGuideShell();
  return {
    repository,
    shell,
    coordinator: new CrossDeviceLinkGuideCoordinator(repository, shell, 0)
  };
}

async function flushPresentation(): Promise<void> {
  for (let turn = 0; turn < 4; turn += 1) {
    await new Promise<void>((resolve: () => void): void => {
      setTimeout(resolve, 0);
    });
  }
}

export default function crossDeviceLinkGuideCoordinatorTest(): void {
  describe('CrossDeviceLinkGuideCoordinator', () => {
    it('shows the first step on the first page entry and keeps next on that step', 0, async () => {
      const fixture = buildGuideFixture();

      fixture.coordinator.handlePageEntered();
      await flushPresentation();

      expect(fixture.coordinator.getSnapshot().visible).assertTrue();
      expect(fixture.coordinator.getSnapshot().clipId).assertEqual('page_push');
      expect(fixture.coordinator.getSnapshot().primaryAction).assertEqual('next');
      expect(fixture.coordinator.getSnapshot().primaryActionTitle).assertEqual('下一个');
      expect(fixture.coordinator.getSnapshot().progressLabel).assertEqual('1/2');
      expect(fixture.shell.openGuideCount).assertEqual(0);
      expect(fixture.repository.hasCompleted()).assertTrue();
    });

    it('opens the interconnect guide only from the second step primary button', 0, async () => {
      const fixture = buildGuideFixture();

      fixture.coordinator.handlePageEntered();
      await flushPresentation();
      fixture.coordinator.handleAction('next');

      expect(fixture.coordinator.getSnapshot().visible).assertTrue();
      expect(fixture.coordinator.getSnapshot().clipId).assertEqual('device_tabs');
      expect(fixture.coordinator.getSnapshot().primaryAction).assertEqual('open_guide');
      expect(fixture.coordinator.getSnapshot().primaryActionTitle).assertEqual('查看互联教程');
      expect(fixture.shell.openGuideCount).assertEqual(0);

      fixture.coordinator.handleAction('next');
      expect(fixture.coordinator.getSnapshot().visible).assertTrue();
      expect(fixture.shell.openGuideCount).assertEqual(0);

      fixture.coordinator.handleAction('open_guide');
      expect(fixture.coordinator.getSnapshot().visible).assertFalse();
      expect(fixture.shell.openGuideCount).assertEqual(1);
      expect(fixture.repository.getState().completedAt > 0).assertTrue();
    });

    it('does not open the guide when the lesson is skipped or dismissed', 0, async () => {
      const skipped = buildGuideFixture();
      skipped.coordinator.handlePageEntered();
      await flushPresentation();
      skipped.coordinator.handleAction('never_show_again');
      expect(skipped.coordinator.getSnapshot().visible).assertFalse();
      expect(skipped.shell.openGuideCount).assertEqual(0);

      const dismissed = buildGuideFixture();
      dismissed.coordinator.handlePageEntered();
      await flushPresentation();
      dismissed.coordinator.handleAction('next');
      dismissed.coordinator.handleAction('dismiss');
      expect(dismissed.coordinator.getSnapshot().visible).assertFalse();
      expect(dismissed.shell.openGuideCount).assertEqual(0);
    });

    it('stays silent after this device has already seen the lesson', 0, async () => {
      const fixture = buildGuideFixture({ shownAt: 10, completedAt: 0 });

      fixture.coordinator.handlePageEntered();
      await flushPresentation();

      expect(fixture.coordinator.getSnapshot().visible).assertFalse();
      expect(fixture.shell.openGuideCount).assertEqual(0);
    });
  });
}
