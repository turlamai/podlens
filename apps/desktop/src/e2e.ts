// In-page acceptance journey harness (#63). glaze exposes no JS injection
// into the webview, so the journey runs inside the page itself: verify.rkt
// navigates the window to #e2e with PODLENS_E2E=1, and each step reports
// through api/host/e2e_report. Inert in production (hash + host gate).
import { apiPost } from '@podlens/core';
import { state } from './state';

const wait = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

function click(selector: string): void {
  const el = document.querySelector(selector) as HTMLElement | null;
  if (!el) throw new Error(`missing element: ${selector}`);
  el.click();
}

function expect(cond: unknown, message: string): void {
  if (!cond) throw new Error(message);
}

let harnessStarted = false;

export async function runHarnessIfGated(): Promise<void> {
  if (harnessStarted || location.hash !== '#e2e') return;
  let gate: { enabled?: boolean };
  try {
    gate = (await apiPost('api/host/e2e', {})) as { enabled?: boolean };
  } catch {
    return;
  }
  if (!gate.enabled) return;
  harnessStarted = true;
  const report = (id: string, ok: boolean, detail: string): Promise<unknown> =>
    apiPost('api/host/e2e_report', { id, ok, detail }).catch(() => undefined);
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
    await wait(400);
    expect(state.page === 'settings', 'settings page not active');
    expect(document.querySelector('#api-base'), 'api base field missing');
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
  await report('journey-complete', true, 'slice 2 page journey');
}