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
REQUIREMENTS_FILE="$ROOT_DIR/requirements.txt"

echo "== Apple Music Downloader backend dependency installer =="
echo "Project root: $ROOT_DIR"
echo

mkdir -p "$SITE_PACKAGES_DIR"

detect_python_abi_tag() {
  if [[ -d "$SITE_PACKAGES_DIR/PIL" ]]; then
    local tag
    tag="$(ls "$SITE_PACKAGES_DIR/PIL" 2>/dev/null | sed -n 's/.*cpython-\([0-9][0-9][0-9]\).*/\1/p' | head -n1 || true)"
    if [[ -n "$tag" ]]; then
      local major="${tag:0:1}"
      local minor="${tag:1:2}"
      echo "${major}.${minor}"
      return 0
    fi
  fi
  return 1
}

PYTHON_ABI="$(detect_python_abi_tag || true)"

if [[ -x "$BACKEND_DIR/python3" ]]; then
  PYTHON_BIN="$BACKEND_DIR/python3"
elif [[ -n "$PYTHON_ABI" && -x "/usr/local/bin/python$PYTHON_ABI" ]]; then
  PYTHON_BIN="/usr/local/bin/python$PYTHON_ABI"
elif [[ -n "$PYTHON_ABI" && -x "/opt/homebrew/bin/python$PYTHON_ABI" ]]; then
  PYTHON_BIN="/opt/homebrew/bin/python$PYTHON_ABI"
elif [[ -x "/usr/local/bin/python3" ]]; then
  PYTHON_BIN="/usr/local/bin/python3"
elif [[ -x "/opt/homebrew/bin/python3" ]]; then
  PYTHON_BIN="/opt/homebrew/bin/python3"
elif command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="$(command -v python3)"
else
  echo "ERROR: python3 not found."
  read -r -p "Press Enter to close..."
  exit 1
fi

echo "Using Python: $PYTHON_BIN"

if ! "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
  echo "pip is not available. Attempting to bootstrap pip..."
  "$PYTHON_BIN" -m ensurepip --upgrade || true
fi

if ! "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
  echo "ERROR: pip is still unavailable for $PYTHON_BIN."
  echo "Install pip first, then rerun this script."
  read -r -p "Press Enter to close..."
  exit 1
fi

echo
echo "Installing Python dependencies into:"
echo "  $SITE_PACKAGES_DIR"
echo
"$PYTHON_BIN" -m pip install --upgrade pip
if [[ -f "$REQUIREMENTS_FILE" ]]; then
  "$PYTHON_BIN" -m pip install --upgrade -r "$REQUIREMENTS_FILE" --target "$SITE_PACKAGES_DIR"
else
  "$PYTHON_BIN" -m pip install --upgrade \
    click colorama inquirerpy m3u8 mutagen pillow pywidevine pyyaml termcolor yt-dlp \
    --target "$SITE_PACKAGES_DIR"
fi

if [[ -d "$ROOT_DIR/gamdl" ]]; then
  echo
  echo "Copying local gamdl package into bundled site-packages..."
  mkdir -p "$SITE_PACKAGES_DIR/gamdl"
  rsync -a --delete "$ROOT_DIR/gamdl/" "$SITE_PACKAGES_DIR/gamdl/"
fi

echo
if ! command -v mp4decrypt >/dev/null 2>&1; then
  echo "Note: mp4decrypt not found in PATH."
  if command -v brew >/dev/null 2>&1; then
    read -r -p "Install mp4decrypt now via Homebrew (bento4)? [y/N] " install_mp4decrypt
    if [[ "${install_mp4decrypt:-N}" =~ ^[Yy]$ ]]; then
      brew install bento4
    fi
  else
    echo "Install Homebrew, then run: brew install bento4"
  fi
fi

echo
echo "Done. You can now relaunch the app."
read -r -p "Press Enter to close..."
