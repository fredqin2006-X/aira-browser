import { resolveWebToolbarClearanceVp } from './BrowserWebToolbarClearancePolicy';
import { WebToolbarClearanceScriptService } from '../../services/web/WebToolbarClearanceScriptService';

export interface BrowserWebToolbarClearanceFacts {
  tabId: string;
  overlayActive: boolean;
  viewportReserved: boolean;
  bottomLiftVp: number;
}

export interface BrowserWebToolbarClearancePort {
  readFacts: () => BrowserWebToolbarClearanceFacts;
  runScript: (tabId: string, script: string) => void;
}

interface AppliedClearance {
  clearanceVp: number;
  generation: number;
}

/**
 * Keeps a trailing scroll spacer on web documents while the floating toolbar overlays them.
 * The spacer is not a viewport shrink: the page still paints under the capsule, and the extra
 * range only shows up at the end of the scroll, which is the part Safari's content inset covers.
 */
export class BrowserWebToolbarClearanceCoordinator {
  private port: BrowserWebToolbarClearancePort;
  private applied: Map<string, AppliedClearance> = new Map();
  private generationByTab: Map<string, number> = new Map();

  constructor(port: BrowserWebToolbarClearancePort) {
    this.port = port;
  }

  handleDocumentBegin(tabId: string): void {
    if (tabId.length === 0) return;
    this.applied.delete(tabId);
    this.generationByTab.set(tabId, (this.generationByTab.get(tabId) ?? 0) + 1);
  }

  apply(tabId: string, force: boolean = false): void {
    const facts = this.port.readFacts();
    const targetId = tabId.length > 0 ? tabId : facts.tabId;
    if (targetId.length === 0) return;
    const clearanceVp = resolveWebToolbarClearanceVp({
      overlayActive: facts.overlayActive,
      viewportReserved: targetId === facts.tabId && facts.viewportReserved,
      bottomLiftVp: facts.bottomLiftVp
    });
    const generation = this.generationByTab.get(targetId) ?? 0;
    const previous = this.applied.get(targetId);
    if (!force && previous !== undefined &&
      previous.clearanceVp === clearanceVp && previous.generation === generation) {
      return;
    }
    if (previous === undefined && clearanceVp === 0) {
      this.applied.set(targetId, { clearanceVp: 0, generation: generation });
      return;
    }
    this.port.runScript(targetId, WebToolbarClearanceScriptService.buildApplyScript(clearanceVp));
    this.applied.set(targetId, { clearanceVp: clearanceVp, generation: generation });
  }

  retainTabs(tabIds: string[]): void {
    const live = new Set<string>(tabIds);
    const staleApplied: string[] = [];
    this.applied.forEach((_value: AppliedClearance, tabId: string): void => {
      if (!live.has(tabId)) staleApplied.push(tabId);
    });
    staleApplied.forEach((tabId: string): void => {
      this.applied.delete(tabId);
    });
    const staleGenerations: string[] = [];
    this.generationByTab.forEach((_value: number, tabId: string): void => {
      if (!live.has(tabId)) staleGenerations.push(tabId);
    });
    staleGenerations.forEach((tabId: string): void => {
      this.generationByTab.delete(tabId);
    });
  }

  dispose(): void {
    this.applied.clear();
    this.generationByTab.clear();
  }
}
