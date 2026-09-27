#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/versions.env"

CACHE_ROOT="${RMMZ_TEMPLATE_CACHE:-$HOME/Library/Caches/rmmz-reactor-template}"

ARCHIVE_NAME="rpgreactor-${REACTOR_COMMIT}.tar.gz"
ARCHIVE="$CACHE_ROOT/$ARCHIVE_NAME"

EXTRACT_ROOT="$CACHE_ROOT/rpgreactor-${REACTOR_COMMIT}"
SOURCE_ROOT="$EXTRACT_ROOT/source"

DOWNLOAD_URL="https://codeload.github.com/${REACTOR_REPO}/tar.gz/${REACTOR_COMMIT}"

REACTOR_MAIN="$ROOT/js/reactor_main.js"
REACTOR_MANIFEST="$ROOT/js/reactor_plugins.js"
MZ_MANIFEST="$ROOT/js/plugins.js"
INDEX_HTML="$ROOT/index.html"

MODE="install"
FORCE=0

usage() {
  cat <<USAGE
Usage:
  ./scripts/setup-reactor.sh --check
  ./scripts/setup-reactor.sh --install
  ./scripts/setup-reactor.sh --install --force

Environment:
  RMMZ_TEMPLATE_CACHE=/path/to/cache
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      MODE="check"
      ;;
    --install)
      MODE="install"
      ;;
    --force)
      FORCE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac

  shift
done

normalize_text() {
  tr -d '\r' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

runtime_version_for_file() {
  local file="$1"

  [[ -f "$file" ]] || {
    printf 'missing'
    return
  }

  grep -m1 'RPG Reactor runtime version:' "$file" \
    | sed -E 's/.*version:[[:space:]]*([^[:space:]*]+).*/\1/' \
    | normalize_text \
    || true
}

runtime_revision_for_file() {
  local file="$1"

  [[ -f "$file" ]] || {
    printf 'missing'
    return
  }

  grep -m1 'RPG Reactor runtime revision:' "$file" \
    | sed -E 's/.*revision:[[:space:]]*([^[:space:]*]+).*/\1/' \
    | normalize_text \
    || true
}

current_runtime_version() {
  runtime_version_for_file "$REACTOR_MAIN"
}

current_runtime_revision() {
  runtime_revision_for_file "$REACTOR_MAIN"
}

manifest_bridge_ok() {
  [[ -L "$REACTOR_MANIFEST" ]] || return 1
  [[ "$(readlink "$REACTOR_MANIFEST")" == "plugins.js" ]] || return 1
}

index_uses_reactor() {
  [[ -f "$INDEX_HTML" ]] || return 1
  grep -q 'js/reactor_main\.js' "$INDEX_HTML"
}

is_expected_install() {
  [[ -f "$REACTOR_MAIN" ]] || return 1

  [[ "$(current_runtime_version)" == "$REACTOR_VERSION" ]] || return 1
  [[ "$(current_runtime_revision)" == "$REACTOR_RUNTIME_REVISION" ]] || return 1

  index_uses_reactor || return 1
  manifest_bridge_ok || return 1

  [[ -f "$ROOT/js/libs/pixi.js" ]] || return 1
  [[ -f "$ROOT/js/libs/pixi_compat.js" ]] || return 1

  return 0
}

print_current_state() {
  echo "Runtime version:  $(current_runtime_version)"
  echo "Runtime revision: $(current_runtime_revision)"

  if index_uses_reactor; then
    echo "index.html:       Reactor"
  else
    echo "index.html:       missing / not Reactor"
  fi

  if manifest_bridge_ok; then
    echo "Plugin manifest:  reactor_plugins.js -> plugins.js"
  elif [[ -e "$REACTOR_MANIFEST" || -L "$REACTOR_MANIFEST" ]]; then
    echo "Plugin manifest:  exists, but bridge is not correct"
  else
    echo "Plugin manifest:  missing"
  fi
}

download_archive() {
  mkdir -p "$CACHE_ROOT"

  if command -v aria2c >/dev/null 2>&1; then
    echo "Downloader: aria2c"
    echo "Connections: 16"
    echo
    echo "Downloading:"
    echo "  $DOWNLOAD_URL"
    echo

    aria2c \
      --continue=true \
      --allow-overwrite=true \
      --auto-file-renaming=false \
      --file-allocation=none \
      --max-connection-per-server=16 \
      --split=16 \
      --min-split-size=1M \
      --dir="$CACHE_ROOT" \
      --out="$ARCHIVE_NAME" \
      "$DOWNLOAD_URL"
  else
    echo "Downloader: curl (aria2c not found)"
    echo
    echo "Downloading:"
    echo "  $DOWNLOAD_URL"
    echo

    curl \
      --fail \
      --location \
      --retry 3 \
      --retry-delay 2 \
      --continue-at - \
      "$DOWNLOAD_URL" \
      --output "$ARCHIVE"
  fi
}

archive_is_valid() {
  [[ -f "$ARCHIVE" ]] || return 1
  tar -tzf "$ARCHIVE" >/dev/null 2>&1
}

write_reactor_index() {
  local title
  title="$(basename "$ROOT")"

  cat > "$INDEX_HTML" <<HTML
<!DOCTYPE html>
<html>
    <head>
        <meta charset="UTF-8">
        <meta name="apple-mobile-web-app-capable" content="yes">
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
        <meta name="viewport" content="user-scalable=no">
        <link rel="icon" href="icon/icon.png" type="image/png">
        <link rel="apple-touch-icon" href="icon/icon.png">
        <title>${title}</title>
    </head>
    <body style="background-color: black">
        <script type="text/javascript" src="js/reactor_main.js"></script>
    </body>
</html>
HTML
}

echo
echo "RPG Reactor runtime setup"
echo "Project:          $ROOT"
echo "Repository:       $REACTOR_REPO"
echo "Pinned version:   $REACTOR_VERSION"
echo "Pinned commit:    $REACTOR_COMMIT"
echo "Runtime revision: $REACTOR_RUNTIME_REVISION"
echo

# ------------------------------------------------------------
# Check mode
# ------------------------------------------------------------

if [[ "$MODE" == "check" ]]; then
  print_current_state
  echo

  if is_expected_install; then
    echo "PASS: Reactor runtime matches the pinned template runtime."
    exit 0
  fi

  echo "FAIL: Reactor runtime does not match the pinned template runtime."
  exit 1
fi

# ------------------------------------------------------------
# Idempotent install
# ------------------------------------------------------------

if is_expected_install && [[ "$FORCE" -eq 0 ]]; then
  print_current_state
  echo
  echo "Already installed. Nothing to do."
  exit 0
fi

for command in tar grep sed; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $command" >&2
    exit 1
  fi
done

if ! command -v aria2c >/dev/null 2>&1 \
   && ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: Neither aria2c nor curl is installed." >&2
  exit 1
fi

if [[ ! -f "$ROOT/game.rmmzproject" ]]; then
  echo "ERROR: game.rmmzproject is missing." >&2
  exit 1
fi

if [[ ! -f "$MZ_MANIFEST" ]]; then
  echo "ERROR: js/plugins.js is missing." >&2
  exit 1
fi

mkdir -p "$CACHE_ROOT"

# ------------------------------------------------------------
# Download pinned Reactor source snapshot
# ------------------------------------------------------------

if [[ -f "$ARCHIVE" ]]; then
  echo "Found cached Reactor archive:"
  echo "  $ARCHIVE"

  if archive_is_valid; then
    echo "Cached archive is valid."
  else
    echo "Cached archive is invalid; removing it."
    rm -f "$ARCHIVE"
    download_archive
  fi
else
  download_archive
fi

echo
echo "Validating Reactor archive..."

if ! archive_is_valid; then
  echo "ERROR: Reactor archive failed validation." >&2
  exit 1
fi

echo "Archive OK."

# ------------------------------------------------------------
# Extract
# ------------------------------------------------------------

echo
echo "Preparing Reactor source..."

rm -rf "$EXTRACT_ROOT"
mkdir -p "$SOURCE_ROOT"

tar \
  -xzf "$ARCHIVE" \
  -C "$SOURCE_ROOT" \
  --strip-components=1

RUNTIME_SOURCE="$SOURCE_ROOT/runtime"
SOURCE_MAIN="$RUNTIME_SOURCE/reactor_main.js"

if [[ ! -f "$SOURCE_MAIN" ]]; then
  echo "ERROR: Downloaded source does not contain runtime/reactor_main.js." >&2
  exit 1
fi

SOURCE_VERSION="$(runtime_version_for_file "$SOURCE_MAIN")"
SOURCE_REVISION="$(runtime_revision_for_file "$SOURCE_MAIN")"

if [[ "$SOURCE_VERSION" != "$REACTOR_VERSION" ]]; then
  echo "ERROR: Downloaded Reactor version '$SOURCE_VERSION'." >&2
  echo "Expected '$REACTOR_VERSION'." >&2
  exit 1
fi

if [[ "$SOURCE_REVISION" != "$REACTOR_RUNTIME_REVISION" ]]; then
  echo "ERROR: Downloaded Reactor revision '$SOURCE_REVISION'." >&2
  echo "Expected '$REACTOR_RUNTIME_REVISION'." >&2
  exit 1
fi

if [[ ! -f "$RUNTIME_SOURCE/libs/pixi.js" ]]; then
  echo "ERROR: Downloaded Reactor runtime is missing libs/pixi.js." >&2
  exit 1
fi

echo "Downloaded runtime verified:"
echo "  version:  $SOURCE_VERSION"
echo "  revision: $SOURCE_REVISION"

# ------------------------------------------------------------
# Reject unexpected stock corescript
#
# This bootstrap is designed for this GitHub template or an
# already-Reactor-hydrated copy. A stock MZ project should be
# converted deliberately rather than silently deleting its runtime.
# ------------------------------------------------------------

if [[ -f "$ROOT/js/main.js" ]] \
   || find "$ROOT/js" -maxdepth 1 -type f -name 'rmmz_*.js' | grep -q .; then
  echo
  echo "ERROR: Stock RPG Maker MZ corescript detected." >&2
  echo "This template bootstrap will not silently delete it." >&2
  echo >&2
  echo "Start from the GitHub template, or convert that project with" >&2
  echo "RPG Reactor's 'Install Reactor Runtime...' first." >&2
  exit 1
fi

# ------------------------------------------------------------
# Install / refresh vendor runtime
# ------------------------------------------------------------

echo
echo "Installing Reactor runtime..."

mkdir -p "$ROOT/js"

rm -rf "$ROOT/js/libs"

find "$ROOT/js" \
  -maxdepth 1 \
  -type f \
  -name 'reactor_*.js' \
  ! -name 'reactor_plugins.js' \
  -delete

cp -R "$RUNTIME_SOURCE/libs" "$ROOT/js/libs"

for source_file in "$RUNTIME_SOURCE"/reactor_*.js; do
  file_name="$(basename "$source_file")"

  if [[ "$file_name" == "reactor_plugins.js" ]]; then
    continue
  fi

  cp "$source_file" "$ROOT/js/$file_name"
done

# ------------------------------------------------------------
# MZ Plugin Manager -> Reactor runtime manifest bridge
# ------------------------------------------------------------

rm -f "$REACTOR_MANIFEST"
ln -s "plugins.js" "$REACTOR_MANIFEST"

# ------------------------------------------------------------
# Reactor entry page
# ------------------------------------------------------------

write_reactor_index

# ------------------------------------------------------------
# Verify
# ------------------------------------------------------------

echo
echo "Verifying installation..."

if ! is_expected_install; then
  echo "ERROR: Reactor runtime installation verification failed." >&2
  print_current_state
  exit 1
fi

print_current_state

echo
echo "PASS: RPG Reactor $REACTOR_VERSION is ready."
