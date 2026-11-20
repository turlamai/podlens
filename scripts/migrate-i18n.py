#!/usr/bin/env python3
"""One-shot i18n migration for the glaze UI rewrite (#63, slice 2).

Folds the native host string tables into the Racket single source
(racket/core/i18n.rkt):

  * macos-host/Sources/RivetHost/Lang.swift  -> canonical camelCase keys
  * windows/I18n.h                           -> only concepts whose (zh, en)
    pair is not already present (dotted keys camelized)

The native tables stay in place until slice 4 retires the native hosts;
from this slice on the web UI table is GENERATED from i18n.rkt by
scripts/gen-web-i18n.py, so no fourth independent table appears.

Idempotent: rewrites only the marked section in i18n.rkt.
"""
import re
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SWIFT = ROOT / "macos-host" / "Sources" / "RivetHost" / "Lang.swift"
WIN = ROOT / "windows" / "I18n.h"
TARGET = ROOT / "racket" / "core" / "i18n.rkt"

BEGIN = "   ;; --- migrated host/UI labels (#63 slice 2; begin) ---"
END = "   ;; --- migrated host/UI labels (#63 slice 2; end) ---"


def swift_pairs():
    text = SWIFT.read_text(encoding="utf-8")
    out = []
    for m in re.finditer(r'"([A-Za-z0-9_]+)":\s*\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)', text):
        out.append((m.group(1), m.group(2), m.group(3)))
    return out


def win_pairs():
    text = WIN.read_text(encoding="utf-8")
    out = []
    for m in re.finditer(r'\{\s*"([A-Za-z0-9_.]+)"\s*,\s*L"((?:[^"\\]|\\.)*)"\s*,\s*L"((?:[^"\\]|\\.)*)"\s*\}', text, re.S):
        out.append((m.group(1), m.group(2), m.group(3)))
    return out


def camelize(key):
    parts = key.split(".")
    return parts[0] + "".join(p[:1].upper() + p[1:] for p in parts[1:])


def unescape(s):
    return s.replace('\\"', '"').replace("\\\\", "\\").replace("\\n", "\n")


def racket_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def main():
    swift = swift_pairs()
    win = win_pairs()
    seen_pairs = {(zh, en) for _, zh, en in swift}
    seen_keys = {k for k, _, _ in swift}
    merged = list(swift)
    skipped = []
    for key, zh, en in win:
        if (zh, en) in seen_pairs:
            skipped.append((key, "duplicate pair"))
            continue
        name = camelize(key)
        if name in seen_keys:
            skipped.append((key, "key collision"))
            continue
        seen_keys.add(name)
        seen_pairs.add((zh, en))
        merged.append((name, zh, en))
    lines = [BEGIN]
    for key, zh, en in merged:
        zh, en = unescape(zh), unescape(en)
        lines.append(f"   '{key} '({racket_string(zh)} . {racket_string(en)})")
    lines.append(END)
    block = "\n".join(lines)
    text = TARGET.read_text(encoding="utf-8")
    if BEGIN in text:
        text = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END), lambda _: block, text, flags=re.S)
    else:
        lines = text.split("\n")
        idx = next(i for i, ln in enumerate(lines) if ln.strip().startswith("'tray-quit"))
        assert lines[idx].rstrip().endswith(")))"), lines[idx]
        # strip the hasheq + define closers; keep the pair closer
        lines[idx] = lines[idx].rstrip()[:-2]
        lines[idx + 1:idx + 1] = block.split("\n") + ["))"]
        text = "\n".join(lines)
    TARGET.write_text(text, encoding="utf-8", newline="\n")
    print(f"swift keys: {len(swift)}; win keys: {len(win)}; merged: {len(merged)}; win skipped: {len(skipped)}")
    for key, why in skipped:
        print(f"  skip {key}: {why}")
    return 0


if __name__ == "__main__":
    sys.exit(main())