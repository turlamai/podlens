#!/usr/bin/env python3
"""Generate packages/core/src/i18n.ts from racket/core/i18n.rkt (#63).

The Racket table is the single source; this script only projects it into
TypeScript. Native printf-style placeholders (%d / %@ / %s / %%) are
normalized to the engine's {0} {1} … form so the web `t()` and Racket `tr`
share one placeholder convention.

Regenerate: pnpm gen:i18n (review the diff; do not edit the output).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "racket" / "core" / "i18n.rkt"
OUT = ROOT / "packages" / "core" / "src" / "i18n.ts"

ROW = re.compile(r"'([A-Za-z0-9_-]+) '\(\"((?:[^\"\\]|\\.)*)\" \. \"((?:[^\"\\]|\\.)*)\"\)")


def unescape(s):
    return s.replace("\\n", "\n").replace('\\"', '"').replace("\\\\", "\\")


def normalize(s):
    s = s.replace("%%", "\x00")
    n = 0

    def sub(_m):
        nonlocal n
        tok = "{" + str(n) + "}"
        n += 1
        return tok

    s = re.sub(r"%[d@su]", sub, s)
    return s.replace("\x00", "%")


def ts_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def main():
    rows = ROW.findall(SRC.read_text(encoding="utf-8"))
    if not rows:
        print("no i18n rows parsed", file=sys.stderr)
        return 1
    lines = [
        "// Generated from racket/core/i18n.rkt by scripts/gen-web-i18n.py — do not edit.",
        "// Regenerate: pnpm gen:i18n (the Racket table is the single source, #63).",
        "",
        "export type Lang = 'zh' | 'en';",
        "",
        "export const STRINGS: Record<string, readonly [string, string]> = {",
    ]
    for key, zh, en in rows:
        zh, en = normalize(unescape(zh)), normalize(unescape(en))
        lines.append(f"  {key}: [{ts_string(zh)}, {ts_string(en)}],")
    lines += [
        "};",
        "",
        "/** Look up a label; {0} {1} … placeholders are filled positionally. */",
        "export function t(lang: Lang, key: string, ...args: Array<string | number>): string {",
        "  const pair = STRINGS[key] ?? [key, key];",
        "  let s = lang === 'en' ? pair[1] : pair[0];",
        "  args.forEach((a, i) => {",
        "    s = s.split('{' + i + '}').join(String(a));",
        "  });",
        "  return s;",
        "}",
        "",
    ]
    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"generated {OUT.relative_to(ROOT)}: {len(rows)} labels")
    return 0


if __name__ == "__main__":
    sys.exit(main())