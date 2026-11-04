#!/usr/bin/env python3
"""Turn binary files in an assets directory into C headers you can #include.

For each file in the input directory, emits a header exposing the bytes as a
`const unsigned char <name>[]` array plus a `const unsigned int <name>_len`.
A roll-up `assets.h` #includes every generated header.

Usage:
    python tools/bin2header.py --src assets --out include/generated
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys


def sanitize(name: str) -> str:
    """Turn a filename into a valid C identifier."""
    ident = re.sub(r"[^0-9a-zA-Z]", "_", name)
    if ident and ident[0].isdigit():
        ident = "_" + ident
    return ident or "_blob"


def emit_header(data: bytes, symbol: str, guard: str) -> str:
    lines = [
        f"#ifndef {guard}",
        f"#define {guard}",
        "",
        f"const unsigned int {symbol}_len = {len(data)};",
        f"const unsigned char {symbol}[] = {{",
    ]
    for i in range(0, len(data), 12):
        chunk = data[i : i + 12]
        body = ", ".join(f"0x{b:02x}" for b in chunk)
        lines.append(f"  {body},")
    lines.append("};")
    lines.append("")
    lines.append(f"#endif  // {guard}")
    lines.append("")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--src", default="assets", help="Directory of binary assets")
    parser.add_argument(
        "--out",
        default="include/generated",
        help="Directory to write generated headers into",
    )
    args = parser.parse_args(argv)

    src = pathlib.Path(args.src)
    out = pathlib.Path(args.out)
    if not src.is_dir():
        print(f"error: source directory not found: {src}", file=sys.stderr)
        return 1

    out.mkdir(parents=True, exist_ok=True)

    files = sorted(p for p in src.iterdir() if p.is_file() and not p.name.startswith("."))
    if not files:
        print(f"no asset files found in {src}/ — nothing to generate", file=sys.stderr)

    generated: list[str] = []
    for path in files:
        symbol = sanitize(path.name)
        guard = f"ASSET_{symbol.upper()}_H"
        header_name = f"{symbol}.h"
        data = path.read_bytes()
        (out / header_name).write_text(emit_header(data, symbol, guard))
        generated.append(header_name)
        print(f"generated {out / header_name}  ({len(data)} bytes)")

    rollup = [
        "#ifndef ASSETS_H",
        "#define ASSETS_H",
        "",
        *[f'#include "{name}"' for name in generated],
        "",
        "#endif  // ASSETS_H",
        "",
    ]
    (out / "assets.h").write_text("\n".join(rollup))
    print(f"generated {out / 'assets.h'}  ({len(generated)} asset(s))")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
