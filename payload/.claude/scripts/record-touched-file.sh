#!/usr/bin/env bash
# Helper script to safely record touched files for verification hooks
# Usage: ./record-touched-file.sh <repo-root> <file-path>

set -uo pipefail

if [ "$#" -lt 2 ]; then
  printf '[record-touched-file] Missing arguments.\n' >&2
  exit 1
fi

REPO_ROOT="$1"
FILE_PATH="$2"

[ -z "$FILE_PATH" ] && exit 0

# Reject control characters including newline
if printf '%s' "$FILE_PATH" | grep -q '[[:cntrl:]]'; then
  printf '[record-touched-file] ⚠️ Path contains control characters, rejected.\n' >&2
  exit 2
fi

# Only process .php files
case "$FILE_PATH" in
  *.php) ;;
  *) exit 10 ;;
esac

# Reject path traversal attempts
case "/$FILE_PATH/" in
  */../* | */./*)
    printf '[record-touched-file] ⚠️ Path traversal detected, rejected.\n' >&2
    exit 2
    ;;
esac

# Convert to absolute path
case "$FILE_PATH" in
  /*) ABS="$FILE_PATH" ;;
  *)  ABS="$REPO_ROOT/$FILE_PATH" ;;
esac

PHYSICAL_ROOT="$(cd "$REPO_ROOT" 2>/dev/null && pwd -P)" || {
  printf '[record-touched-file] ⚠️ Cannot resolve repository root.\n' >&2
  exit 2
}

PARENT="$(dirname "$ABS")"
PHYSICAL_PARENT="$(cd "$PARENT" 2>/dev/null && pwd -P)" || {
  printf '[record-touched-file] ⚠️ Parent directory does not exist or cannot be resolved: %s\n' "$FILE_PATH" >&2
  exit 2
}

case "$PHYSICAL_PARENT/" in
  "$PHYSICAL_ROOT/"*) ;;
  *)
    printf '[record-touched-file] ⚠️ Touched file resolves outside repository: %s\n' "$FILE_PATH" >&2
    exit 2
    ;;
esac

if [ -L "$ABS" ]; then
  printf '[record-touched-file] ⚠️ Touched file must not be a symlink: %s\n' "$FILE_PATH" >&2
  exit 2
fi

# Simple resolution by stripping REPO_ROOT prefix
PREFIX="${REPO_ROOT%/}/"
case "$ABS" in
  "$PREFIX"*) REL="${ABS#$PREFIX}" ;;
  *)
    printf '[record-touched-file] ⚠️ File %s is outside repository, rejected.\n' "$FILE_PATH" >&2
    exit 2
    ;;
esac

# Must be under source/
case "$REL" in
  source/*) ;;
  *) exit 10 ;; # Silently ignore files outside source/ (e.g. scripts)
esac

. "$REPO_ROOT/.claude/scripts/validate-tooling-tmp.sh" || exit 2

MANIFEST_DIR="$REPO_ROOT/.claude/tmp"
MANIFEST_FILE="$MANIFEST_DIR/touched-files"

if [ -L "$MANIFEST_FILE" ]; then
    printf '[record-touched-file] Manifest must not be a symlink.\n' >&2
    exit 2
fi

if [ -e "$MANIFEST_FILE" ] && [ ! -f "$MANIFEST_FILE" ]; then
    printf '[record-touched-file] Manifest is not a regular file.\n' >&2
    exit 2
fi

# Append directly; we deduplicate when reading
if ! printf '%s\n' "$REL" >> "$MANIFEST_FILE"; then
  printf '[record-touched-file] ⚠️ Failed to write to manifest.\n' >&2
  exit 2
fi

chmod 600 "$MANIFEST_FILE" 2>/dev/null || true

touch "$MANIFEST_DIR/session-had-edits" 2>/dev/null || true

exit 0
