# Windows 0.7 parity evidence

Captured by the packaged WinUI acceptance at **1024×768** with the synthetic
listening fixture.

| File | State |
|---|---|
| `focus-1024x768.png` | Focus Listening: header removed, brand buttons, three reading modes, follow-off status |
| `library-1024x768.png` | Restored library: page header, reading modes, current-sentence highlight, player |

The journey also asserts the tab order, sentence activation, follow off/on,
Focus round-trip, Settings save and application termination in
`interaction-trace.json` (CI artifact). Windows keeps native WinUI controls;
it does not copy macOS chrome.
