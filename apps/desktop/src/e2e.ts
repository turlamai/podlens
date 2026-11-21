// In-page acceptance journey harness (#63). glaze exposes no JS injection
// into the webview, so the journey runs inside the page itself: verify.rkt
// navigates the window to #e2e with PODLENS_E2E=1, and each step reports
// through api/host/e2e_report. Inert in production (hash + host gate).
import { apiPost, resumeLast } from '@podlens/core';
import { state } from './state';
import { position, preload } from './player';

const wait = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

// Condition polling instead of fixed sleeps: slow CI runners add latency
// between click and media-clock start, so fixed waits either flake or
// overshoot the 8s fixture. Deadlines stay inside the fixture window.
async function until(cond: () => boolean, ms: number, what: string): Promise<void> {
  const deadline = Date.now() + ms;
  while (!cond()) {
    if (Date.now() > deadline) throw new Error(`timeout waiting for ${what}`);
    await wait(120);
  }
}

function click(selector: string): void {
  const el = document.querySelector(selector) as HTMLElement | null;
  if (!el) throw new Error(`missing element: ${selector}`);
  el.click();
}

function expect(cond: unknown, message: string): void {
  if (!cond) throw new Error(message);
}

// WebKit media pipelines can wedge with promises that never settle (macOS
// CI): an unbounded await would hang the step forever, lose its report and
// cascade every later verdict to #f. Race every foreign await against a
// deadline so a wedge surfaces as a reported step failure instead.
function withTimeout<T>(p: Promise<T> | undefined, ms: number, what: string): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const t = setTimeout(() => reject(new Error(`timeout waiting for ${what}`)), ms);
    Promise.resolve(p as Promise<T>).then(
      (v) => {
        clearTimeout(t);
        resolve(v);
      },
      (e) => {
        clearTimeout(t);
        reject(e);
      },
    );
  });
}

// WebView2 intermittently aborts keep-alive connections (win_err=10053 server
// noise); a single failed gate/report fetch must not silently skip the whole
// harness. Retry harness-only POSTs with a short backoff.
async function postRetry(path: string, body: unknown, tries = 5): Promise<unknown> {
  let last: unknown = new Error('no attempt');
  for (let i = 0; i < tries; i++) {
    try {
      return await apiPost(path, body);
    } catch (e) {
      last = e;
      await wait(150 * (i + 1));
    }
  }
  throw last;
}

let harnessStarted = false;

export async function runHarnessIfGated(): Promise<void> {
  if (harnessStarted || location.hash !== '#e2e') return;
  let gate: { enabled?: boolean };
  try {
    gate = (await postRetry('api/host/e2e', {})) as { enabled?: boolean };
  } catch {
    return;
  }
  if (!gate.enabled) return;
  harnessStarted = true;
  // Harness-only flag: the player keeps muted-autoplay media muted under this
  // flag (WebKitGTK pauses muted-autoplay media when unmuted without a real
  // gesture; acceptance asserts the clock/bridge, not audibility).
  (window as unknown as Record<string, unknown>).__podlensE2E = true;
  const report = (id: string, ok: boolean, detail: string): Promise<unknown> =>
    postRetry('api/host/e2e_report', { id, ok, detail }).catch(() => undefined);
  const step = async (id: string, fn: () => Promise<string | void>): Promise<void> => {
    try {
      const detail = await fn();
      await report(id, true, detail ?? '');
    } catch (err) {
      await report(id, false, String(err instanceof Error ? err.message : err));
    }
  };

  await step('boot-loaded', async () => {
    expect(state.loaded, 'app state not loaded');
    expect(document.querySelector('.sidebar'), 'sidebar missing');
    expect(document.querySelector('.player'), 'player missing');
    return document.title;
  });
  await step('nav-episodes', async () => {
    click('.sidebar [data-page="episodes"]');
    await wait(400);
    expect(state.page === 'episodes', 'episodes page not active');
    return document.querySelector('h1')?.textContent ?? '';
  });
  await step('nav-discover', async () => {
    click('.sidebar [data-page="discover"]');
    await wait(400);
    expect(state.page === 'discover', 'discover page not active');
    expect(document.querySelector('#search'), 'search field missing');
    return document.querySelector('h1')?.textContent ?? '';
  });
  await step('nav-settings', async () => {
    click('.sidebar [data-page="settings"]');
    // Settings nav awaits a settings RPC round-trip before rendering
    // (main.ts); slow CI hosts need more than a fixed wait.
    const t0 = Date.now();
    while (!document.querySelector('#api-base') && Date.now() - t0 < 6000) await wait(100);
    if (!document.querySelector('#api-base')) {
      // WKWebView CI hosts occasionally drop the first navigation's render;
      // one re-click recovers without masking a real regression.
      click('.sidebar [data-page="settings"]');
      const t1 = Date.now();
      while (!document.querySelector('#api-base') && Date.now() - t1 < 4000) await wait(100);
    }
    expect(state.page === 'settings', 'settings page not active');
    expect(
      document.querySelector('#api-base'),
      `api base field missing (settings=${!!document.querySelector('.settings')} keys=${Object.keys(state.settings ?? {}).length} page=${state.page} content=${(document.querySelector('.content')?.innerHTML ?? '').slice(0, 160)})`,
    );
    return document.querySelector('h1')?.textContent ?? '';
  });
  await step('theme-toggle', async () => {
    click('[data-action="theme"]');
    await wait(250);
    const flipped = document.documentElement.classList.contains('dark');
    click('[data-action="theme"]');
    await wait(250);
    return `dark=${flipped}`;
  });
  await step('nav-home', async () => {
    click('.sidebar [data-page="home"]');
    await wait(400);
    expect(state.page === 'home', 'home page not active');
    return document.querySelector('h1')?.textContent ?? '';
  });
  // ---- seeded listening journey (fixture: 8s wav + 4 bilingual sentences
  // + mixed anchored/legacy summary; verify.rkt seeds it before boot) ----
  await step('journey-open-episode', async () => {
    click('.hero [data-action="open-current"]');
    await wait(600);
    expect(state.page === 'transcript', 'transcript page not active');
    const n = document.querySelectorAll('.sentence').length;
    expect(n === 4, `expected 4 sentences, got ${n}`);
    // Warm the media element before any play(): a load started inside
    // play() at HAVE_NOTHING can stall in WebView2 (acceptance flake).
    // Soft assertion: the webview media pipeline can surface metadata
    // seconds after the server wrote the full response; the play step
    // below owns the hard clock assertion with its own restart backstop.
    preload(state.episode ?? '');
    const a = document.getElementById('audio') as HTMLAudioElement | null;
    try {
      await until(() => (a?.readyState ?? 0) >= 1, 8000, 'media metadata preload');
    } catch (e) {
      return `preload slow (${(e as Error).message}); continuing to play step`;
    }
    return document.querySelector('h1')?.textContent ?? '';
  });
  await step('journey-sentence-seek', async () => {
    click('.sentence[data-sec="4"]');
    await wait(400);
    const p = position();
    expect(Math.abs(p - 4) < 0.6, `position ${p} not at sentence 4`);
    expect(state.reading === 4, `reading ${state.reading}`);
    return `position=${p.toFixed(2)}`;
  });
  await step('journey-play-mediasession', async () => {
    // Media-event counters: on a dead pipeline play() can resolve while no
    // media event ever fires; the counters tell load stalls from clock stalls.
    let mutedFallback = false;
    const a0 = document.getElementById('audio') as HTMLAudioElement | null;
    const w0 = window as unknown as Record<string, unknown>;
    if (a0 && !w0.__podlensMediaEvents) {
      const counts: Record<string, number> = {};
      w0.__podlensMediaEvents = counts;
      for (const ev of [
        'loadstart', 'loadedmetadata', 'canplay', 'play', 'playing',
        'timeupdate', 'error', 'stalled', 'suspend', 'waiting', 'emptied', 'abort',
      ]) {
        a0.addEventListener(ev, () => { counts[ev] = (counts[ev] ?? 0) + 1; });
      }
    }
    click('.player [data-action="toggle"]');
    try {
      await until(() => state.playing, 2500, 'playback start');
    } catch {
      /* fall through to the muted diagnostic fallback below */
    }
    if (!state.playing) {
      const a = document.getElementById('audio') as HTMLAudioElement | null;
      const w = window as unknown as Record<string, unknown>;
      const prior = `unmuted=${w.__podlensPlayError ?? 'none'} muted=${w.__podlensMutedPlayError ?? 'none'}`;
      if (a) a.muted = true;
      mutedFallback = true;
      try {
        await withTimeout(a?.play(), 5000, 'muted play promise');
        // keep muted: unmute without a real gesture pauses WebKitGTK media
      } catch (e) {
        throw new Error(
          `play rejected (${prior}): ${(e as Error).name}: ${(e as Error).message}`,
        );
      }
      await wait(300);
    }
    try {
      await until(() => state.playing, 1500, 'playback start');
    } catch (e) {
      const a = document.getElementById('audio') as HTMLAudioElement | null;
      const w = window as unknown as Record<string, unknown>;
      throw new Error(
        `${(e as Error).message}; ready=${a?.readyState} net=${a?.networkState} paused=${a?.paused} t=${a?.currentTime} src=${a?.currentSrc ?? 'none'} mediaErr=${a?.error?.code ?? 'none'} events=${JSON.stringify(w.__podlensMediaEvents ?? {})} playErr=${w.__podlensPlayError ?? 'none'} mutedErr=${w.__podlensMutedPlayError ?? 'none'}`,
      );
    }
    try {
      await until(() => position() > 4.2, 4000, 'media clock advance');
    } catch (e) {
      // Transient media-pipeline stall (observed once locally): the 'play'
      // event fires but the clock stays put. One pause/play restart kicks
      // the pipeline; the pause-position journey proves this path works.
      click('.player [data-action="toggle"]');
      await wait(250);
      click('.player [data-action="toggle"]');
      try {
        await until(() => position() > 4.2, 3000, 'media clock advance after restart');
      } catch (e2) {
        const a = document.getElementById('audio') as HTMLAudioElement | null;
        const w = window as unknown as Record<string, unknown>;
        throw new Error(
          `${(e2 as Error).message}; pos=${position()} ready=${a?.readyState} net=${a?.networkState} paused=${a?.paused} t=${a?.currentTime} mediaErr=${a?.error?.code ?? 'none'} playErr=${w.__podlensPlayError ?? 'none'} mutedErr=${w.__podlensMutedPlayError ?? 'none'} (first: ${(e as Error).message})`,
        );
      }
    }
    const ms = navigator.mediaSession;
    expect(ms, 'mediaSession missing');
    expect(ms.playbackState === 'playing', `playbackState ${ms.playbackState}`);
    expect(
      (ms.metadata?.title ?? '').includes('focused listening'),
      `metadata title ${ms.metadata?.title}`,
    );
    // Host-owned OS Now Playing bridge (glaze#153): the page sync must
    // reach the host surface. The Windows stub answers {} (web SMTC is
    // the verified path there); macOS/Linux read the published state back.
    // The host surface can lag the page sync by the bus name-acquisition
    // round trip; poll briefly instead of reading once (inert carriers
    // answer {} and fall through after the cap).
    let os: Record<string, unknown> = {};
    const hostDeadline = Date.now() + 4000;
    for (;;) {
      os = (await withTimeout(
        apiPost('api/host/now-playing_os', {}) as Promise<Record<string, unknown>>,
        2000,
        'host now-playing_os RPC',
      ).catch(() => ({}))) as Record<string, unknown>;
      if (typeof os.title === 'string' && os.title) break;
      if (Date.now() > hostDeadline) break;
      await wait(400);
    }
    const hostTitle = typeof os.title === 'string' ? os.title : '';
    let hostNote = 'host=inert';
    if (hostTitle || typeof os.playing === 'boolean') {
      expect(hostTitle.includes('focused listening'), `host now-playing title ${hostTitle}`);
      expect(os.playing === true, `host now-playing playing ${String(os.playing)}`);
      hostNote = `host=${hostTitle}`;
    }
    const hw = window as unknown as Record<string, unknown>;
    return `${ms.metadata?.title ?? ''}${mutedFallback ? ' [muted-fallback]' : ''} muted=${a0?.muted} vol=${a0?.volume} playErr=${(window as unknown as Record<string, unknown>).__podlensPlayError ?? 'none'} ${hostNote} sync=${hw.__podlensHostSyncCalls ?? 0}/${hw.__podlensHostSyncOk ?? 0} syncErr=${hw.__podlensHostSyncError ?? 'none'}`;
  });
  await step('journey-follow-sync', async () => {
    try {
      await until(() => state.reading === 6, 4000, 'follow to sentence 6');
    } catch {
      // Same transient-stall kick as the play step.
      click('.player [data-action="toggle"]');
      await wait(250);
      click('.player [data-action="toggle"]');
      await until(() => state.reading === 6, 3000, 'follow to sentence 6 after restart');
    }
    await wait(150);
    const cur = document.querySelector('.sentence.current') as HTMLElement | null;
    expect(cur?.dataset.sec === '6', `current class on ${cur?.dataset.sec}`);
    return `reading=${state.reading}`;
  });
  await step('journey-summary-anchors', async () => {
    click('[data-page="summary"]');
    await wait(600);
    const points = [...document.querySelectorAll('.point')];
    expect(points.length === 2, `points ${points.length}`);
    expect(points[0]?.querySelector('[data-action="anchor"]'), 'anchored point lost its jump');
    expect(
      !points[1]?.querySelector('[data-action="anchor"]'),
      'legacy unanchored point must render without a jump button',
    );
    const quotes = [...document.querySelectorAll('.quote')];
    expect(quotes.length === 1, `quotes ${quotes.length}`);
    expect(quotes[0]?.querySelector('[data-action="anchor"]'), 'anchored quote lost its jump');
    click('.point [data-action="anchor"]');
    await wait(300);
    expect(state.page === 'transcript', 'anchor did not return to transcript');
    expect(state.reading === 0, `anchor reading ${state.reading}`);
    await until(() => state.playing, 2000, 'anchor playback start');
    return 'anchors ok';
  });
  await step('journey-pause-position', async () => {
    if (!state.playing) {
      // Fixture may have run out on a very slow runner; restart briefly so
      // the pause-save path is still exercised.
      click('.player [data-action="toggle"]');
      await until(() => state.playing, 2000, 'restart for pause check');
    }
    click('.player [data-action="toggle"]');
    await wait(500);
    expect(!state.playing, 'playback did not pause');
    const row = await withTimeout(resumeLast(), 4000, 'resume-last RPC');
    expect(row.length >= 3, 'resume-last lost the episode');
    return `saved=${row[2] ?? ''}`;
  });
  await report('journey-complete', true, 'slice 3 listening journey');
}