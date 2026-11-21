// Generated from rivet-schema.json by scripts/gen-rpc-types.py — do not edit.
// Regenerate: pnpm gen:rpc (review the diff; the schema is the single source).

import { apiPost } from './bridge';

// ---- records (camelCase DTOs; field order on the wire is the schema's) ----

export interface UpdateCheck {
  status: string;
  error: string | null;
  currentVersion: string;
  availableVersion: string | null;
  build: number | null;
  publishedAt: string | null;
  installer: string | null;
  sizeBytes: number | null;
}

export interface UpdateState {
  phase: string;
  percent: number;
  message: string | null;
  downloadedPath: string | null;
  availableVersion: string | null;
}

// ---- RPC surface ----

export const RPC_NAMES = [
  'ai-test',
  'catalog-list',
  'catalog-search',
  'episode-chapters',
  'episode-download',
  'episode-estimate',
  'episode-list',
  'episode-pipeline',
  'episode-recent',
  'episode-remove-audio',
  'episode-set-done',
  'episode-summarize',
  'episode-summary',
  'episode-transcribe',
  'episode-transcript',
  'episode-translate',
  'feed-add',
  'feed-list',
  'feed-peek',
  'feed-refresh',
  'feed-refresh-all',
  'feed-remove',
  'health',
  'job-cancel',
  'job-status',
  'open-releases',
  'position-save',
  'preview-audio',
  'resume-last',
  'security-status',
  'settings-list',
  'settings-set',
  'start-download',
  'update-check',
  'update-state',
] as const;

export function aiTest(): Promise<string> {
  return apiPost<string>('api/rpc/ai-test', {  });
}

export function catalogList(): Promise<Array<Array<string>>> {
  return apiPost<Array<Array<string>>>('api/rpc/catalog-list', {  });
}

export function catalogSearch(query: string): Promise<Array<Array<string>>> {
  return apiPost<Array<Array<string>>>('api/rpc/catalog-search', { query });
}

export function episodeChapters(id: string): Promise<Array<Array<string>>> {
  return apiPost<Array<Array<string>>>('api/rpc/episode-chapters', { id });
}

export function episodeDownload(id: string): Promise<string> {
  return apiPost<string>('api/rpc/episode-download', { id });
}

export function episodeEstimate(id: string): Promise<string> {
  return apiPost<string>('api/rpc/episode-estimate', { id });
}

export function episodeList(feedId: string): Promise<Array<Array<string>>> {
  return apiPost<Array<Array<string>>>('api/rpc/episode-list', { feedId });
}

export function episodePipeline(id: string): Promise<string> {
  return apiPost<string>('api/rpc/episode-pipeline', { id });
}

export function episodeRecent(): Promise<Array<Array<string>>> {
  return apiPost<Array<Array<string>>>('api/rpc/episode-recent', {  });
}

export function episodeRemoveAudio(id: string): Promise<boolean> {
  return apiPost<boolean>('api/rpc/episode-remove-audio', { id });
}

export function episodeSetDone(id: string, done: string): Promise<boolean> {
  return apiPost<boolean>('api/rpc/episode-set-done', { id, done });
}

export function episodeSummarize(id: string): Promise<string> {
  return apiPost<string>('api/rpc/episode-summarize', { id });
}

export function episodeSummary(id: string): Promise<string> {
  return apiPost<string>('api/rpc/episode-summary', { id });
}

export function episodeTranscribe(id: string): Promise<string> {
  return apiPost<string>('api/rpc/episode-transcribe', { id });
}

export function episodeTranscript(id: string): Promise<Array<Array<string>>> {
  return apiPost<Array<Array<string>>>('api/rpc/episode-transcript', { id });
}

export function episodeTranslate(id: string): Promise<string> {
  return apiPost<string>('api/rpc/episode-translate', { id });
}

export function feedAdd(url: string): Promise<string> {
  return apiPost<string>('api/rpc/feed-add', { url });
}

export function feedList(): Promise<Array<Array<string>>> {
  return apiPost<Array<Array<string>>>('api/rpc/feed-list', {  });
}

export function feedPeek(url: string): Promise<Array<Array<string>>> {
  return apiPost<Array<Array<string>>>('api/rpc/feed-peek', { url });
}

export function feedRefresh(id: string): Promise<number> {
  return apiPost<number>('api/rpc/feed-refresh', { id });
}

export function feedRefreshAll(): Promise<number> {
  return apiPost<number>('api/rpc/feed-refresh-all', {  });
}

export function feedRemove(id: string): Promise<boolean> {
  return apiPost<boolean>('api/rpc/feed-remove', { id });
}

export function health(): Promise<string> {
  return apiPost<string>('api/rpc/health', {  });
}

export function jobCancel(jobId: string): Promise<boolean> {
  return apiPost<boolean>('api/rpc/job-cancel', { jobId });
}

export function jobStatus(jobId: string): Promise<string> {
  return apiPost<string>('api/rpc/job-status', { jobId });
}

export function openReleases(): Promise<void> {
  return apiPost<null>('api/rpc/open-releases', {  }).then(() => undefined);
}

export function positionSave(id: string, seconds: string, done: string): Promise<boolean> {
  return apiPost<boolean>('api/rpc/position-save', { id, seconds, done });
}

export function previewAudio(enclosureUrl: string): Promise<string> {
  return apiPost<string>('api/rpc/preview-audio', { enclosureUrl });
}

export function resumeLast(): Promise<Array<string>> {
  return apiPost<Array<string>>('api/rpc/resume-last', {  });
}

export function securityStatus(): Promise<string> {
  return apiPost<string>('api/rpc/security-status', {  });
}

export function settingsList(): Promise<Array<Array<string>>> {
  return apiPost<Array<Array<string>>>('api/rpc/settings-list', {  });
}

export function settingsSet(key: string, value: string): Promise<boolean> {
  return apiPost<boolean>('api/rpc/settings-set', { key, value });
}

export function startDownload(): Promise<void> {
  return apiPost<null>('api/rpc/start-download', {  }).then(() => undefined);
}

export function updateCheck(): Promise<UpdateCheck> {
  return apiPost<UpdateCheck>('api/rpc/update-check', {  });
}

export function updateState(): Promise<UpdateState> {
  return apiPost<UpdateState>('api/rpc/update-state', {  });
}
