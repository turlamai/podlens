# macOS 0.6 visual evidence

Synthetic library, no real keys, feeds or personal data.

| File | Window | State |
|---|---|---|
| `home-en-1280.png` | 1280×800 | Home, English |
| `home-zh-1280.png` | 1280×800 | Home, Chinese |
| `reading-en-1280.png` | 1280×800 | Focus Listening, bilingual transcript |
| `reading-zh-1280.png` | 1280×800 | Focus Listening, Chinese UI |
| `reading-en-1024x768.png` | 1024×768 | Focus Listening at the declared floor |
| `home-en-1024x768.png` | 1024×768 | Three-column shell at the declared floor |
| `episodes-en-1280.png` | 1280×800 | Show episode list and selection |
| `discover-en-1280.png` | 1280×800 | Discover with directory search |
| `settings-general.png` | 660×640 | Settings → General |
| `settings-intelligence.png` | 660×640 | Settings → Intelligence, Keychain status |
| `settings-advanced.png` | 660×640 | Settings → Advanced |
| `settings-about.png` | 660×640 | Settings → About |

Regenerate from a built stage or packaged app:

```bash
bash scripts/e2e/snapshot-macos.sh
```

The harness renders each window offscreen; it does not use Screen Recording
or accessibility permissions. CI still owns the packaged native interaction
acceptance (`scripts/e2e/e2e-macos.sh`, which needs a trusted Accessibility
client) and the Windows/Linux legs.
