#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="$(basename "$SCRIPT_DIR")"

if [[ "$SCRIPT_NAME" == "PythonBackend" ]]; then
  BACKEND_DIR="$SCRIPT_DIR"
  ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
else
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
  BACKEND_DIR="$ROOT_DIR/Resources/PythonBackend"
fi

SITE_PACKAGES_DIR="$BACKEND_DIR/site-packages"
PYTHON_LINK="$BACKEND_DIR/python3"

echo "== Apple Music Downloader Python version matcher =="
echo "Project root: $ROOT_DIR"
echo "Backend dir : $BACKEND_DIR"
echo

detect_python_abi_tag() {
  if [[ -d "$SITE_PACKAGES_DIR" ]]; then
    local tag
    tag="$(
      find "$SITE_PACKAGES_DIR" -type f -name '*.so' 2>/dev/null \
      | sed -n 's/.*cpython-\([0-9][0-9][0-9]\).*/\1/p' \
      | head -n1 || true
    )"
    if [[ -n "$tag" ]]; then
      local major="${tag:0:1}"
      local minor="${tag:1:2}"
      echo "${major}.${minor}"
      return 0
    fi
  fi
  return 1
}

select_python_binary() {
  local abi="$1"
  local candidates=()

  if [[ -n "$abi" ]]; then
    candidates+=("/usr/local/bin/python$abi")
    candidates+=("/opt/homebrew/bin/python$abi")
  fi

  candidates+=("/usr/local/bin/python3")
  candidates+=("/opt/homebrew/bin/python3")
  candidates+=("/usr/bin/python3")

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  if command -v python3 >/dev/null 2>&1; then
    command -v python3
    return 0
  fi

  return 1
}

ABI_TARGET="$(detect_python_abi_tag || true)"
PYTHON_BIN="$(select_python_binary "$ABI_TARGET" || true)"

if [[ -z "${PYTHON_BIN:-}" ]]; then
  echo "ERROR: Could not find a usable python3 interpreter."
  read -r -p "Press Enter to close..."
  exit 1
fi

mkdir -p "$BACKEND_DIR"
ln -sfn "$PYTHON_BIN" "$PYTHON_LINK"

echo "Selected interpreter: $PYTHON_BIN"
if [[ -n "$ABI_TARGET" ]]; then
  echo "Detected package ABI : cpython-${ABI_TARGET/./}"
else
  echo "Detected package ABI : none (using best available python3)"
fi
echo "Updated symlink     : $PYTHON_LINK -> $PYTHON_BIN"
echo
"$PYTHON_LINK" --version

echo
echo "Done. You can now run 'Install Backend Dependencies'."
read -r -p "Press Enter to close..."
