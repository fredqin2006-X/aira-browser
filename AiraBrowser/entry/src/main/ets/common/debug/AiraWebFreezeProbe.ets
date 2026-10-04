import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'WebFreezeDiag';
const PREFIX: string = '[DEBUG-web-freeze-9f2a]';
const UI_TICK_MS: number = 50;
const UI_LATE_LOG_MS: number = 100;
const UI_HEARTBEAT_MS: number = 5000;
const UI_PROBE_WINDOW_MS: number = 120000;
const TOUCH_MOVE_FROZEN_LOG_MS: number = 400;
const TOUCH_MOVE_IDLE_LOG_MS: number = 2000;
const PULL_DELAYS_MS: number[] = [1500, 4000, 8000, 15000, 30000, 50000, 80000];

const SNAPSHOT_SCRIPT: string = `(() => {
  try {
    var diag = window.__airaFreezeDiag;
    if (!diag || typeof diag.snapshot !== 'function') return 'missing';
    return String(diag.snapshot());
  } catch (error) {
    return 'err';
  }
})()`;

/**
 * Temporary probe for "this page is frozen, then suddenly scrolls".
 * Grep [DEBUG-web-freeze-9f2a] to remove.
 *
 * Three clocks, because a freeze can sit in different processes:
 * - `ui_late` is the ArkTS UI thread. If that thread is blocked, ArkWeb does not receive the
 *   gesture even though the finger is on the Web.
 * - `snapshot queueLate` is how late the UI timer was when it asked the page; `jsDelay` is how long
 *   `runJavaScript` then waited. A large `jsDelay` with a small `queueLate` means the renderer was
 *   blocked while the app UI thread was free.
 * - the snapshot fields are the page's own account: touch delivery, preventDefault, document lock,
 *   EventSource progress, and how late the page's own timer fired (`lateMax`).
 */
export class AiraWebFreezeProbe {
  private static generation: number = 0;
  private static controller: webview.WebviewController | undefined = undefined;
  private static pageStartedAt: number = 0;
  private static uiRunningGeneration: number = -1;
  private static uiExpectedAt: number = 0;
  private static uiMaxLateMs: number = 0;
  private static uiLastHeartbeatAt: number = 0;
  private static moves: number = 0;
  private static movesSinceScroll: number = 0;
  private static scrolls: number = 0;
  private static lastScrollY: number = -1;
  private static lastMoveLogAt: number = 0;
  private static lastScrollLogAt: number = 0;
  private static lastSnapshot: string = '';

  static buildCostLedgerScriptItem(): ScriptItem {
    return {
      script: FREEZE_COST_LEDGER_SCRIPT,
      scriptRules: ['*']
    };
  }

  static buildDocumentStartScriptItem(): ScriptItem {
    return {
      script: FREEZE_DIAGNOSIS_DOCUMENT_START_SCRIPT,
      scriptRules: ['*']
    };
  }

  static notePageBegin(tabId: string, url: string, controller: webview.WebviewController): void {
    AiraWebFreezeProbe.generation += 1;
    AiraWebFreezeProbe.controller = controller;
    AiraWebFreezeProbe.pageStartedAt = Date.now();
    AiraWebFreezeProbe.moves = 0;
    AiraWebFreezeProbe.movesSinceScroll = 0;
    AiraWebFreezeProbe.scrolls = 0;
    AiraWebFreezeProbe.lastScrollY = -1;
    AiraWebFreezeProbe.lastMoveLogAt = 0;
    AiraWebFreezeProbe.lastScrollLogAt = 0;
    AiraWebFreezeProbe.lastSnapshot = '';
    AiraWebFreezeProbe.uiMaxLateMs = 0;
    AiraWebFreezeProbe.uiLastHeartbeatAt = Date.now();
    AiraWebFreezeProbe.uiRunningGeneration = -1;
    AiraWebFreezeProbe.ensureUiOccupancy();
    hilog.info(
      DOMAIN,
      TAG,
      '%{public}s page_begin tab=%{public}s url=%{public}s',
      PREFIX,
      tabId,
      AiraWebFreezeProbe.briefUrl(url)
    );
    PULL_DELAYS_MS.forEach((delayMs: number): void => {
      AiraWebFreezeProbe.schedulePull('page', delayMs);
    });
  }

  static notePageEnd(tabId: string, url: string): void {
    hilog.info(
      DOMAIN,
      TAG,
      '%{public}s page_end tab=%{public}s sincePage=%{public}d url=%{public}s',
      PREFIX,
      tabId,
      AiraWebFreezeProbe.sincePage(),
      AiraWebFreezeProbe.briefUrl(url)
    );
  }

  static noteTouch(tabId: string, phase: string, controller: webview.WebviewController): void {
    AiraWebFreezeProbe.controller = controller;
    if (phase === 'down') {
      AiraWebFreezeProbe.movesSinceScroll = 0;
      AiraWebFreezeProbe.ensureUiOccupancy();
      hilog.info(
        DOMAIN,
        TAG,
        '%{public}s touch_down tab=%{public}s sincePage=%{public}d y=%{public}d',
        PREFIX,
        tabId,
        AiraWebFreezeProbe.sincePage(),
        AiraWebFreezeProbe.lastScrollY
      );
      AiraWebFreezeProbe.schedulePull('touch_down', 0);
      AiraWebFreezeProbe.schedulePull('touch_down', 2000);
      return;
    }
    if (phase === 'move') {
      AiraWebFreezeProbe.moves += 1;
      AiraWebFreezeProbe.movesSinceScroll += 1;
      const now = Date.now();
      const frozen = AiraWebFreezeProbe.movesSinceScroll >= 4;
      const interval = frozen ? TOUCH_MOVE_FROZEN_LOG_MS : TOUCH_MOVE_IDLE_LOG_MS;
      if (now - AiraWebFreezeProbe.lastMoveLogAt < interval) {
        return;
      }
      AiraWebFreezeProbe.lastMoveLogAt = now;
      hilog.info(
        DOMAIN,
        TAG,
        '%{public}s touch_move tab=%{public}s frozen=%{public}d moves=%{public}d sinceScroll=%{public}d y=%{public}d sincePage=%{public}d',
        PREFIX,
        tabId,
        frozen ? 1 : 0,
        AiraWebFreezeProbe.moves,
        AiraWebFreezeProbe.movesSinceScroll,
        AiraWebFreezeProbe.lastScrollY,
        AiraWebFreezeProbe.sincePage()
      );
      return;
    }
    if (phase === 'up' || phase === 'cancel') {
      hilog.info(
        DOMAIN,
        TAG,
        '%{public}s touch_%{public}s tab=%{public}s moves=%{public}d sinceScroll=%{public}d scrolls=%{public}d y=%{public}d sincePage=%{public}d',
        PREFIX,
        phase,
        tabId,
        AiraWebFreezeProbe.moves,
        AiraWebFreezeProbe.movesSinceScroll,
        AiraWebFreezeProbe.scrolls,
        AiraWebFreezeProbe.lastScrollY,
        AiraWebFreezeProbe.sincePage()
      );
      AiraWebFreezeProbe.schedulePull('touch_end', 0);
    }
  }

  static noteScroll(tabId: string, yOffset: number): void {
    const y = Number.isFinite(yOffset) ? Math.round(yOffset) : 0;
    if (y === AiraWebFreezeProbe.lastScrollY) {
      return;
    }
    const movesBefore = AiraWebFreezeProbe.movesSinceScroll;
    const first = AiraWebFreezeProbe.scrolls === 0;
    AiraWebFreezeProbe.scrolls += 1;
    AiraWebFreezeProbe.movesSinceScroll = 0;
    AiraWebFreezeProbe.lastScrollY = y;
    const now = Date.now();
    if (!first && movesBefore < 4 && now - AiraWebFreezeProbe.lastScrollLogAt < 1000) {
      return;
    }
    AiraWebFreezeProbe.lastScrollLogAt = now;
    hilog.info(
      DOMAIN,
      TAG,
      '%{public}s scroll tab=%{public}s y=%{public}d movesBefore=%{public}d scrolls=%{public}d sincePage=%{public}d',
      PREFIX,
      tabId,
      y,
      movesBefore,
      AiraWebFreezeProbe.scrolls,
      AiraWebFreezeProbe.sincePage()
    );
  }

  private static ensureUiOccupancy(): void {
    if (AiraWebFreezeProbe.uiRunningGeneration === AiraWebFreezeProbe.generation) {
      return;
    }
    AiraWebFreezeProbe.uiRunningGeneration = AiraWebFreezeProbe.generation;
    AiraWebFreezeProbe.startUiOccupancy(AiraWebFreezeProbe.generation);
  }

  private static startUiOccupancy(generation: number): void {
    AiraWebFreezeProbe.uiExpectedAt = Date.now() + UI_TICK_MS;
    const deadline = Date.now() + UI_PROBE_WINDOW_MS;
    const tick = (): void => {
      if (generation !== AiraWebFreezeProbe.generation) {
        return;
      }
      const now = Date.now();
      const late = now - AiraWebFreezeProbe.uiExpectedAt;
      if (late > AiraWebFreezeProbe.uiMaxLateMs) {
        AiraWebFreezeProbe.uiMaxLateMs = late;
      }
      if (late >= UI_LATE_LOG_MS) {
        hilog.info(
          DOMAIN,
          TAG,
          '%{public}s ui_late lateMs=%{public}d sincePage=%{public}d',
          PREFIX,
          late,
          AiraWebFreezeProbe.sincePage()
        );
      }
      if (now - AiraWebFreezeProbe.uiLastHeartbeatAt >= UI_HEARTBEAT_MS) {
        AiraWebFreezeProbe.uiLastHeartbeatAt = now;
        hilog.info(
          DOMAIN,
          TAG,
          '%{public}s ui_heartbeat maxLateMs=%{public}d sincePage=%{public}d',
          PREFIX,
          AiraWebFreezeProbe.uiMaxLateMs,
          AiraWebFreezeProbe.sincePage()
        );
        AiraWebFreezeProbe.uiMaxLateMs = 0;
      }
      if (now >= deadline) {
        if (AiraWebFreezeProbe.uiRunningGeneration === generation) {
          AiraWebFreezeProbe.uiRunningGeneration = -1;
        }
        hilog.info(DOMAIN, TAG, '%{public}s ui_probe_end sincePage=%{public}d', PREFIX, AiraWebFreezeProbe.sincePage());
        return;
      }
      AiraWebFreezeProbe.uiExpectedAt = now + UI_TICK_MS;
      setTimeout(tick, UI_TICK_MS);
    };
    setTimeout(tick, UI_TICK_MS);
  }

  private static schedulePull(reason: string, delayMs: number): void {
    const generation = AiraWebFreezeProbe.generation;
    const dueAt = Date.now() + delayMs;
    setTimeout((): void => {
      void AiraWebFreezeProbe.pull(generation, reason, dueAt);
    }, delayMs);
  }

  private static async pull(generation: number, reason: string, dueAt: number): Promise<void> {
    if (generation !== AiraWebFreezeProbe.generation) {
      return;
    }
    const controller = AiraWebFreezeProbe.controller;
    if (controller === undefined) {
      return;
    }
    const queueLate = Math.max(0, Date.now() - dueAt);
    const startedAt = Date.now();
    try {
      const raw = await controller.runJavaScript(SNAPSHOT_SCRIPT);
      AiraWebFreezeProbe.logSnapshot(reason, queueLate, Date.now() - startedAt, raw);
    } catch (error) {
      hilog.warn(
        DOMAIN,
        TAG,
        '%{public}s snapshot_fail reason=%{public}s queueLate=%{public}d jsDelay=%{public}d sincePage=%{public}d err=%{public}s',
        PREFIX,
        reason,
        queueLate,
        Date.now() - startedAt,
        AiraWebFreezeProbe.sincePage(),
        AiraWebFreezeProbe.briefError(error)
      );
    }
  }

  private static logSnapshot(reason: string, queueLate: number, jsDelay: number, raw: Object | string | undefined): void {
    const text = AiraWebFreezeProbe.briefSnapshot(raw);
    const delayed = queueLate >= UI_LATE_LOG_MS || jsDelay >= 300;
    if (!delayed && text === AiraWebFreezeProbe.lastSnapshot) {
      return;
    }
    AiraWebFreezeProbe.lastSnapshot = text;
    hilog.info(
      DOMAIN,
      TAG,
      '%{public}s snapshot reason=%{public}s queueLate=%{public}d jsDelay=%{public}d sincePage=%{public}d %{public}s',
      PREFIX,
      reason,
      queueLate,
      jsDelay,
      AiraWebFreezeProbe.sincePage(),
      text
    );
  }

  private static briefSnapshot(raw: Object | string | undefined): string {
    const text = typeof raw === 'string' ? raw : `${raw ?? ''}`;
    return text.replace(/[\r\n]+/g, ' ').slice(0, 720);
  }

  private static briefError(error: Object): string {
    return `${error}`.replace(/[\r\n]+/g, ' ').slice(0, 180);
  }

  private static briefUrl(url: string): string {
    const raw = String(url ?? '');
    const query = raw.indexOf('?');
    const cut = query >= 0 ? raw.substring(0, query) : raw;
    return cut.length > 0 ? cut.substring(0, 180) : 'empty';
  }

  private static sincePage(): number {
    if (AiraWebFreezeProbe.pageStartedAt <= 0) {
      return -1;
    }
    return Date.now() - AiraWebFreezeProbe.pageStartedAt;
  }
}

const FREEZE_COST_LEDGER_SCRIPT: string = `
(function () {
  if (window.__airaFreezeCostAdd) {
    return;
  }
  var ledger = window.__airaFreezeCost || { n: {}, ms: {} };
  window.__airaFreezeCost = ledger;
  window.__airaFreezeCostAdd = function (name, startedAt) {
    var elapsed = Date.now() - startedAt;
    if (!(elapsed >= 0)) {
      elapsed = 0;
    }
    var key = String(name || 'unknown');
    ledger.n[key] = (ledger.n[key] || 0) + 1;
    ledger.ms[key] = (ledger.ms[key] || 0) + elapsed;
  };
})();
`;

const FREEZE_DIAGNOSIS_DOCUMENT_START_SCRIPT: string = `
(function () {
  if (window !== window.top || window.__airaFreezeDiag) {
    return;
  }
  var installedAt = Date.now();
  var state = {
    lateMax: 0,
    lateMaxAge: 0,
    lastLate: 0,
    lateN: 0,
    lt: 0,
    ltMax: 0,
    ltWho: '',
    loafN: 0,
    loafMax: 0,
    loafScript: 0,
    loafStyle: 0,
    loafTop: '',
    tS: 0,
    tM: 0,
    tE: 0,
    tP: 0,
    sc: 0,
    innerSc: 0,
    sseC: 0,
    sseM: 0,
    sseE: 0,
    sseOpen: 0,
    xhr: 0,
    fetchN: 0,
    tgt: ''
  };
  function age() {
    return Date.now() - installedAt;
  }
  function overflowY(el) {
    try {
      return el ? getComputedStyle(el).overflowY : '';
    } catch (_error) {
      return '';
    }
  }
  function lockBits() {
    var bits = 0;
    try {
      var html = document.documentElement;
      var body = document.body;
      if (html && html.getAttribute('data-launch-loading') === 'true') bits += 1;
      if (document.getElementById('loading-bg')) bits += 2;
      if (html && html.classList && (
        html.classList.contains('v-overlay-scroll-blocked') ||
        html.classList.contains('quick-access-scroll-locked') ||
        html.classList.contains('overflow-y-hidden'))) bits += 4;
      var htmlOverflow = overflowY(html);
      var bodyOverflow = overflowY(body);
      if (htmlOverflow === 'hidden' || htmlOverflow === 'clip') bits += 8;
      if (bodyOverflow === 'hidden' || bodyOverflow === 'clip') bits += 16;
    } catch (_error) {
    }
    return bits;
  }
  function costText() {
    var ledger = window.__airaFreezeCost;
    if (!ledger || !ledger.ms) {
      return 'none';
    }
    var names = [];
    try {
      names = Object.keys(ledger.ms);
    } catch (_error) {
      return 'err';
    }
    var parts = [];
    for (var index = 0; index < names.length; index += 1) {
      var name = names[index];
      parts.push(name + ':' + Math.round(ledger.ms[name] || 0) + '/' + (ledger.n[name] || 0));
    }
    return parts.length > 0 ? parts.join(',') : 'none';
  }
  function snapshot() {
    var html = document.documentElement;
    var body = document.body;
    return [
      'age=' + age(),
      'lateMax=' + Math.round(state.lateMax),
      'lateMaxAge=' + state.lateMaxAge,
      'lastLate=' + Math.round(state.lastLate),
      'lateN=' + state.lateN,
      'lt=' + state.lt,
      'ltMax=' + Math.round(state.ltMax),
      'ltWho=' + state.ltWho,
      'loaf=' + Math.round(state.loafMax) + '/n' + state.loafN + ',script:' + Math.round(state.loafScript) +
        ',style:' + Math.round(state.loafStyle),
      'loafTop=' + state.loafTop,
      'pcs=' + prefersDarkText(),
      'cs=' + clip(String(computedColorScheme())),
      'nodes=' + nodeCount(),
      'cost=' + costText(),
      'tS=' + state.tS,
      'tM=' + state.tM,
      'tE=' + state.tE,
      'tP=' + state.tP,
      'sc=' + state.sc,
      'innerSc=' + state.innerSc,
      'y=' + Math.round(window.scrollY || (html && html.scrollTop) || 0),
      'sh=' + (html ? html.scrollHeight : 0),
      'ch=' + (html ? html.clientHeight : 0),
      'sw=' + (html ? html.scrollWidth : 0),
      'cw=' + (html ? html.clientWidth : 0),
      'ox=' + overflowY(html),
      'ob=' + overflowY(body),
      'lock=' + lockBits(),
      'ready=' + document.readyState,
      'sseC=' + state.sseC,
      'sseM=' + state.sseM,
      'sseE=' + state.sseE,
      'sseOpen=' + state.sseOpen,
      'xhr=' + state.xhr,
      'fetch=' + state.fetchN,
      'tgt=' + state.tgt
    ].join(' ');
  }
  window.__airaFreezeDiag = { snapshot: snapshot };
  var expected = Date.now() + 250;
  setInterval(function () {
    var now = Date.now();
    var late = now - expected;
    state.lastLate = late;
    if (late > 200) {
      state.lateN += 1;
      if (late > state.lateMax) {
        state.lateMax = late;
        state.lateMaxAge = age();
      }
    }
    expected = now + 250;
  }, 250);
  function clip(value) {
    return String(value || '').replace(/[^A-Za-z0-9_./:?&=%-]+/g, '_').slice(0, 80);
  }
  function prefersDarkText() {
    try {
      return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    } catch (_error) {
      return 'unknown';
    }
  }
  function computedColorScheme() {
    try {
      return getComputedStyle(document.documentElement).colorScheme || 'none';
    } catch (_error) {
      return 'err';
    }
  }
  function nodeCount() {
    try {
      return document.getElementsByTagName('*').length;
    } catch (_error) {
      return -1;
    }
  }
  function longTaskWho(entry) {
    var who = '';
    try {
      var attribution = entry && entry.attribution;
      var first = attribution && attribution.length ? attribution[0] : undefined;
      if (first) {
        who = [first.name, first.containerType, first.containerName, first.containerSrc].map(clip).join('|');
      }
    } catch (_error) {
    }
    return who || 'none';
  }
  try {
    if (window.PerformanceObserver && PerformanceObserver.supportedEntryTypes &&
      PerformanceObserver.supportedEntryTypes.indexOf('long-animation-frame') >= 0) {
      var loafObserver = new PerformanceObserver(function (list) {
        var entries = list.getEntries();
        for (var entryIndex = 0; entryIndex < entries.length; entryIndex += 1) {
          var entry = entries[entryIndex];
          var loafDuration = entry.duration || 0;
          state.loafN += 1;
          if (loafDuration <= state.loafMax) {
            continue;
          }
          state.loafMax = loafDuration;
          state.loafStyle = entry.styleAndLayoutStart ?
            Math.round(entry.startTime + loafDuration - entry.styleAndLayoutStart) : 0;
          var scripts = entry.scripts || [];
          var scriptMs = 0;
          var top = '';
          for (var scriptIndex = 0; scriptIndex < scripts.length; scriptIndex += 1) {
            var script = scripts[scriptIndex];
            var scriptDuration = script.duration || 0;
            scriptMs += scriptDuration;
            top += clip(script.sourceURL) + '#' + clip(script.functionName) + '#' + clip(script.invoker) +
              '#' + clip(script.invokerType) + ':' + Math.round(scriptDuration) + ';';
          }
          state.loafScript = Math.round(scriptMs);
          state.loafTop = top.slice(0, 640) || 'none';
        }
      });
      loafObserver.observe({ entryTypes: ['long-animation-frame'] });
    }
  } catch (_error) {
  }
  try {
    if (window.PerformanceObserver) {
      var observer = new PerformanceObserver(function (list) {
        var entries = list.getEntries();
        for (var index = 0; index < entries.length; index += 1) {
          var entry = entries[index];
          var duration = entry.duration || 0;
          state.lt += 1;
          if (duration > state.ltMax) {
            state.ltMax = duration;
            state.ltWho = longTaskWho(entry);
          }
        }
      });
      observer.observe({ entryTypes: ['longtask'] });
    }
  } catch (_error) {
  }
  function targetName(event) {
    var target = event && event.target;
    if (!target || !target.tagName) return '';
    var className = '';
    try {
      className = String(target.className || '').replace(/[^A-Za-z0-9_-]+/g, ' ').slice(0, 40);
    } catch (_error) {
    }
    return String(target.tagName).toLowerCase() +
      (className ? '.' + className.trim().replace(/ +/g, '.') : '');
  }
  document.addEventListener('touchstart', function (event) {
    state.tS += 1;
    state.tgt = targetName(event);
  }, true);
  document.addEventListener('touchmove', function (event) {
    state.tM += 1;
    if (state.tM <= 6 || state.tM % 8 === 0) {
      setTimeout(function () {
        if (event && event.defaultPrevented) state.tP += 1;
      }, 0);
    }
  }, true);
  document.addEventListener('touchend', function () { state.tE += 1; }, true);
  document.addEventListener('touchcancel', function () { state.tE += 1; }, true);
  document.addEventListener('scroll', function (event) {
    state.sc += 1;
    var target = event && event.target;
    if (target && target !== document && target !== document.documentElement && target !== document.body) {
      state.innerSc += 1;
    }
  }, true);
  try {
    var OriginalEventSource = window.EventSource;
    if (typeof OriginalEventSource === 'function') {
      var PatchedEventSource = function (url, options) {
        state.sseC += 1;
        var source = options === undefined ? new OriginalEventSource(url) : new OriginalEventSource(url, options);
        source.addEventListener('open', function () { state.sseOpen = 1; });
        source.addEventListener('message', function () { state.sseM += 1; });
        source.addEventListener('error', function () { state.sseE += 1; });
        return source;
      };
      PatchedEventSource.prototype = OriginalEventSource.prototype;
      PatchedEventSource.CONNECTING = OriginalEventSource.CONNECTING;
      PatchedEventSource.OPEN = OriginalEventSource.OPEN;
      PatchedEventSource.CLOSED = OriginalEventSource.CLOSED;
      window.EventSource = PatchedEventSource;
    }
  } catch (_error) {
  }
  try {
    var originalOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function () {
      state.xhr += 1;
      return originalOpen.apply(this, arguments);
    };
  } catch (_error) {
  }
  try {
    var originalFetch = window.fetch;
    if (typeof originalFetch === 'function') {
      window.fetch = function () {
        state.fetchN += 1;
        return originalFetch.apply(this, arguments);
      };
    }
  } catch (_error) {
  }
})();
`;
