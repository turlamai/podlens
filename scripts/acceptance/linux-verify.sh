#!/usr/bin/env bash
# Real-window verify on a headless Linux runner.
#
# WebKitGTK's MediaSession->MPRIS bridge lives in the sandboxed web process,
# which reaches the session bus through xdg-dbus-proxy — and the sandbox
# only exposes /run, not /tmp (WebKit bug 246159). dbus-run-session puts its
# socket in /tmp, so the bridge can never own org.mpris.MediaPlayer2.* there
# and the slice-5 OS Now Playing probe finds nothing. Run the session bus on
# a /run/user socket instead; the app, the bridge and the probe share it.
set -euo pipefail
# Surface WebKit's MediaSession/MPRIS log channels on headless runners so a
# silent registration gate (eligibility / empty title) is diagnosable.
export G_MESSAGES_DEBUG="${G_MESSAGES_DEBUG:-all}"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR"
BUS_INFO="$(mktemp)"
dbus-daemon --session --fork \
  --address="unix:path=$XDG_RUNTIME_DIR/podlens-acceptance-bus" \
  --print-address=1 --print-pid=1 > "$BUS_INFO"
DBUS_SESSION_BUS_ADDRESS="$(sed -n 1p "$BUS_INFO")"
export DBUS_SESSION_BUS_ADDRESS
BUS_PID="$(sed -n 2p "$BUS_INFO")"
status=0
xvfb-run -a racket verify.rkt || status=$?
kill "$BUS_PID" 2>/dev/null || true
rm -f "$BUS_INFO" "$XDG_RUNTIME_DIR/podlens-acceptance-bus"
exit "$status"