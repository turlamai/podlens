import { defineConfig } from 'vite';

// The glaze host serves the built bundle from apps/desktop/dist.
// Dev: run `racket backend/main.rkt` (HTTP carrier) and point the browser
// at its loopback origin, or proxy /api + /glaze here.
export default defineConfig({
  clearScreen: false,
  server: {
    port: 1420,
    strictPort: true,
    proxy: {
      '/api': 'http://127.0.0.1:8765',
      '/glaze': 'http://127.0.0.1:8765',
    },
  },
  build: {
    target: 'es2022',
    outDir: 'dist',
  },
});