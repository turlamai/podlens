// Slice 1 boot probe (#63): the typed client talks to the production
// engine through the glaze adapter. The full prototype-faithful UI
// (library / episodes / transcript / summary / discover / settings)
// lands in slice 2; this page only proves the wire end to end.
import { hasBackend, health, feedList, audioUrl } from '@podlens/core';

const app = document.getElementById('app')!;

async function boot(): Promise<void> {
  const ok = await hasBackend();
  if (!ok) {
    app.textContent = 'PodLens: backend unavailable';
    return;
  }
  const h = await health();
  const feeds = await feedList();
  app.innerHTML =
    '<h1>PodLens</h1>' +
    `<p id="engine">${h}</p>` +
    `<p id="feeds">feeds: ${feeds.length}</p>` +
    `<p id="media">media carrier: ${audioUrl('probe')}</p>`;
}

void boot();