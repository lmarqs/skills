#!/usr/bin/env python3
"""Statically check that a core/domain package is pure.

"Pure" means two things, both checked by *parsing* the source (never importing it), so a
violation is caught even when the offending import is never executed:

  1. the core imports nothing from the project's outer layers (infra/run/adapters/...), and
  2. the core imports no I/O-capable module (subprocess, os, sockets, http, db drivers, ...).

Exit status is non-zero if any violation is found, so it drops straight into a test suite or CI.

Usage:
    python check_core_purity.py path/to/core --layer infra --layer run
    python check_core_purity.py src/domain -l infrastructure -l adapters --io-module requests --io-module boto3
    python check_core_purity.py app --layer infra --layer run --allow-io   # direction only
"""

from __future__ import annotations

import argparse
import ast
import sys
from pathlib import Path

# Conservative default set of I/O / outside-world stdlib modules a pure core should not import.
# Extend with --io-module for vendor SDKs and third-party clients (requests, boto3, psycopg2, ...).
DEFAULT_IO_MODULES = {
    "subprocess",
    "os",
    "pathlib",
    "shutil",
    "socket",
    "ssl",
    "urllib",
    "http",
    "ftplib",
    "smtplib",
    "sqlite3",
}


def imported_modules(source: str) -> set[str]:
    """Every module name reached by an ``import`` or ``from ... import`` in the source."""
    names: set[str] = set()
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, ast.Import):
            names.update(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            names.add(node.module)
    return names


def _top(name: str) -> str:
    return name.split(".", 1)[0]


def find_offenders(core: Path, forbidden: set[str], io_modules: set[str]) -> dict[str, set[str]]:
    offenders: dict[str, set[str]] = {}
    for path in sorted(core.rglob("*.py")):
        imported = imported_modules(path.read_text(encoding="utf-8"))
        bad = {name for name in imported if _top(name) in forbidden or _top(name) in io_modules}
        if bad:
            offenders[str(path)] = bad
    return offenders


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Check a core/domain package is pure (inward-only imports, no I/O)."
    )
    parser.add_argument("core", type=Path, help="path to the core/domain package directory")
    parser.add_argument(
        "-l",
        "--layer",
        action="append",
        default=[],
        metavar="NAME",
        help="an outer layer the core must not import (repeatable), e.g. infra run adapters",
    )
    parser.add_argument(
        "--io-module",
        action="append",
        default=[],
        metavar="NAME",
        help="extra module to forbid in the core (repeatable), e.g. requests boto3 psycopg2",
    )
    parser.add_argument(
        "--allow-io",
        action="store_true",
        help="skip the no-I/O check; enforce only the inward dependency direction",
    )
    args = parser.parse_args(argv)

    if not args.core.is_dir():
        print(f"error: {args.core} is not a directory", file=sys.stderr)
        return 2

    forbidden = set(args.layer)
    io_modules = set() if args.allow_io else (DEFAULT_IO_MODULES | set(args.io_module))

    offenders = find_offenders(args.core, forbidden, io_modules)

    if offenders:
        print("Core purity violated — the core must import nothing inward-breaking and no I/O:\n")
        for file, names in offenders.items():
            print(f"  {file}")
            for name in sorted(names):
                print(f"      imports {name}")
        print(f"\n{len(offenders)} file(s) breach core purity.", file=sys.stderr)
        return 1

    suffix = "" if args.allow_io else ", no I/O modules"
    print(f"OK — {args.core} is pure (no {sorted(forbidden)} imports{suffix}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
