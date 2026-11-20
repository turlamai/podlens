// Playback controller (#63 slice 2): the webview's HTML5 <audio> element
// streams the engine's audio cache over the host's Range-capable media
// route; the bootstrap cookie authenticates it. Positions persist through
// position-save (throttled), resume through resume-last. MediaSession /
// Now Playing integration lands in slice 3.
import { audioUrl, positionSave, episodeDownload } from '@podlens/core';
import { state, episodeOf, currentSentence, t, type Episode } from './state';

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
    hooks.render();
  });
  audio.addEventListener('pause', () => {
    state.playing = false;
    saveNow();
    hooks.render();
  });
  audio.addEventListener('ended', onEnded);
  audio.addEventListener('error', () => {
    if (state.episode && audio?.getAttribute('src')) {
      hooks.notify(t('statusPlayback_failed'));
    }
  });
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
    audio.src = want;
    audio.load();
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
  if (opts.seekTo !== undefined) audio.currentTime = Math.max(0, opts.seekTo);
  else if (ep.position > 0 && audio.currentTime === 0) audio.currentTime = ep.position;
  try {
    await audio.play();
  } catch {
    hooks.notify(t('statusPlayback_failed'));
  }
}

export function toggle(): void {
  if (!audio || !state.episode) return;
  if (state.playing) audio.pause();
  else void playEpisode(state.episode);
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