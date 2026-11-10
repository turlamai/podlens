# Third-party notices

PodLens builds on the components below. Each entry names where the
component enters the shipped artifacts and the license it is distributed
under; consult the upstream license files for full terms. The Rivet
release toolchain generates a per-artifact notices file for the Linux
legs and ships it as `podlens-<version>-linux-<arch>-THIRD_PARTY_NOTICES.txt`
attached to every release (it covers the framework components); this
document is the root overview for the repository and the authoritative
notices record across all platforms. Rivet is a first-party TurLamAI
project (MIT) consumed as a pinned package — not third-party code — so
it is not listed here.

## Racket CS runtime

Every platform host embeds the statically linked Racket CS runtime
([racket/racket](https://github.com/racket/racket), 9.x). Racket is
distributed under the MIT license and the Apache License 2.0, at your
option; the Racket CS runtime system additionally embeds Chez Scheme,
distributed under the Apache License 2.0 (per Racket's `LICENSE.txt`).

## crypto-lib

Update-trust work — Ed25519 signature verification and SHA-256 artifact
checks through Rivet's distribution layer — runs through the Racket
`crypto` package's libcrypto factory
([racket/crypto](https://github.com/racket/crypto)), distributed under
the Apache License 2.0. It links against the platform's OpenSSL
(libcrypto), which ships with the operating system.

## GTK 4 and GLib

The Linux host is a GTK 4 application. GTK and GLib are licensed under
the GNU Lesser General Public License, version 2.1 or later. Depending
on the Linux install shape the libraries come from two places:

- deb / rpm / tar.gz / zip: GTK 4 and its system libraries are supplied
  by the distribution (or by you, for the tarball).
- `.AppImage` artifacts: the AppImage carries its own GTK4 dependency
  closure, bundled by the Rivet release toolchain.

## GStreamer core, plugins and gst-libav (Linux)

Local playback uses GStreamer 1.0: the core (`gstreamer-1.0`) and
plugins-base are linked at build time
(`linux/CMakeLists.txt`), licensed LGPL-2.1-or-later. The deb package
additionally ships a side-payload with the GStreamer plugin closure —
gst-plugins-base, gst-plugins-good and gst-libav — so m4a/mp3 play on
stock Debian/Ubuntu systems; the plugin packages are LGPL-2.1-or-later,
and gst-libav wraps FFmpeg's libav libraries (LGPL-2.1-or-later; FFmpeg
carries its own optional-component licensing — see upstream). The
AppImage bundles the playback closure the same way; the per-release
generated notices file does not list these plugin packages, so this
section and the upstream license files are the reference for them.

## Microsoft Windows App SDK

The Windows host is a WinUI 3 application built on the Microsoft
Windows App SDK, distributed by Microsoft under the MIT license.

## Apple system frameworks

The macOS host is a SwiftUI application built against Apple's system
frameworks (SwiftUI, AVFoundation and friends), provided under Apple's
SDK license terms and shipped by the operating system itself.

## AppImageKit runtime (`.AppImage` artifacts)

`.AppImage` release artifacts contain the type-2 AppImage runtime from
[AppImage/AppImageKit](https://github.com/AppImage/AppImageKit),
licensed MIT. The build tool is the official `appimagetool` 1.9.0
release, SHA-256-verified in the release workflow
(`RIVET_APPIMAGETOOL_PATH`). AppImageKit's license does not apply to
the contents of the AppImage: those are PodLens's AGPL-3.0 payload plus
the entries above.
