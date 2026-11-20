// View renderers (#63 slice 2). Markup and class names follow
// design/prototype/app.js + shared.css (the visual truth); every label
// comes from the generated i18n table and every datum from engine RPCs.
import {
  state,
  t,
  feedOf,
  episodeOf,
  feedOfEpisode,
  currentSentence,
  pageLabelKey,
  type Episode,
  type Feed,
  type CatalogEntry,
} from './state';
import { position, duration } from './player';

export const esc = (value: unknown): string =>
  String(value).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  })[c] as string);

const paths: Record<string, string> = {
  lens: '<path d="M5 5h5v14H5zM14 3h5v18h-5z"/><path d="M8 9v6m8-9v12"/>',
  home: '<path d="m3 10 9-7 9 7v10H3zM9 20v-7h6v7"/>',
  compass: '<circle cx="12" cy="12" r="9"/><path d="m16 8-3 5-5 3 3-5z"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  grid: '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
  download: '<path d="M12 3v12m-5-5 5 5 5-5M4 16v5h16v-5"/>',
  settings: '<path d="M4 7h16M4 17h16"/><circle cx="9" cy="7" r="3"/><circle cx="15" cy="17" r="3"/>',
  plus: '<path d="M12 4v16M4 12h16"/>',
  play: '<path d="m9 5 10 7-10 7z"/>',
  pause: '<path d="M8 5v14M16 5v14"/>',
  book: '<path d="M12 5v15M3 4c4-1 7 0 9 2 2-2 5-3 9-2v15c-4-1-7 0-9 2-2-2-5-3-9-2z"/>',
  arrow: '<path d="M4 12h16m-6-6 6 6-6 6"/>',
  replay: '<path d="M4 9a8 8 0 1 1 0 6M4 3v6h6"/>',
  moon: '<path d="M20 14A9 9 0 0 1 10 3a9 9 0 1 0 10 11z"/>',
  search: '<circle cx="10" cy="10" r="7"/><path d="m15 15 6 6"/>',
  check: '<path d="m5 12 4 4L20 5"/>',
  menu: '<path d="M4 6h16M4 12h16M4 18h16"/>',
  focus: '<path d="M9 3H3v6m12-6h6v6M3 15v6h6m6 0h6v-6"/>',
  close: '<path d="m5 5 14 14M19 5 5 19"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 1v2m0 18v2M1 12h2m18 0h2M4 4l2 2m12 12 2 2M4 20l2-2M18 6l2-2"/>',
};

export const icon = (name: string): string =>
  `<svg class="od-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name] || paths.book}</svg>`;

export const time = (s: number): string =>
  `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(Math.floor(s % 60)).padStart(2, '0')}`;

const button = (text: string, action: string, cls = '', attrs = ''): string =>
  `<button type="button" class="btn ${cls}" data-action="${action}" ${attrs}>${text}</button>`;

const navButton = (label: string, page: string, glyph: string, attrs = ''): string =>
  `<button type="button" class="nav-btn ${state.page === page && !state.show ? 'active' : ''}" data-page="${page}" ${attrs}>${icon(glyph)}<span>${label}</span></button>`;

/** Real artwork when the feed carries one; typographic fallback otherwise. */
const cover = (feed: Feed | undefined, mini = false): string => {
  const name = feed?.title ?? '';
  const initials = name.slice(0, 2).toUpperCase() || '··';
  const art = feed?.artwork
    ? `<img src="${esc(feed.artwork)}" alt="" loading="lazy">`
    : '';
  return `<div class="cover${mini ? ' mini' : ''}" aria-label="${esc(name)}">${art}<small>${esc(feed?.author ?? '')}</small><strong>${esc(mini ? initials : name.slice(0, 12))}</strong><span class="cover-line"></span></div>`;
};

const entryCover = (entry: CatalogEntry, mini = false): string => {
  const art = entry.artwork ? `<img src="${esc(entry.artwork)}" alt="" loading="lazy">` : '';
  return `<div class="cover${mini ? ' mini' : ''}" aria-label="${esc(entry.title)}">${art}<small>${esc(entry.category)}</small><strong>${esc(entry.title.slice(0, 12))}</strong><span class="cover-line"></span></div>`;
};

export function sidebar(): string {
  return `<aside class="sidebar" aria-label="${esc(t('librarySection'))}"><button type="button" class="brand" data-page="home" style="border:0;background:none;text-align:left"><span class="brand-mark">${icon('lens')}</span>PodLens</button>
 <nav class="nav-group">${navButton(t('homeTab'), 'home', 'home')}${navButton(t('discover'), 'discover', 'compass')}</nav>
 <nav class="nav-group"><div class="nav-title">${esc(t('librarySection'))}</div>${navButton(t('recentlyUpdated'), 'episodes', 'clock', 'data-filter="all"')}${navButton(t('showsTab'), 'episodes', 'grid', 'data-filter="shows"')}${navButton(t('downloadedTab'), 'episodes', 'download', 'data-filter="downloaded"')}</nav>
 <nav class="nav-group"><div class="nav-title">${esc(t('subscriptionsSection'))}</div>${state.feeds.map((f) => `<button type="button" class="nav-btn ${state.show === f.id ? 'active' : ''}" data-page="episodes" data-show="${esc(f.id)}">${cover(f, true)}<span class="od-field od-fill"><span class="od-truncate">${esc(f.title)}</span><span class="sub">${esc(t('ui-show-tile-count', f.count))}</span></span></button>`).join('')}${button(`${icon('plus')} ${esc(t('addFeed'))}`, 'add-feed', 'text')}</nav>
 <div class="side-bottom">${navButton(t('settings'), 'settings', 'settings')}<p>${esc(t('appTagline'))}</p></div></aside>`;
}

const stageKey = (job: { kind: string; message: string }): string => {
  if (['downloading', 'transcribing', 'translating', 'summarizing'].includes(job.message)) {
    return job.message;
  }
  return job.kind === 'download' ? 'downloading'
    : job.kind === 'translate' ? 'translating'
    : job.kind === 'summarize' ? 'summarizing'
    : 'transcribing';
};

function jobChip(ep: Episode): string {
  const job = state.jobs[ep.id];
  if (job) {
    if (job.kind === 'cancelled') return `<span class="chip pending">${esc(t('jobCancelled'))}</span>`;
    return `<span class="chip pending">${esc(t(stageKey(job)))}<span class="pct">${Math.round(job.pct)}%</span></span>`;
  }
  if (ep.transcriptStatus === 'done') {
    return `<span class="chip ready">${icon('check')} ${esc(t('ui-chip-ready'))}</span>`;
  }
  if (ep.transcriptStatus === 'error' || ep.summaryStatus === 'error') {
    return `<span class="chip pending">${esc(t('jobFailed'))}</span>`;
  }
  if (ep.transcriptStatus === 'cancelled') {
    return `<span class="chip pending">${esc(t('jobCancelled'))}</span>`;
  }
  if (ep.transcriptStatus === 'running') {
    return `<span class="chip pending">${esc(t('transcribing'))}</span>`;
  }
  return `<span class="chip">${esc(t('ui-chip-none'))}</span>`;
}

export function row(ep: Episode): string {
  const feed = feedOfEpisode(ep);
  const current = state.episode === ep.id;
  const job = state.jobs[ep.id];
  const mins = Math.round(ep.duration / 60);
  return `<article class="episode-row">${cover(feed)}<div class="od-fill"><button type="button" class="episode-title" data-action="open" data-id="${esc(ep.id)}">${esc(ep.title)}</button><div class="meta">${esc(feed?.title ?? ep.feedTitle)} · ${esc(ep.date)} · ${esc(t('ui-duration-minutes', mins))}${ep.done ? ' · ' + esc(t('done')) : ''}</div><div class="chips">${ep.downloaded ? `<span class="chip">${esc(t('tooltipDownloaded'))}</span>` : ''}${jobChip(ep)}</div></div><div class="row-actions">${job && job.kind !== 'cancelled' ? button(esc(t('cancel')), 'cancel-job', '', `data-id="${esc(ep.id)}"`) : ''}${button(icon(current && state.playing ? 'pause' : 'play'), 'play-episode', '', `data-id="${esc(ep.id)}" aria-label="${esc(current && state.playing ? t('pause') : t('play'))} ${esc(ep.title)}"`)}${ep.transcriptStatus === 'done' ? button(esc(t('transcriptTab')), 'open', 'text', `data-id="${esc(ep.id)}"`) : button(esc(t('pipeline')), 'generate', 'text', `data-id="${esc(ep.id)}"`)}${button(icon('menu'), 'episode-more', '', `data-id="${esc(ep.id)}" aria-label="${esc(t('detailActions'))}"`)}</div></article>`;
}

function showTiles(): string {
  return `<div class="show-grid">${state.feeds.map((f) => `<button type="button" class="show-tile" data-page="episodes" data-show="${esc(f.id)}">${cover(f)}<span class="od-field"><span class="od-clamp-2">${esc(f.title)}</span><small>${esc(t('ui-show-tile-count', f.count))}</small></span></button>`).join('')}</div>`;
}

export function home(): string {
  const ep = episodeOf(state.episode) ?? state.recent[0];
  if (!ep) {
    return `<div class="page-heading"><div><h1>${esc(t('homeHeroTitle'))}</h1><p>${esc(t('homeHeroSubtitle'))}</p></div>${button(`${icon('plus')} ${esc(t('addFeed'))}`, 'add-feed')}</div><div class="empty"><h2>${esc(t('emptyFeeds_title'))}</h2><p>${esc(t('emptyFeeds_hint'))}</p>${button(esc(t('goToDiscover')), 'discover')}</div>`;
  }
  const feed = feedOfEpisode(ep);
  const p = state.episode === ep.id ? position() : ep.position;
  const dur = state.episode === ep.id ? duration() || ep.duration : ep.duration;
  const sentence = state.episode === ep.id ? currentSentence(p) : undefined;
  const ready = ep.transcriptStatus === 'done';
  return `<div class="page-heading"><div><h1>${esc(t('homeHeroTitle'))}</h1><p>${esc(t('homeHeroSubtitle'))}</p></div>${button(`${icon('plus')} ${esc(t('addFeed'))}`, 'add-feed')}</div>
 <section class="hero"><div><div class="eyebrow">${esc(t('continueListening'))}</div><h2>${esc(ep.title)}</h2><div class="meta">${esc(feed?.title ?? ep.feedTitle)} · ${esc(t('ui-duration-minutes', Math.round(dur / 60)))}</div><div class="progress-line"><progress data-hero-progress max="${dur}" value="${p}" aria-label="${esc(t('playbackPosition'))}"></progress><small data-hero-time>${time(p)} / ${time(dur)}</small></div>
 <div class="actions">${button(`${icon(state.playing && state.episode === ep.id ? 'pause' : 'play')} <span data-toggle-label>${esc(state.playing && state.episode === ep.id ? t('pause') : t('continueListening'))}</span>`, 'toggle', 'primary')}${button(`${icon('book')} ${esc(ready ? t('backToTranscript') : t('viewEpisode'))}`, 'open-current')}${button(`${icon('replay')} ${esc(t('restartFromStart'))}`, 'restart', 'text')}</div>
 <div class="resume-line">${icon('book')}<div>${ready && sentence ? `${esc(t('homeResumePrefix'))} <strong>${time(sentence.start)}</strong><p>${esc(sentence.translation || sentence.text)}</p>` : `${esc(t('homeResumeNone'))}<p>${esc(t('homeResumeNoneHint'))}</p>`}</div></div></div>${cover(feed)}</section>
 <section class="section"><div class="section-head"><h2>${esc(t('recentlyUpdated'))} <small>${esc(t('subscriptionsSection'))}</small></h2>${button(`${esc(t('seeAll'))} ${icon('arrow')}`, 'all-episodes', 'text')}</div>${state.recent.filter((e) => e.id !== ep.id).slice(0, 3).map(row).join('') || `<p class="notice">${esc(t('homeRecentEmpty'))}</p>`}</section>
 <section class="section"><div class="section-head"><h2>${esc(t('myShowsLane'))}</h2><small>${esc(t('ui-show-tile-count', state.feeds.length))}</small></div>${state.feeds.length ? showTiles() : `<p class="notice">${esc(t('emptyFeeds_hint'))}</p>`}</section>`;
}

export function listPage(): string {
  if (state.filter === 'shows') {
    return `<div class="page-heading"><div><h1>${esc(t('myShowsLane'))}</h1><p>${esc(t('ui-library-sub', state.feeds.length))}</p></div></div>${state.feeds.length ? showTiles() : `<div class="empty"><h2>${esc(t('showsEmptyTitle'))}</h2><p>${esc(t('emptyFeeds_hint'))}</p>${button(esc(t('goToDiscover')), 'discover')}</div>`}`;
  }
  const show = state.show ? feedOf(state.show) : undefined;
  const list = state.episodes;
  const title = show ? show.title : state.filter === 'downloaded' ? t('downloadedTab') : t('recentlyUpdated');
  const sub = show ? `${t('ui-episode-count-sub', list.length)} · ${show.author}` : `${t('ui-episode-count-sub', list.length)} · ${t('ui-list-sub')}`;
  return `<div class="page-heading"><div><h1>${esc(title)}</h1><p>${esc(sub)}</p></div>${show ? button(`${icon('refresh')} ${esc(t('refresh'))}`, 'refresh-feed', 'text', `data-id="${esc(show.id)}"`) : button(`${icon('refresh')} ${esc(t('menuRefreshAll'))}`, 'refresh-all', 'text')}</div><div class="detail-tools"><div class="tabs">${(['all', 'downloaded'] as const).map((id) => `<button class="tab ${state.filter === id ? 'active' : ''}" data-action="filter" data-filter="${id}">${esc(id === 'all' ? t('allCategories') : t('downloadedTab'))}</button>`).join('')}</div><span class="od-fill"></span>${button(esc(t('ui-mark-all-heard')), 'mark-heard', 'text')}</div>${list.length ? list.map(row).join('') : `<div class="empty"><h2>${esc(state.filter === 'downloaded' ? t('downloadedEmptyTitle') : t('recentEmptyTitle'))}</h2><p>${esc(state.filter === 'downloaded' ? t('ui-downloaded-empty-body') : t('emptyEpisodes_hint'))}</p></div>`}`;
}

function detailHeader(): string {
  const ep = episodeOf(state.episode);
  const feed = feedOfEpisode(ep);
  if (!ep) return `<div class="empty"><h2>${esc(t('selectEpisodeTitle'))}</h2><p>${esc(t('detailHint'))}</p></div>`;
  const ready = ep.transcriptStatus === 'done';
  return `<div class="detail-heading">${cover(feed)}<div class="od-fill"><div class="eyebrow">${esc(feed?.title ?? ep.feedTitle)}</div><h1>${esc(ep.title)}</h1><div class="meta">${esc(ep.date)} · ${esc(t('ui-duration-minutes', Math.round(ep.duration / 60)))} · ${esc(ready ? t('ui-detail-ready') : t('ui-detail-not-ready'))}</div></div><button type="button" class="icon-btn" data-action="focus" aria-label="${esc(state.focus ? t('focusExit') : t('focusEnter'))}" title="${esc(t('ui-focus-hint'))}">${icon(state.focus ? 'close' : 'focus')}</button></div>`;
}

const detailTabs = (active: 'transcript' | 'summary'): string =>
  `<nav class="tabs" aria-label="${esc(t('episodes'))}"><button class="tab ${active === 'transcript' ? 'active' : ''}" data-page="transcript">${esc(t('transcriptTab'))}</button><button class="tab ${active === 'summary' ? 'active' : ''}" data-page="summary">${esc(t('summaryTab'))}</button></nav>`;

export function transcript(): string {
  const ep = episodeOf(state.episode);
  if (!ep) return detailHeader();
  const ready = ep.transcriptStatus === 'done';
  return `${detailHeader()}<div class="detail-tools">${detailTabs('transcript')}<div class="segmented" aria-label="${esc(t('readingMode'))}">${(['bilingual', 'translation', 'original'] as const).map((id) => `<button type="button" data-action="language" data-language="${id}" aria-pressed="${state.language === id}" class="${state.language === id ? 'active' : ''}">${esc(t(id === 'bilingual' ? 'modeBilingual' : id === 'translation' ? 'modeTranslation' : 'modeOriginal'))}</button>`).join('')}</div><div class="tool-end">${button(`${esc(t('followTranscript'))} ${esc(state.follow ? t('ui-on') : t('ui-off'))}`, 'follow', '', `aria-pressed="${state.follow}" title="${esc(t('followTranscriptHint'))}"`)}${button(esc(t('returnToCurrent')), 'current', 'text', `title="${esc(t('returnToCurrentHint'))}"`)}</div></div>
 ${ready ? `<div class="reading" data-language="${state.language}"><p class="reading-note">${esc(t('ui-reading-note'))} ${esc(t('transcriptSeekHint'))}</p>${state.transcript.map((row) => `<div class="sentence ${row.start === state.reading ? 'current' : ''}" role="button" tabindex="0" data-action="sentence" data-sec="${row.start}" aria-label="${esc(t('playbackPosition'))} ${time(row.start)} ${esc(row.translation || row.text)}"><span class="stamp">${time(row.start)}</span><div><div class="en" lang="en">${esc(row.text)}</div><div class="zh">${esc(row.translation)}</div></div></div>`).join('')}<div class="reading-footer"><span><kbd>Space</kbd> ${esc(t('keyboardSpaceHint'))}</span><span><kbd>Ctrl / ⌘ ← →</kbd> ${esc(t('ui-keyboard-seek'))}</span><span><kbd>F</kbd> ${esc(t('keyboardFocusHint'))}</span></div></div>` : `<div class="empty"><h2>${esc(t('ui-empty-transcript-title'))}</h2><p>${esc(t('ui-empty-transcript-body'))}</p>${button(esc(t('understandFlow')), 'generate', '', `data-id="${esc(ep.id)}"`)}</div>`}`;
}

export function summary(): string {
  const ep = episodeOf(state.episode);
  if (!ep) return detailHeader();
  const s = state.summary;
  const anchor = (start: number | undefined, label: string): string =>
    start === undefined ? '' : button(`${time(start)} ${icon('arrow')} ${esc(label)}`, 'anchor', 'text', `data-sec="${start}"`);
  return `${detailHeader()}<div class="detail-tools">${detailTabs('summary')}<span class="od-fill"></span>${button(esc(t('returnToCurrent')), 'current', 'text')}</div>${s ? `<div class="reading"><p class="reading-note">${esc(t('ui-summary-note'))}</p><section class="summary-section"><h2>${esc(t('summaryTldrTitle'))}</h2><p class="tldr">${esc(s.tldr)}</p></section><section class="summary-section"><h2>${esc(t('summaryPointsTitle'))}</h2>${(s['key-points'] ?? []).map((p, i) => `<div class="point"><span class="number">0${i + 1}</span><div class="od-fill"><p>${esc(p.text)}</p>${anchor(p.start, t('summaryJumpToPoint'))}</div></div>`).join('')}</section><section class="summary-section"><h2>${esc(t('summaryQuotesTitle'))}</h2>${(s.quotes ?? []).map((q) => `<blockquote class="quote"><p lang="en">“${esc(q.text)}”</p>${q.translation ? `<small>${esc(q.translation)}</small>` : ''}${anchor(q.start, t('summaryReplayQuote'))}</blockquote>`).join('')}</section><section class="summary-section"><h2>${esc(t('summaryTopicsTitle'))}</h2><div class="chips">${(s.topics ?? []).map((topic) => `<span class="chip">${esc(topic)}</span>`).join('')}</div></section></div>` : `<div class="empty"><h2>${esc(t('summaryEmptyTitle'))}</h2><p>${esc(t('summaryEmptyBody'))}</p>${button(esc(t('understandFlow')), 'generate', '', `data-id="${esc(ep.id)}"`)}</div>`}`;
}

function discoverCard(entry: CatalogEntry): string {
  return `<article class="discover-card"><div class="od-row">${entryCover(entry)}<div class="od-fill"><h2>${esc(entry.title)}</h2><div class="meta">${esc(entry.category)}${entry.description ? ' · ' + esc(entry.description) : ''}</div></div></div><div class="actions">${button(`${icon(entry.added ? 'check' : 'plus')} ${esc(entry.added ? t('subscribed') : t('subscribe'))}`, 'subscribe', '', `data-url="${esc(entry.url)}" data-title="${esc(entry.title)}" aria-pressed="${entry.added}"`)}${button(esc(t('preview')), 'preview', 'text', `data-url="${esc(entry.url)}" data-title="${esc(entry.title)}"`)}${entry.added ? button(esc(t('viewEpisode')), 'show-by-title', 'text', `data-title="${esc(entry.title)}"`) : ''}</div></article>`;
}

export function discoverResults(entries: CatalogEntry[]): string {
  return entries.length
    ? `<div class="discover-grid">${entries.map(discoverCard).join('')}</div>`
    : `<div class="empty"><h2>${esc(t('ui-discover-empty-title'))}</h2><p>${esc(t('ui-discover-empty-body'))}</p></div>`;
}

export function discover(): string {
  return `<div class="page-heading"><div><h1>${esc(t('ui-discover-title'))}</h1><p>${esc(t('ui-discover-sub'))}</p></div></div><div class="notice">${esc(state.feeds.length ? t('ui-discover-status-subscribed', state.feeds.length) : t('ui-discover-status-none'))} ${esc(t('discoverNote'))}</div><label class="search-field">${icon('search')}<input id="search" type="search" value="${esc(state.query)}" placeholder="${esc(t('ui-discover-search-placeholder'))}" aria-label="${esc(t('search'))}"></label><div id="search-results">${discoverResults(state.catalog)}</div>`;
}

const formRow = (id: string, label: string, value: string, type = 'text', help = ''): string =>
  `<div class="form-row"><label for="${id}">${esc(label)}${help ? `<small>${esc(help)}</small>` : ''}</label><input id="${id}" type="${type}" value="${esc(value)}" autocomplete="off"></div>`;

export function settings(): string {
  const s = state.settings;
  const sec = state.security;
  const connection = sec
    ? sec.configured
      ? t(sec.secure ? 'settingsStorage_secure' : 'settingsStorage_file', sec.label)
      : t('settingsStorage_none')
    : t('storageUnknown');
  return `<div class="settings"><div class="page-heading"><div><h1>${esc(t('settings'))}</h1><p>${esc(t('settingsReadingHint'))}</p></div></div><section class="settings-group"><h2>${esc(t('settingsReadingGroup'))}</h2><div class="form-row"><label for="theme-choice">${esc(t('appearance'))}<small>${esc(t('ui-appearance-hint'))}</small></label><select id="theme-choice">${(['light', 'dark', 'system'] as const).map((v) => `<option value="${v}" ${(s['appearance'] ?? 'system') === v ? 'selected' : ''}>${esc(t(v === 'light' ? 'appearanceLight' : v === 'dark' ? 'appearanceDark' : 'appearanceSystem'))}</option>`).join('')}</select></div><div class="form-row"><label for="auto-follow">${esc(t('autoFollow'))}<small>${esc(t('autoFollowHint'))}</small></label><input id="auto-follow" type="checkbox" ${state.follow ? 'checked' : ''}></div><div class="form-row"><label for="ui-lang">${esc(t('language'))}<small>${esc(t('languageHint'))}</small></label><select id="ui-lang"><option value="zh" ${state.lang === 'zh' ? 'selected' : ''}>中文</option><option value="en" ${state.lang === 'en' ? 'selected' : ''}>English</option></select></div></section>
 <section class="settings-group"><h2>${esc(t('settingsProvider'))}</h2><p class="meta">${esc(t('ui-settings-provider-note'))} ${esc(t('settingsProviderHint'))}</p>${formRow('api-base', t('apiBase'), s['api-base'] ?? '', 'url', t('apiBaseHint'))}
 <div class="form-row"><label for="api-key">${esc(t('apiKey'))}<small>${esc(sec?.configured ? t('keySavedReplaceHint') : t('keyEmptyHint'))}</small></label><div class="od-row"><input id="api-key" type="password" placeholder="${esc(t('apiKeyPlaceholder'))}" autocomplete="off">${button(esc(t('showKey')), 'reveal-key')}${sec?.configured ? button(esc(t('removeKey')), 'remove-key', 'text') : ''}</div></div><p class="meta">${esc(t('ui-connection-status', connection))}</p><p id="settings-error" class="field-error" role="alert" hidden></p><div class="save-row">${button(esc(t('testConnection')), 'test-connection')}${button(esc(t('saveChanges')), 'save-settings', 'primary')}</div><p id="settings-result" class="meta" role="status"></p>
 <details><summary>${esc(t('ui-advanced-summary'))}</summary>${formRow('chat-model', t('chatModel'), s['chat-model'] ?? '', 'text', t('chatModelHint'))}${formRow('asr-model', t('asrModel'), s['asr-model'] ?? '', 'text', t('asrModelHint'))}${formRow('target-lang', t('targetLanguage'), s['target-lang'] ?? '')}${formRow('asr-chunk-seconds', t('chunkSeconds'), s['asr-chunk-seconds'] ?? '', 'number', t('chunkSecondsHint'))}${formRow('max-transcript-chars', t('maxChars'), s['max-transcript-chars'] ?? '', 'number', t('maxCharsHint'))}${formRow('search-limit', t('searchLimit'), s['search-limit'] ?? '', 'number', t('searchLimitHint'))}<div class="form-row"><label for="auto-update">${esc(t('autoUpdates'))}<small>${esc(t('autoUpdatesHint'))}</small></label><input id="auto-update" type="checkbox" ${s['check-updates-enabled'] === '#t' || s['check-updates-enabled'] === 'true' ? 'checked' : ''}></div><div class="form-row"><label for="autostart">${esc(t('ui-autostart'))}<small>${esc(t('ui-autostart-hint'))}</small></label><input id="autostart" type="checkbox"></div><p class="meta">${esc(t('refreshHint'))}</p></details></section>
 <section class="settings-group"><h2>${esc(t('updateTitle'))}</h2><p class="meta">${esc(t('updateHint'))}</p><div class="save-row">${button(esc(t('ui-check-updates-now')), 'check-updates')}${button(esc(t('ui-open-releases')), 'open-releases', 'text')}</div><p id="update-result" class="meta" role="status"></p></section>
 <section class="settings-group"><h2>${esc(t('ui-local-data'))}</h2><p class="meta">${esc(t('ui-local-data-meta', state.feeds.length, state.recent.length))}</p><div class="save-row">${button(esc(t('ui-reveal-data')), 'reveal-data', 'text')}</div></section>
 <section class="settings-group"><h2>${esc(t('ui-about-links'))}</h2><p class="meta">${esc(t('aboutLicense'))}</p><div class="save-row">${button(esc(t('aboutWebsite')), 'about-website', 'text')}${button(esc(t('aboutReportIssue')), 'about-issue', 'text')}${button(esc(t('aboutReleases')), 'open-releases', 'text')}</div></section></div>`;
}

export function player(): string {
  const ep = episodeOf(state.episode);
  const feed = feedOfEpisode(ep);
  const p = position();
  const dur = duration() || ep?.duration || 0;
  const job = ep ? state.jobs[ep.id] : undefined;
  const meta = job
    ? `${t(stageKey(job))} ${Math.round(job.pct)}%`
    : state.sleep
      ? t('sleepActive', state.sleep)
      : t('ready');
  return `<footer class="player" aria-label="${esc(t('menuPlayback'))}">${ep ? `<button type="button" class="now-playing" data-action="open-current" aria-label="${esc(t('ui-player-open'))}">${cover(feed, true)}<span class="od-field"><span class="od-truncate">${esc(ep.title)}</span><small class="od-truncate">${esc(feed?.title ?? ep.feedTitle)}</small></span></button>` : `<span class="now-playing meta">${esc(t('nothingPlaying'))}</span>`}
 <div class="player-center"><div class="transport"><button type="button" data-action="back" aria-label="${esc(t('playerSkip_back'))}">−15</button><button type="button" class="play" data-action="toggle" aria-label="${esc(state.playing ? t('pause') : t('play'))}">${icon(state.playing ? 'pause' : 'play')}</button><button type="button" data-action="forward" aria-label="${esc(t('playerSkip_forward'))}">+30</button></div>
 <div class="player-range"><span data-time>${time(p)}</span><input id="seek" type="range" min="0" max="${dur || 1}" value="${p}" aria-label="${esc(t('playbackPosition'))}"><span data-remaining>−${time(Math.max(0, dur - p))}</span></div></div>
 <div class="player-extras"><label><span class="sr-only">${esc(t('playerRate_label'))}</span><select id="rate" aria-label="${esc(t('playerRate_label'))}">${[1, 1.25, 1.5, 2, 2.5, 3].map((v) => `<option ${state.rate === v ? 'selected' : ''} value="${v}">${v}×</option>`).join('')}</select></label><select id="sleep" aria-label="${esc(t('sleep'))}">${[[0, t('ui-sleep-off')], [5, t('sleepMinutes', 5)], [15, t('sleepMinutes', 15)], [30, t('sleepMinutes', 30)]].map(([v, label]) => `<option value="${v}" ${state.sleep === v ? 'selected' : ''}>${esc(label)}</option>`).join('')}</select><span class="meta">${esc(meta)}</span></div></footer>`;
}

export function topbar(): string {
  return `<header class="topbar"><button type="button" class="icon-btn mobile-menu" data-action="menu" aria-label="${esc(t('ui-nav-open'))}" aria-expanded="false">${icon('menu')}</button><span class="breadcrumb">${esc(t('librarySection'))} <span aria-hidden="true">/</span> ${esc(t(pageLabelKey[state.page]))}</span><span class="mode-label">${esc(t('appTagline'))}</span><button type="button" class="icon-btn" data-action="theme" aria-label="${esc(t('toggleAppearance'))}">${icon(state.dark ? 'sun' : 'moon')}</button></header>`;
}

export function pageBody(): string {
  switch (state.page) {
    case 'episodes':
      return listPage();
    case 'transcript':
      return transcript();
    case 'summary':
      return summary();
    case 'discover':
      return discover();
    case 'settings':
      return settings();
    default:
      return home();
  }
}