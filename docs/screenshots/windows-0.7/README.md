# Windows 0.7 parity evidence

Captured by the packaged WinUI acceptance at **1024×768** with the synthetic
listening fixture.

| File | State |
|---|---|
| `focus-1024x768.png` | Focus Listening: header removed, brand buttons, three reading modes, follow-off status |
| `library-1024x768.png` | Restored library: page header, reading modes, current-sentence highlight, player |
| `vmpal-windows11-library.jpg` | Published MSI on a real Windows 11 26H2 VM via VMPal |
| `vmpal-windows11-translation.jpg` | Translation-only reading mode on the VMPal install |
| `vmpal-windows11-settings.jpg` | Settings with the DPAPI storage note and masked key |
| `vmpal-windows11-focus.jpg` | Focus Listening, header band removed |
| `vmpal-windows11-cancel.jpg` | Active pipeline job with the Cancel action |
| `vmpal-windows11-cancelled-075.jpg` | 0.7.5: Cancel leaves the progress state immediately on Windows 11 |

The journey also asserts the tab order, sentence activation, follow off/on,
Focus round-trip, Settings save and application termination in
`interaction-trace.json` (CI artifact). Windows keeps native WinUI controls;
it does not copy macOS chrome.
