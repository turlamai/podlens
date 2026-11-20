#!/usr/bin/env python3
"""Generate packages/core/src/rpc.ts from rivet-schema.json (#63).

rivet-schema.json is the single source of the RPC contract. This generator
emits the web-side typed client: one interface per record (camelCase DTO
keys), one typed async function per RPC. The Racket adapter
(backend/wire-codec.rkt) reads the same file for the wire conversion, and
scripts/check-rpc-surface.py gates the glaze route surface against it —
regenerate with `pnpm gen:rpc` after any schema change and review the diff.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCHEMA = ROOT / "rivet-schema.json"
OUT = ROOT / "packages" / "core" / "src" / "rpc.ts"


def camel(name: str) -> str:
    parts = re.split(r"[-_]", name)
    return parts[0] + "".join(p[:1].upper() + p[1:] for p in parts[1:])


def ts_type(t: dict) -> str:
    kind = t["kind"]
    if kind == "scalar":
        return {
            "String": "string",
            "Int64": "number",
            "Bool": "boolean",
            "Void": "null",
            "Any": "unknown",
        }[t["name"]]
    if kind == "optional":
        return f"{ts_type(t['element'])} | null"
    if kind == "list":
        return f"Array<{ts_type(t['element'])}>"
    if kind == "record":
        return t["name"]
    raise SystemExit(f"unsupported type kind: {kind}")


def main() -> None:
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    lines = [
        "// Generated from rivet-schema.json by scripts/gen-rpc-types.py — do not edit.",
        "// Regenerate: pnpm gen:rpc (review the diff; the schema is the single source).",
        "",
        "import { apiPost } from './bridge';",
        "",
        "// ---- records (camelCase DTOs; field order on the wire is the schema's) ----",
        "",
    ]
    for rec in schema["records"]:
        lines.append(f"export interface {rec['name']} {{")
        for f in rec["fields"]:
            lines.append(f"  {camel(f['name'])}: {ts_type(f['type'])};")
        lines.append("}")
        lines.append("")

    lines.append("// ---- RPC surface ----")
    lines.append("")
    names = sorted(r["name"] for r in schema["rpcs"])
    lines.append("export const RPC_NAMES = [")
    for n in names:
        lines.append(f"  '{n}',")
    lines.append("] as const;")
    lines.append("")

    for rpc in sorted(schema["rpcs"], key=lambda r: r["name"]):
        name = rpc["name"]
        fn = camel(name)
        args = rpc["arguments"]
        params = []
        body = []
        for a in args:
            key = camel(a["name"])
            ty = ts_type(a["type"])
            optional = a["type"]["kind"] == "optional"
            # Optional DTO fields are nullable-but-required parameters:
            # TS forbids an optional parameter before a required one
            # (load_snapshot's list-id sits between view and show-completed),
            # and the wire codec treats null as the absent marker anyway.
            params.append(f"{key}: {ty}")
            body.append(f"{key}: {key} ?? null" if optional else key)
        result = ts_type(rpc["result"])
        ret = "Promise<void>" if rpc["result"] == {"kind": "scalar", "name": "Void"} else f"Promise<{result}>"
        lines.append(f"export function {fn}({', '.join(params)}): {ret} {{")
        if rpc["result"]["kind"] == "scalar" and rpc["result"]["name"] == "Void":
            lines.append(f"  return apiPost<null>('api/rpc/{name}', {{ {', '.join(body)} }}).then(() => undefined);")
        else:
            lines.append(f"  return apiPost<{result}>('api/rpc/{name}', {{ {', '.join(body)} }});")
        lines.append("}")
        lines.append("")

    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"generated {OUT.relative_to(ROOT)}: {len(schema['records'])} records, {len(names)} RPCs")


if __name__ == "__main__":
    sys.exit(main())