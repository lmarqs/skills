"""PlatformIO pre-build hook: regenerate asset headers before compiling.

PlatformIO runs every `extra_scripts` file with a SCons-style `env` available in
the global namespace. We use it to locate the project root and invoke the
standalone `tools/bin2header.py` converter so a fresh `pio run` always picks up
the latest contents of `assets/`.

The same converter can be run by hand (or via `mise run gen-headers`); this hook
just wires it into the PlatformIO build graph.
"""

import sys
from pathlib import Path

# PlatformIO injects `Import`/`env` into this script's namespace.
Import("env")  # type: ignore[name-defined]  # noqa: F821

PROJECT_DIR = Path(env["PROJECT_DIR"])  # type: ignore[name-defined]  # noqa: F821
ASSETS_DIR = PROJECT_DIR / "assets"
OUT_DIR = PROJECT_DIR / "include" / "generated"

# Make tools/ importable so we reuse the exact same generation logic.
sys.path.insert(0, str(PROJECT_DIR / "tools"))

import bin2header  # noqa: E402

print("generate_headers: regenerating asset headers...")
rc = bin2header.generate(ASSETS_DIR, OUT_DIR)
if rc != 0:
    raise SystemExit(rc)
