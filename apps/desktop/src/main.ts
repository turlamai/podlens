// PodLens web UI entry (#63 slice 2): boot, render loop, delegated
// actions, engine events, keyboard shortcuts, and the in-page acceptance
// harness gate (#e2e). The engine stays the single source of data; this
// module only orchestrates.
import './shared.css';
import './product.css';
import {
  hasBackend,
  onEngineEvent,
  apiPost,
  feedAdd,
  feedRemove,
  feedRefresh,
  feedRefreshAll,
  feedPeek,
  previewAudio,
  catalogSearch,
  episodeEstimate,
  episodePipeline,
  episodeDownload,
  episodeRemoveAudio,
  episodeSetDone,
  jobCancel,
  settingsSet,
  aiTest,
  updateCheck,
  updateState,
  startDownload,
  openReleases,
} from '@podlens/core';
import {
  state,
  t,
  feedOf,
  episodeOf,
  loadFeeds,
  loadRecent,
  loadEpisodes,
  loadCatalog,
  loadSettings,
  loadTranscript,
  loadSummary,
  loadResume,
  applyAppearance,
  pageLabelKey,
  type Page,
  type Episode,
} from './state';
import * as player from './player';
import { esc, time, sidebar, topbar, pageBody, player as playerBar, discoverResults } from './views';
import { runHarnessIfGated } from './e2e';

const $ = (s: string): HTMLElement | null => document.querySelector(s);
const $$ = (s: string): HTMLElement[] => [...document.querySelectorAll(s)] as HTMLElement[];

let noticeTimer: number | undefined;
export function notify(message: string): void {
  const el = $('#feedback');
  if (!el) return;
  el.textContent = message;
  el.hidden = false;
  window.clearTimeout(noticeTimer);
  noticeTimer = window.setTimeout(() => {
    el.hidden = true;
  }, 4500);
}

let renderQueued = false;
function scheduleRender(): void {
  if (renderQueued) return;
  renderQueued = true;
  requestAnimationFrame(() => {
    renderQueued = false;
    render();
  });
}

const scrollPositions: Record<string, number> = {};

function render(): void {
  const focused = document.activeElement as HTMLElement | null;
  const focusKey = focused?.dataset ? JSON.stringify(focused.dataset) : '';
  const focusId = focused?.id;
  const previousScroll = $('.main-scroll')?.scrollTop || 0;
  document.documentElement.classList.toggle('dark', state.dark);
  document.documentElement.lang = state.lang === 'en' ? 'en' : 'zh-CN';
  document.title = `PodLens — ${t(pageLabelKey[state.page])}`;
  const app = $('#app');
  if (!app) return;
  app.className = `app${state.focus ? ' focus-mode' : ''}`;
  app.innerHTML = `${sidebar()}<div class="workspace">${topbar()}<main class="main-scroll" id="main"><div class="content">${pageBody()}</div></main>${playerBar()}</div>`;
  const scroll = $('.main-scroll');
  if (scroll) scroll.scrollTop = previousScroll;
  if (focusId && document.getElementById(focusId)) {
    document.getElementById(focusId)?.focus({ preventScroll: true });
  } else if (focusKey && focusKey !== '{}') {
    const replacement = $$('button,[role=button]').find(
      (node) => JSON.stringify(node.dataset) === focusKey,
    );
    replacement?.focus({ preventScroll: true });
  }
  syncPositionUi();
  if (state.page === 'settings') void loadAutostart();
}

function syncPositionUi(): void {
  const p = player.position();
  const dur = player.duration() || episodeOf(state.episode)?.duration || 0;
  $$('[data-time]').forEach((n) => {
    n.textContent = time(p);
  });
  $$('[data-remaining]').forEach((n) => {
    n.textContent = '−' + time(Math.max(0, dur - p));
  });
  const seek = $('#seek') as HTMLInputElement | null;
  if (seek) seek.value = String(p);
  $$('[data-hero-progress]').forEach((n) => {
    (n as HTMLProgressElement).value = p;
  });
  $$('[data-hero-time]').forEach((n) => {
    n.textContent = `${time(p)} / ${time(dur)}`;
  });
}

async function navigate(page: Page, opts: { show?: string | null; filter?: string } = {}): Promise<void> {
  scrollPositions[state.page] = $('.main-scroll')?.scrollTop || 0;
  state.page = page;
  if (page !== 'transcript' && page !== 'summary') state.focus = false;
  if (page === 'episodes') {
    state.show = opts.show ?? null;
    state.filter = (opts.filter as 'all' | 'downloaded' | 'shows') || 'all';
    if (state.filter !== 'shows') await loadEpisodes();
  } else {
    state.show = null;
  }
  if (page === 'discover' && !state.catalog.length) await loadCatalog();
  if (page === 'settings') await loadSettings();
  if ((page === 'transcript' || page === 'summary') && state.episode) {
    await ensureEpisodeContent(state.episode);
  }
  render();
  const scroll = $('.main-scroll');
  if (scroll) scroll.scrollTop = scrollPositions[page] || 0;
  const heading = $('h1');
  if (heading) {
    heading.tabIndex = -1;
    heading.focus({ preventScroll: true });
  }
}

let contentFor: string | null = null;
async function ensureEpisodeContent(id: string): Promise<void> {
  if (contentFor === id) return;
  contentFor = id;
  await Promise.all([loadTranscript(id), loadSummary(id)]);
}

async function openEpisode(id: string): Promise<void> {
  if (state.episode !== id) {
    player.stopForSwitch();
    state.episode = id;
    state.reading = null;
    contentFor = null;
  }
  await navigate('transcript');
  player.preload(id);
}

function setFollow(on: boolean, announce: boolean): void {
  state.follow = on;
  void settingsSet('follow-transcript', on ? 'true' : 'false').catch(() => {});
  if (announce) notify(on ? t('statusFollow_on') : t('statusFollow_off'));
  render();
}

// ---- dialogs -------------------------------------------------------------
const dialog = (): HTMLDialogElement => $('#info-dialog') as HTMLDialogElement;
function openDialog(title: string, copyHtml: string, actionsHtml: string): void {
  $('#dialog-title')!.textContent = title;
  $('#dialog-copy')!.innerHTML = copyHtml;
  $('#dialog-actions')!.innerHTML = actionsHtml;
  dialog().showModal();
}
const closeDialog = (): void => dialog().close();
const dlgButton = (text: string, action: string, cls = '', attrs = ''): string =>
  `<button type="button" class="btn ${cls}" data-action="${action}" ${attrs}>${text}</button>`;

function addFeedDialog(): void {
  openDialog(
    t('addFeed'),
    `<p>${esc(t('addFeedSubtitle'))}</p><div class="form-row"><label for="feed-url">${esc(t('feedURL'))}</label><input id="feed-url" type="url" placeholder="${esc(t('dialogUrl_placeholder'))}" autocomplete="off"></div><p class="meta">${esc(t('addFeedExample'))}</p>`,
    dlgButton(esc(t('cancel')), 'close-dialog') + dlgButton(esc(t('add')), 'add-feed-confirm', 'primary'),
  );
  $('#feed-url')?.focus();
}

async function generationDialog(id: string): Promise<void> {
  const ep = episodeOf(id);
  if (!ep) return;
  openDialog(
    t('confirmTitle'),
    `<p>${esc(t('confirmBody', ep.title, Math.round(ep.duration / 60)))}</p><p class="meta" id="estimate-line">${esc(t('confirmLoading'))}</p>`,
    dlgButton(esc(t('confirmCancel')), 'close-dialog') +
      dlgButton(esc(t('confirmStart')), 'pipeline-start', 'primary', `data-id="${esc(id)}"`),
  );
  try {
    const estimate = await episodeEstimate(id);
    const line = $('#estimate-line');
    if (line) line.textContent = estimate || t('pipelineCostUnknown');
  } catch {
    const line = $('#estimate-line');
    if (line) line.textContent = t('pipelineCostUnknown');
  }
}

function episodeMoreDialog(id: string): void {
  const ep = episodeOf(id);
  if (!ep) return;
  const actions = [
    ep.downloaded
      ? dlgButton(esc(t('removeAudio')), 'remove-audio', '', `data-id="${esc(id)}"`)
      : dlgButton(esc(t('download')), 'download', '', `data-id="${esc(id)}"`),
    ep.done
      ? dlgButton(esc(t('markUnplayed')), 'mark-undone', '', `data-id="${esc(id)}"`)
      : dlgButton(esc(t('markPlayed')), 'mark-done', '', `data-id="${esc(id)}"`),
    dlgButton(esc(t('cancel')), 'close-dialog'),
  ].join('');
  openDialog(t('detailActions'), `<p>${esc(ep.title)}</p>`, actions);
}

function removeFeedDialog(id: string): void {
  const f = feedOf(id);
  openDialog(
    t('dialogRemove_feed_title'),
    `<p>${esc(t('dialogRemove_feed_text'))}</p><p class="meta">${esc(f?.title ?? id)}</p>`,
    dlgButton(esc(t('cancel')), 'close-dialog') +
      dlgButton(esc(t('dialogRemove_feed_primary')), 'remove-feed-confirm', 'primary', `data-id="${esc(id)}"`),
  );
}

function updateDialog(version: string): void {
  openDialog(
    t('updateAvailableTitle'),
    `<p>${esc(t('updateAvailableBody', version))}</p>`,
    dlgButton(esc(t('updateLater')), 'close-dialog') +
      dlgButton(esc(t('updateDownload')), 'update-download', 'primary') +
      dlgButton(esc(t('updateOpenReleases')), 'open-releases', 'text'),
  );
}

async function previewDialog(url: string, title: string): Promise<void> {
  notify(t('previewFetching'));
  try {
    const rows = await feedPeek(url);
    if (!rows.length) {
      notify(t('previewNoEnclosure'));
      return;
    }
    openDialog(
      t('preview'),
      `<p class="meta">${esc(title)}</p>` +
        rows
          .map(
            (r, i) =>
              `<div class="form-row"><label>${esc(r[4] ?? '')}<small>${esc(r[5] ?? '')} · ${esc(t('ui-duration-minutes', Math.round((Number(r[6]) || 0) / 60)))}</small></label>${dlgButton(esc(t('play')), 'preview-play', '', `data-i="${i}"`)}</div>`,
          )
          .join(''),
      dlgButton(esc(t('dismiss')), 'close-dialog'),
    );
    previewRows = rows;
  } catch (err) {
    notify(t('previewFailed', String(err instanceof Error ? err.message : err)));
  }
}
let previewRows: string[][] = [];

async function playPreview(i: number): Promise<void> {
  const r = previewRows[i];
  if (!r) return;
  closeDialog();
  notify(t('previewDownloading'));
  try {
    const path = await previewAudio(r[3] ?? '');
    const base = path.split(/[\\/]/).pop() ?? '';
    const id = base.replace(/\.[a-z0-9]+$/i, '');
    const ep: Episode = {
      id,
      title: r[4] ?? '',
      date: r[5] ?? '',
      duration: Number(r[6]) || 0,
      downloaded: true,
      transcriptStatus: 'none',
      summaryStatus: 'none',
      position: 0,
      done: false,
      hasTranslation: false,
      description: '',
      feedId: '',
      feedTitle: r[0] ?? '',
      feedArtwork: r[2] ?? '',
    };
    state.preview = ep;
    state.episode = id;
    state.reading = null;
    contentFor = null;
    await player.playEpisode(id, { seekTo: 0 });
    notify(t('previewPlaying') + (r[4] ?? ''));
    render();
  } catch (err) {
    notify(t('previewFailed', String(err instanceof Error ? err.message : err)));
  }
}

// ---- settings helpers ----------------------------------------------------
function checkApiBase(): boolean {
  const field = $('#api-base') as HTMLInputElement | null;
  const error = $('#settings-error');
  if (!field || !error) return false;
  const base = field.value.trim();
  let valid = false;
  try {
    const parsed = new URL(base);
    valid = parsed.protocol === 'https:' && !parsed.username && !parsed.password;
  } catch {
    valid = false;
  }
  error.hidden = valid;
  error.textContent = valid ? '' : t('apiBaseHint');
  if (!valid) {
    const result = $('#settings-result');
    if (result) result.textContent = '';
    field.focus();
  }
  return valid;
}

async function saveSettings(): Promise<void> {
  if (!checkApiBase()) return;
  const val = (id: string): string => ($(id) as HTMLInputElement | null)?.value.trim() ?? '';
  const checked = (id: string): boolean => !!($(id) as HTMLInputElement | null)?.checked;
  const wanted: Record<string, string> = {
    'api-base': val('#api-base'),
    'chat-model': val('#chat-model'),
    'asr-model': val('#asr-model'),
    'target-lang': val('#target-lang'),
    'asr-chunk-seconds': val('#asr-chunk-seconds'),
    'max-transcript-chars': val('#max-transcript-chars'),
    'search-limit': val('#search-limit'),
    appearance: ($('#theme-choice') as HTMLSelectElement | null)?.value ?? 'system',
    'follow-transcript': checked('#auto-follow') ? 'true' : 'false',
    'ui-lang': ($('#ui-lang') as HTMLSelectElement | null)?.value ?? 'zh',
    'check-updates-enabled': checked('#auto-update') ? 'true' : 'false',
  };
  const key = val('#api-key');
  if (key) wanted['api-key'] = key;
  try {
    for (const [k, v] of Object.entries(wanted)) {
      if (state.settings[k] !== v) await settingsSet(k, v);
    }
    await loadSettings();
    const result = $('#settings-result');
    if (result) result.textContent = t('statusSaved');
    const keyInput = $('#api-key') as HTMLInputElement | null;
    if (keyInput) keyInput.value = '';
    notify(t('statusSaved'));
    render();
  } catch (err) {
    notify(t('fetchFailed', String(err instanceof Error ? err.message : err)));
  }
}

async function loadAutostart(): Promise<void> {
  try {
    const st = (await apiPost('api/host/autostart', {})) as { enabled?: boolean; supported?: boolean };
    const box = $('#autostart') as HTMLInputElement | null;
    if (box) {
      box.checked = !!st.enabled;
      box.disabled = st.supported === false;
    }
  } catch {
    /* host without autostart support */
  }
}

async function refreshLibrary(): Promise<void> {
  await Promise.all([loadFeeds(), loadRecent(), loadCatalog()]);
  if (state.page === 'episodes' && state.filter !== 'shows') await loadEpisodes();
  player.resolvePendingPlay();
  scheduleRender();
}

// ---- actions -------------------------------------------------------------
async function onAction(el: HTMLElement): Promise<void> {
  const action = el.dataset.action as string;
  const id = el.dataset.id ?? '';
  switch (action) {
    case 'menu': {
      const open = $('#app')!.classList.toggle('menu-open');
      el.setAttribute('aria-expanded', String(open));
      el.setAttribute('aria-label', open ? t('ui-nav-close') : t('ui-nav-open'));
      break;
    }
    case 'theme': {
      const mode = state.dark ? 'light' : 'dark';
      await settingsSet('appearance', mode).catch(() => {});
      state.settings['appearance'] = mode;
      applyAppearance();
      render();
      break;
    }
    case 'discover':
      await navigate('discover');
      break;
    case 'all-episodes':
      await navigate('episodes');
      break;
    case 'show':
      await navigate('episodes', { show: el.dataset.show });
      break;
    case 'show-by-title': {
      const f = state.feeds.find((x) => x.title === el.dataset.title);
      if (f) await navigate('episodes', { show: f.id });
      else notify(t('no-feed'));
      break;
    }
    case 'open':
      await openEpisode(id);
      break;
    case 'open-current':
      if (state.episode) {
        await navigate('transcript');
        player.preload(state.episode);
      }
      break;
    case 'toggle':
      player.toggle();
      break;
    case 'play-episode':
      if (state.episode === id) player.toggle();
      else {
        player.stopForSwitch();
        state.episode = id;
        contentFor = null;
        void ensureEpisodeContent(id);
        await player.playEpisode(id);
        notify(t('ui-switched-episode'));
        render();
      }
      break;
    case 'restart':
      player.seek(0);
      await player.playEpisode(state.episode as string, { seekTo: 0 });
      notify(t('ui-restarted'));
      render();
      break;
    case 'back':
      player.seek(player.position() - 15);
      break;
    case 'forward':
      player.seek(player.position() + 30);
      break;
    case 'sentence': {
      const sec = Number(el.dataset.sec);
      state.reading = sec;
      player.seek(sec);
      render();
      $(`.sentence[data-sec="${sec}"]`)?.focus({ preventScroll: true });
      break;
    }
    case 'anchor': {
      const sec = Number(el.dataset.sec);
      state.reading = sec;
      player.seek(sec);
      await player.playEpisode(state.episode as string, { seekTo: sec });
      await navigate('transcript');
      $(`.sentence[data-sec="${sec}"]`)?.scrollIntoView({ block: 'center', behavior: 'smooth' });
      notify(t('ui-anchored'));
      break;
    }
    case 'current': {
      const sentence = state.transcript.length
        ? [...state.transcript].reverse().find((r) => r.start <= player.position()) ?? state.transcript[0]
        : undefined;
      if (sentence) state.reading = sentence.start;
      setFollow(true, true);
      await navigate('transcript');
      $('.sentence.current')?.scrollIntoView({ block: 'center', behavior: 'smooth' });
      break;
    }
    case 'language':
      state.language = el.dataset.language as typeof state.language;
      render();
      break;
    case 'follow':
      setFollow(!state.follow, true);
      break;
    case 'focus':
      state.focus = !state.focus;
      render();
      break;
    case 'filter':
      state.filter = el.dataset.filter as typeof state.filter;
      if (state.page === 'episodes' && state.filter !== 'shows') await loadEpisodes();
      render();
      break;
    case 'subscribe': {
      try {
        await feedAdd(el.dataset.url as string);
        notify(t('feedAdded'));
        await refreshLibrary();
      } catch (err) {
        notify(t('fetchFailed', String(err instanceof Error ? err.message : err)));
      }
      break;
    }
    case 'preview':
      await previewDialog(el.dataset.url as string, el.dataset.title ?? '');
      break;
    case 'preview-play':
      await playPreview(Number(el.dataset.i));
      break;
    case 'cancel-job':
      await jobCancel(id).catch(() => {});
      state.jobs[id] = { kind: 'cancelled', pct: 0, message: '' };
      notify(t('statusCancelled'));
      render();
      break;
    case 'generate':
      await generationDialog(id);
      break;
    case 'pipeline-start':
      closeDialog();
      try {
        await episodePipeline(id);
        notify(t('statusJob_running'));
      } catch (err) {
        notify(t('fetchFailed', String(err instanceof Error ? err.message : err)));
      }
      break;
    case 'mark-heard': {
      for (const ep of state.episodes) await episodeSetDone(ep.id, '1').catch(() => {});
      await refreshLibrary();
      notify(t('ui-marked-list'));
      break;
    }
    case 'episode-more':
      episodeMoreDialog(id);
      break;
    case 'download':
      closeDialog();
      await episodeDownload(id).catch((err) =>
        notify(t('fetchFailed', String(err instanceof Error ? err.message : err))),
      );
      notify(t('statusJob_running'));
      break;
    case 'remove-audio':
      closeDialog();
      await episodeRemoveAudio(id).catch(() => {});
      notify(t('statusAudio_removed'));
      await refreshLibrary();
      break;
    case 'mark-done':
      closeDialog();
      await episodeSetDone(id, '1').catch(() => {});
      await refreshLibrary();
      notify(t('marked-done'));
      break;
    case 'mark-undone':
      closeDialog();
      await episodeSetDone(id, '0').catch(() => {});
      await refreshLibrary();
      notify(t('marked-undone'));
      break;
    case 'refresh-feed': {
      const added = await feedRefresh(id).catch(() => 0);
      notify(t('refreshed', added));
      await refreshLibrary();
      break;
    }
    case 'refresh-all': {
      const added = await feedRefreshAll().catch(() => 0);
      notify(t('refreshed', added));
      await refreshLibrary();
      break;
    }
    case 'add-feed':
      addFeedDialog();
      break;
    case 'add-feed-confirm': {
      const url = ($('#feed-url') as HTMLInputElement | null)?.value.trim() ?? '';
      if (!url) {
        notify(t('feedURLRequired'));
        return;
      }
      try {
        const newId = await feedAdd(url);
        closeDialog();
        notify(t('feedAdded'));
        await refreshLibrary();
        await navigate('episodes', { show: newId });
      } catch (err) {
        notify(t('fetchFailed', String(err instanceof Error ? err.message : err)));
      }
      break;
    }
    case 'remove-feed':
      removeFeedDialog(id);
      break;
    case 'remove-feed-confirm':
      closeDialog();
      await feedRemove(id).catch(() => {});
      notify(t('statusFeed_removed'));
      state.show = null;
      await refreshLibrary();
      await navigate('episodes');
      break;
    case 'reveal-key': {
      const input = $('#api-key') as HTMLInputElement | null;
      if (!input) break;
      input.type = input.type === 'password' ? 'text' : 'password';
      el.textContent = input.type === 'password' ? t('showKey') : t('hideKey');
      break;
    }
    case 'remove-key':
      await settingsSet('api-key', '').catch(() => {});
      await loadSettings();
      notify(t('statusSaved'));
      render();
      break;
    case 'test-connection': {
      const result = $('#settings-result');
      if (result) result.textContent = t('testingConnection');
      try {
        const probe = JSON.parse(await aiTest()) as { ok?: boolean; message?: string };
        if (result) result.textContent = probe.ok ? t('ready') : probe.message ?? t('connectionTestUnreadable');
      } catch {
        if (result) result.textContent = t('connectionTestUnreadable');
      }
      break;
    }
    case 'save-settings':
      await saveSettings();
      break;
    case 'check-updates': {
      const result = $('#update-result');
      if (result) result.textContent = t('updateChecking');
      try {
        const check = await updateCheck();
        if (check.status === 'available' && check.availableVersion) updateDialog(check.availableVersion);
        else if (result) {
          result.textContent =
            check.status === 'up-to-date' ? t('updateUpToDate')
            : check.status === 'dev' ? t('updateNotInstalled')
            : t('updateCheckFailed', check.error ?? '');
        }
      } catch (err) {
        if (result) result.textContent = t('updateCheckFailed', String(err instanceof Error ? err.message : err));
      }
      break;
    }
    case 'update-download':
      closeDialog();
      await startDownload().catch(() => {});
      notify(t('updateDownloading'));
      updating = true;
      break;
    case 'open-releases':
      closeDialog();
      await openReleases().catch(() => {});
      break;
    case 'reveal-data':
      await apiPost('api/host/reveal', { path: '' }).catch(() => {});
      break;
    case 'about-website':
      await apiPost('api/host/open_external', { url: 'https://github.com/turlamai/podlens' }).catch(() => {});
      break;
    case 'about-issue':
      await apiPost('api/host/open_external', { url: 'https://github.com/turlamai/podlens/issues' }).catch(() => {});
      break;
    case 'close-dialog':
      closeDialog();
      break;
    case 'configure':
      closeDialog();
      await navigate('settings');
      break;
  }
}
let updating = false;

// ---- boot ----------------------------------------------------------------
async function boot(): Promise<void> {
  player.initPlayer();
  player.hooks.render = scheduleRender;
  player.hooks.syncPositionUi = syncPositionUi;
  player.hooks.notify = notify;
  player.hooks.onEnded = (ep) => {
    const list = state.episodes.length ? state.episodes : state.recent;
    const i = list.findIndex((e) => e.id === ep.id);
    const next = list[i + 1];
    if (next) {
      notify(t('autoplayNext'));
      void player.playEpisode(next.id, { seekTo: 0 });
    }
  };
  const ok = await hasBackend();
  if (!ok) {
    $('#app')!.innerHTML = `<main class="content"><h1>PodLens</h1><p>${esc(t('backendNotReady'))}</p></main>`;
    return;
  }
  await loadSettings();
  await Promise.all([loadFeeds(), loadRecent(), loadCatalog()]);
  await loadResume();
  if (state.episode) await ensureEpisodeContent(state.episode);
  state.loaded = true;
  render();

  onEngineEvent('notify', (payload) => notify(String(payload)));
  onEngineEvent('job-progress', (payload) => {
    const row = payload as string[];
    const jobId = row[0] ?? '';
    state.jobs[jobId] = { kind: row[1] ?? '', pct: Number(row[2]) || 0, message: row[3] ?? '' };
    scheduleRender();
  });
  onEngineEvent('episodes-changed', () => {
    void refreshLibrary();
    if (state.episode) {
      contentFor = null;
      void ensureEpisodeContent(state.episode);
    }
  });
  onEngineEvent('open-url', (payload) => {
    void apiPost('api/host/open_external', { url: String(payload) }).catch(() => {});
  });
  onEngineEvent('update-available', (payload) => updateDialog(String(payload)));

  document.addEventListener('click', (event) => {
    const el = (event.target as HTMLElement).closest(
      'button[data-action],button[data-page],[role=button][data-action]',
    ) as HTMLElement | null;
    if (!el) return;
    if (el.dataset.page) {
      void navigate(el.dataset.page as Page, { show: el.dataset.show, filter: el.dataset.filter });
      return;
    }
    void onAction(el);
  });

  let searchTimer: number | undefined;
  document.addEventListener('input', (event) => {
    const target = event.target as HTMLInputElement;
    if (target.id === 'seek') player.seek(Number(target.value));
    if (target.id === 'search') {
      state.query = target.value;
      window.clearTimeout(searchTimer);
      searchTimer = window.setTimeout(() => {
        void (async () => {
          const q = state.query.trim();
          try {
            const rows = q ? await catalogSearch(q) : await (async () => {
              await loadCatalog();
              return null;
            })();
            if (rows) {
              state.catalog = rows.map((r) => ({
                id: r[0] ?? '', category: r[1] ?? '', title: r[2] ?? '', description: r[3] ?? '',
                url: r[4] ?? '', homepage: r[5] ?? '', added: r[6] === '1', artwork: r[7] ?? '',
              }));
            }
            const box = $('#search-results');
            if (box) box.innerHTML = discoverResults(state.catalog);
          } catch {
            notify(t('searchFailed'));
          }
        })();
      }, 400);
    }
    if (target.id === 'api-base') {
      const result = $('#settings-result');
      if (result) result.textContent = '';
    }
  });

  document.addEventListener('change', (event) => {
    const el = event.target as HTMLInputElement;
    if (el.id === 'rate') player.setRate(Number(el.value));
    if (el.id === 'sleep') player.setSleep(Number(el.value));
    if (el.id === 'theme-choice') {
      state.settings['appearance'] = el.value;
      void settingsSet('appearance', el.value).catch(() => {});
      applyAppearance();
      render();
    }
    if (el.id === 'auto-follow') setFollow(el.checked, false);
    if (el.id === 'ui-lang') {
      void settingsSet('ui-lang', el.value).then(() => loadSettings()).then(() => render());
    }
    if (el.id === 'autostart') {
      void apiPost('api/host/autostart_set', { enabled: el.checked }).catch(() => {});
    }
  });

  document.addEventListener('focusout', (event) => {
    if ((event.target as HTMLElement).id === 'api-base') checkApiBase();
  });

  // Manual browsing pauses follow until "Current" resumes it (ec81a1a).
  document.addEventListener('wheel', (event) => {
    if (state.follow && (event.target as HTMLElement).closest('.reading')) setFollow(false, true);
  }, { passive: true });
  document.addEventListener('touchmove', (event) => {
    if (state.follow && (event.target as HTMLElement).closest('.reading')) setFollow(false, true);
  }, { passive: true });

  document.addEventListener('keydown', (event) => {
    const target = event.target as HTMLElement;
    if (target.matches('input,textarea,select,[contenteditable=true]') || dialog().open) return;
    if (event.code === 'Space' && target === document.body) {
      event.preventDefault();
      player.toggle();
    }
    if ((event.ctrlKey || event.metaKey) && ['ArrowLeft', 'ArrowRight'].includes(event.key)) {
      event.preventDefault();
      player.seek(player.position() + (event.key === 'ArrowLeft' ? -15 : 30));
    }
    if (event.key.toLowerCase() === 'f' && ['transcript', 'summary'].includes(state.page)) {
      state.focus = !state.focus;
      render();
    }
    if ((event.key === 'Enter' || event.code === 'Space') && target.matches('.sentence')) {
      event.preventDefault();
      target.click();
    }
    if (event.key === '/' && state.page === 'discover') {
      event.preventDefault();
      $('#search')?.focus();
    }
  });

  window.addEventListener('pagehide', () => player.saveNow());
  // Same-document hash navigation (verify.rkt → #e2e) does not reload the
  // page, so re-check the harness gate on hashchange as well.
  window.addEventListener('hashchange', () => {
    void runHarnessIfGated();
  });
  window.setInterval(() => {
    player.sleepTick();
    if (updating) {
      void updateState().then((st) => {
        const result = $('#update-result');
        if (st.phase === 'downloading' && result) {
          result.textContent = t('updateDownloading_percent', Math.round(st.percent));
        } else if (st.phase === 'ready' || st.phase === 'downloaded') {
          updating = false;
          notify(t('updateDownloaded'));
          if (result) result.textContent = t('updateReady_body');
        } else if (st.phase === 'error' || st.phase === 'failed') {
          updating = false;
          if (result) result.textContent = t('updateInstallFailed', st.message ?? '');
        }
      }).catch(() => {});
    }
  }, 1000);

  void runHarnessIfGated();
}

void boot();