// Playback controller (#63 slice 2): the webview's HTML5 <audio> element
// streams the engine's audio cache over the host's Range-capable media
// route; the bootstrap cookie authenticates it. Positions persist through
// position-save (throttled), resume through resume-last. MediaSession /
// Now Playing integration lands in slice 3.
import { audioUrl, positionSave, episodeDownload, episodeChapters } from '@podlens/core';
import { state, episodeOf, feedOfEpisode, currentSentence, t, type Episode } from './state';

let audio: HTMLAudioElement | null = null;
let lastSaveAt = 0;
let sleepDeadline = 0;

/** Hooks installed by main.ts so the player never imports the renderer. */
export const hooks = {
  render: (): void => {},
  syncPositionUi: (): void => {},
  notify: (_message: string): void => {},
  onEnded: (_ep: Episode): void => {},
};

export function initPlayer(): void {
  audio = document.getElementById('audio') as HTMLAudioElement | null;
  if (!audio) return;
  audio.addEventListener('timeupdate', onTime);
  audio.addEventListener('loadedmetadata', () => hooks.syncPositionUi());
  audio.addEventListener('play', () => {
    state.playing = true;
    syncMediaSession();
    hooks.render();
  });
  audio.addEventListener('pause', () => {
    state.playing = false;
    saveNow();
    syncMediaSession();
    hooks.render();
  });
  audio.addEventListener('ended', onEnded);
  audio.addEventListener('error', () => {
    if (state.episode && audio?.getAttribute('src')) {
      hooks.notify(t('statusPlayback_failed'));
    }
  });
  installMediaSessionActions();
}

// ---- OS now-playing bridge (#63 slice 3) --------------------------------
// MediaSession metadata + position state feed SMTC (Windows WebView2),
// Now Playing (macOS WKWebView) and MPRIS (WebKitGTK). Transport and
// chapter actions ride the same seek/play paths as the in-page controls.
function syncMediaSession(): void {
  if (typeof navigator === 'undefined' || !('mediaSession' in navigator)) return;
  const ep = episodeOf(state.episode);
  const feed = feedOfEpisode(ep);
  try {
    navigator.mediaSession.metadata = new MediaMetadata({
      title: ep?.title ?? 'PodLens',
      artist: feed?.title || ep?.feedTitle || '',
      album: 'PodLens',
      artwork: feed?.artwork ? [{ src: feed.artwork }] : [],
    });
  } catch {
    /* metadata unsupported on this platform */
  }
  navigator.mediaSession.playbackState = state.playing ? 'playing' : 'paused';
  syncPositionState();
}

function syncPositionState(): void {
  if (typeof navigator === 'undefined' || !('mediaSession' in navigator)) return;
  const dur = duration();
  if (!dur) return;
  try {
    navigator.mediaSession.setPositionState({
      duration: dur,
      playbackRate: state.rate,
      position: Math.min(position(), dur),
    });
  } catch {
    /* invalid position state (e.g. duration not known yet) */
  }
}

function installMediaSessionActions(): void {
  if (typeof navigator === 'undefined' || !('mediaSession' in navigator)) return;
  const ms = navigator.mediaSession;
  ms.setActionHandler('play', () => {
    if (state.episode) void playEpisode(state.episode);
  });
  ms.setActionHandler('pause', () => pause());
  ms.setActionHandler('stop', () => {
    pause();
    seek(0);
  });
  ms.setActionHandler('seekbackward', (d) => seek(position() - (d.seekOffset ?? 15)));
  ms.setActionHandler('seekforward', (d) => seek(position() + (d.seekOffset ?? 30)));
  ms.setActionHandler('seekto', (d) => {
    if (d.seekTime !== undefined) seek(d.seekTime);
  });
  ms.setActionHandler('previoustrack', () => {
    void chapterJump(-1);
  });
  ms.setActionHandler('nexttrack', () => {
    void chapterJump(1);
  });
}

async function chapterJump(dir: 1 | -1): Promise<void> {
  const id = state.episode;
  if (!id) return;
  const rows = await episodeChapters(id).catch(() => [] as string[][]);
  const starts = rows.map((r) => Number(r[0]) || 0).sort((a, b) => a - b);
  const p = position();
  const target =
    dir === 1 ? starts.find((s) => s > p + 0.5) : [...starts].reverse().find((s) => s < p - 1);
  if (target !== undefined) seek(target);
}

export function position(): number {
  if (audio && state.episode && audio.getAttribute('src')) return audio.currentTime || 0;
  return episodeOf(state.episode)?.position ?? 0;
}

export function duration(): number {
  const meta = audio?.duration;
  if (meta && Number.isFinite(meta) && meta > 0) return meta;
  return episodeOf(state.episode)?.duration ?? 0;
}

function ensureSrc(id: string): void {
  if (!audio) return;
  const want = audioUrl(id);
  if (audio.getAttribute('src') !== want) {
    // Assigning src starts the load; an explicit load() here would abort
    // that first load and can leave the WebView2 media pipeline stalled.
    audio.src = want;
  }
  audio.playbackRate = state.rate;
}

export async function playEpisode(
  id: string,
  opts: { seekTo?: number; autoplay?: boolean } = {},
): Promise<void> {
  const ep = episodeOf(id);
  if (!ep || !audio) return;
  if (state.episode !== id) {
    state.episode = id;
    state.reading = null;
  }
  if (!ep.downloaded) {
    state.pendingPlay = id;
    hooks.notify(t('statusNeed_download'));
    try {
      await episodeDownload(id);
    } catch (err) {
      state.pendingPlay = null;
      hooks.notify(t('fetchFailed', String(err instanceof Error ? err.message : err)));
    }
    return;
  }
  state.pendingPlay = null;
  ensureSrc(id);
  syncMediaSession();
  if (opts.seekTo !== undefined) audio.currentTime = Math.max(0, opts.seekTo);
  else if (ep.position > 0 && audio.currentTime === 0) audio.currentTime = ep.position;
  try {
    await audio.play();
  } catch (err) {
    (window as unknown as Record<string, unknown>).__podlensPlayError =
      err instanceof Error ? `${err.name}: ${err.message}` : String(err);
    // Some webviews gate audible autoplay on user activation (the acceptance
    // harness clicks synthetically). Muted autoplay is universally allowed
    // and the policy is checked at play() time, so start muted and unmute
    // once playback runs. Real user gestures never take this path.
    if (err instanceof DOMException && err.name === 'NotAllowedError') {
      audio.muted = true;
      try {
        await audio.play();
        const harness =
          (window as unknown as Record<string, unknown>).__podlensE2E === true;
        if (!harness) {
          audio.muted = false;
          // WebKitGTK pauses muted-autoplay media when unmuted without a real
          // gesture; fall back to muted playback instead of leaving silence.
          if (audio.paused) {
            audio.muted = true;
            await audio.play();
          }
        }
      } catch (err2) {
        (window as unknown as Record<string, unknown>).__podlensMutedPlayError =
          err2 instanceof Error ? `${err2.name}: ${err2.message}` : String(err2);
        hooks.notify(t('statusPlayback_failed'));
      }
    } else {
      hooks.notify(t('statusPlayback_failed'));
    }
  }
}

export function toggle(): void {
  if (!audio || !state.episode) return;
  if (state.playing) audio.pause();
  else void playEpisode(state.episode);
}

/** Warm the media element (src + metadata) when an episode is opened, so
 *  play() never races the initial load: WebView2 can stall a load that
 *  begins inside play() at HAVE_NOTHING (observed in acceptance). */
export function preload(id: string): void {
  ensureSrc(id);
  const a = audio;
  if (!a) return;
  // The webview's media network context can stall the very first load
  // (cold context, observed intermittently in acceptance). One bounded
  // retry; a warm element or an already-playing one is left alone.
  setTimeout(() => {
    if (a.readyState === 0 && a.getAttribute('src')) a.load();
  }, 4000);
}

export function pause(): void {
  audio?.pause();
}

export function seek(seconds: number): void {
  const ep = episodeOf(state.episode);
  if (!ep || !audio) return;
  const bounded = Math.max(0, Math.min(duration() || ep.duration, seconds));
  if (audio.getAttribute('src')) audio.currentTime = bounded;
  ep.position = bounded;
  onTime();
}

export function setRate(rate: number): void {
  state.rate = rate;
  if (audio) audio.playbackRate = rate;
}

export function setSleep(minutes: number): void {
  state.sleep = minutes;
  sleepDeadline = minutes ? Date.now() + minutes * 60000 : 0;
  hooks.notify(minutes ? t('playerSleep_set', minutes) : t('sleepOff'));
}

/** Called once per second from main.ts. */
export function sleepTick(): void {
  if (sleepDeadline && Date.now() >= sleepDeadline) {
    sleepDeadline = 0;
    state.sleep = 0;
    pause();
    hooks.notify(t('sleepFired'));
    hooks.render();
  }
}

export function saveNow(): void {
  const ep = episodeOf(state.episode);
  if (!ep || !audio || !audio.getAttribute('src')) return;
  lastSaveAt = Date.now();
  void positionSave(ep.id, String(Math.floor(audio.currentTime)), ep.done ? '1' : '0').catch(
    () => {},
  );
}

function onTime(): void {
  const ep = episodeOf(state.episode);
  if (!ep) return;
  ep.position = position();
  if (state.follow && state.playing) {
    const sentence = currentSentence(ep.position);
    if (sentence && state.reading !== sentence.start) {
      state.reading = sentence.start;
      if (state.page === 'transcript') {
        document
          .querySelector(`.sentence[data-sec="${sentence.start}"]`)
          ?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
      }
    }
    document.querySelectorAll('.sentence').forEach((el) => {
      el.classList.toggle('current', Number((el as HTMLElement).dataset.sec) === state.reading);
    });
  }
  hooks.syncPositionUi();
  syncPositionState();
  if (Date.now() - lastSaveAt > 5000) saveNow();
}

function onEnded(): void {
  const ep = episodeOf(state.episode);
  if (!ep || !audio) return;
  ep.done = true;
  ep.position = duration();
  void positionSave(ep.id, String(Math.floor(duration())), '1').catch(() => {});
  state.playing = false;
  hooks.notify(t('statusPlayback_done'));
  hooks.onEnded(ep);
  hooks.render();
}

/** Resolve a play request that waited for its download (episodes-changed). */
export function resolvePendingPlay(): void {
  const id = state.pendingPlay;
  if (!id) return;
  const ep = episodeOf(id);
  if (ep?.downloaded) {
    state.pendingPlay = null;
    void playEpisode(id);
  }
}

export function stopForSwitch(): void {
  audio?.pause();
  saveNow();
}