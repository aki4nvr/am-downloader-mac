#!/usr/bin/env python3
"""Launcher used by the Swift app to execute gamdl CLI."""

import sys
from pathlib import Path


def _prepend_python_paths() -> None:
    root = Path(__file__).resolve().parent
    candidates: list[Path] = []

    for ancestor in [root, *root.parents]:
        candidates.append(ancestor / "site-packages")
        candidates.append(ancestor)

    cwd = Path.cwd().resolve()
    for ancestor in [cwd, *cwd.parents]:
        candidates.append(ancestor / "site-packages")
        candidates.append(ancestor)

    inserted: set[str] = set()
    for candidate in candidates:
        if not candidate.exists():
            continue

        resolved = str(candidate.resolve())
        if resolved in inserted:
            continue

        has_gamdl = (candidate / "gamdl").exists()
        if has_gamdl or candidate.name == "site-packages":
            sys.path.insert(0, resolved)
            inserted.add(resolved)


def main() -> int:
    _prepend_python_paths()
    try:
        from gamdl.cli import main as gamdl_main
    except Exception as exc:
        print(f"ERROR: unable to import gamdl backend: {exc}")
        return 2

    try:
        gamdl_main(sys.argv[1:], standalone_mode=False)
        return 0
    except SystemExit as e:
        return int(e.code) if isinstance(e.code, int) else 1
    except Exception as exc:
        print(f"ERROR: backend execution failed: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
