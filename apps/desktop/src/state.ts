// App state + engine data cache (#63 slice 2). All labels come from the
// generated i18n table (racket/core/i18n.rkt is the single source); all
// data comes from typed RPCs — no localStorage, no demo arrays.
import {
  t as translate,
  type Lang,
  feedList,
  episodeList,
  episodeRecent,
  episodeTranscript,
  episodeSummary,
  catalogList,
  settingsList,
  securityStatus,
  resumeLast,
} from '@podlens/core';

export type Page = 'home' | 'episodes' | 'transcript' | 'summary' | 'discover' | 'settings';
export type ReadingMode = 'bilingual' | 'translation' | 'original';

export interface Feed {
  id: string;
  title: string;
  author: string;
  artwork: string;
  count: number;
  latestTitle: string;
  latestDate: string;
  unplayed: number;
}

export interface Episode {
  id: string;
  title: string;
  date: string;
  duration: number;
  downloaded: boolean;
  transcriptStatus: string;
  summaryStatus: string;
  position: number;
  done: boolean;
  hasTranslation: boolean;
  description: string;
  feedId: string;
  feedTitle: string;
  feedArtwork: string;
}

export interface CatalogEntry {
  id: string;
  category: string;
  title: string;
  description: string;
  url: string;
  homepage: string;
  added: boolean;
  artwork: string;
}

export interface TranscriptRow {
  start: number;
  end: number;
  text: string;
  translation: string;
}

export interface SummaryPoint {
  text: string;
  translation?: string;
  start?: number;
}

export interface Summary {
  tldr: string;
  'key-points': SummaryPoint[];
  quotes: SummaryPoint[];
  topics: string[];
}

export interface JobState {
  kind: string;
  pct: number;
  message: string;
}

export const state = {
  page: 'home' as Page,
  lang: 'zh' as Lang,
  dark: false,
  focus: false,
  filter: 'all' as 'all' | 'downloaded' | 'shows',
  show: null as string | null,
  query: '',
  episode: null as string | null,
  playing: false,
  follow: true,
  language: 'bilingual' as ReadingMode,
  reading: null as number | null,
  rate: 1,
  sleep: 0,
  feeds: [] as Feed[],
  recent: [] as Episode[],
  episodes: [] as Episode[],
  catalog: [] as CatalogEntry[],
  settings: {} as Record<string, string>,
  settingsDesc: {} as Record<string, string>,
  security: null as { backend: string; label: string; secure: boolean; configured: boolean } | null,
  transcript: [] as TranscriptRow[],
  summary: null as Summary | null,
  jobs: {} as Record<string, JobState>,
  pendingPlay: null as string | null,
  preview: null as Episode | null,
  loaded: false,
};

export const t = (key: string, ...args: Array<string | number>): string =>
  translate(state.lang, key, ...args);

/** Engine booleans arrive as "#t" / "true" / "1" depending on the key. */
export const truthy = (v: string | undefined): boolean =>
  v === '#t' || v === 'true' || v === '1';

export const feedOf = (id: string | null | undefined): Feed | undefined =>
  state.feeds.find((f) => f.id === id);

export const episodeOf = (id: string | null | undefined): Episode | undefined =>
  (state.preview && state.preview.id === id ? state.preview : undefined) ??
  state.recent.find((e) => e.id === id) ??
  state.episodes.find((e) => e.id === id);

export const feedOfEpisode = (ep: Episode | undefined): Feed | undefined =>
  feedOf(ep?.feedId);

const episodeFromRow = (r: string[], feedId: string, feedTitle: string, feedArtwork: string): Episode => ({
  id: r[0] ?? '',
  title: r[1] ?? '',
  date: r[2] ?? '',
  duration: Number(r[3]) || 0,
  downloaded: r[4] === '1',
  transcriptStatus: r[5] ?? 'none',
  summaryStatus: r[6] ?? 'none',
  position: Number(r[7]) || 0,
  done: r[8] === '1',
  hasTranslation: r[9] === '1',
  description: r[10] ?? '',
  feedId,
  feedTitle,
  feedArtwork,
});

export async function loadFeeds(): Promise<void> {
  state.feeds = (await feedList()).map((r) => ({
    id: r[0] ?? '',
    title: r[1] ?? '',
    author: r[2] ?? '',
    artwork: r[3] ?? '',
    count: Number(r[4]) || 0,
    latestTitle: r[5] ?? '',
    latestDate: r[6] ?? '',
    unplayed: Number(r[7]) || 0,
  }));
}

export async function loadRecent(): Promise<void> {
  state.recent = (await episodeRecent()).map((r) =>
    episodeFromRow(r.slice(3), r[0] ?? '', r[1] ?? '', r[2] ?? ''),
  );
}

export async function loadEpisodes(): Promise<void> {
  if (state.show) {
    const f = feedOf(state.show);
    state.episodes = (await episodeList(state.show)).map((r) =>
      episodeFromRow(r, state.show as string, f?.title ?? '', f?.artwork ?? ''),
    );
  } else {
    state.episodes = state.recent.filter(
      (e) => state.filter !== 'downloaded' || e.downloaded,
    );
  }
}

export async function loadCatalog(): Promise<void> {
  state.catalog = (await catalogList()).map((r) => ({
    id: r[0] ?? '',
    category: r[1] ?? '',
    title: r[2] ?? '',
    description: r[3] ?? '',
    url: r[4] ?? '',
    homepage: r[5] ?? '',
    added: r[6] === '1',
    artwork: r[7] ?? '',
  }));
}

export async function loadSettings(): Promise<void> {
  const rows = await settingsList();
  state.settings = {};
  state.settingsDesc = {};
  for (const r of rows) {
    const key = r[0] ?? '';
    state.settings[key] = r[1] ?? '';
    state.settingsDesc[key] = r[2] ?? '';
  }
  state.lang = state.settings['ui-lang'] === 'en' ? 'en' : 'zh';
  state.follow = truthy(state.settings['follow-transcript']);
  applyAppearance();
  try {
    // macOS CI keychain queries can block headless sessions forever; the
    // settings view must render even when the security surface is silent.
    state.security = JSON.parse(
      await Promise.race([
        securityStatus(),
        new Promise<string>((_, rej) => setTimeout(() => rej(new Error('security timeout')), 3000)),
      ]),
    );
  } catch {
    state.security = null;
  }
}

export function applyAppearance(): void {
  const mode = state.settings['appearance'] ?? 'system';
  const systemDark =
    typeof matchMedia === 'function' && matchMedia('(prefers-color-scheme: dark)').matches;
  state.dark = mode === 'dark' || (mode !== 'light' && systemDark);
}

export async function loadTranscript(id: string): Promise<void> {
  const rows = await episodeTranscript(id);
  state.transcript = rows.map((r) => ({
    start: Number(r[0]) || 0,
    end: Number(r[1]) || 0,
    text: r[2] ?? '',
    translation: r[3] ?? '',
  }));
  const current = currentSentence();
  state.reading = current ? current.start : null;
}

export async function loadSummary(id: string): Promise<void> {
  const raw = await episodeSummary(id);
  try {
    state.summary = raw ? (JSON.parse(raw) as Summary) : null;
  } catch {
    state.summary = null;
  }
}

/** Last transcript sentence whose anchor is at or before the position. */
export function currentSentence(at?: number): TranscriptRow | undefined {
  const pos = at ?? currentPosition();
  let found: TranscriptRow | undefined;
  for (const row of state.transcript) {
    if (row.start <= pos) found = row;
    else break;
  }
  return found;
}

/** Position source of truth lives in player.ts; injected to avoid a cycle. */
let positionReader: () => number = () => episodeOf(state.episode)?.position ?? 0;
export function setPositionReader(fn: () => number): void {
  positionReader = fn;
}
export function currentPosition(): number {
  return positionReader();
}

export async function loadResume(): Promise<void> {
  const row = await resumeLast();
  if (row.length >= 3) {
    state.episode = row[1] ?? null;
    const ep = episodeOf(state.episode);
    if (ep) ep.position = Number(row[2]) || 0;
  }
}

export const pageLabelKey: Record<Page, string> = {
  home: 'homeTab',
  episodes: 'librarySection',
  transcript: 'transcriptTab',
  summary: 'summaryTab',
  discover: 'discover',
  settings: 'settings',
};