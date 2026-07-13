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
  exit 1
fi

# Only process .php files
case "$FILE_PATH" in
  *.php) ;;
  *) exit 0 ;;
esac

# Reject path traversal attempts
case "/$FILE_PATH/" in
  */../* | */./*)
    printf '[record-touched-file] ⚠️ Path traversal detected, rejected.\n' >&2
    exit 1
    ;;
esac

# Convert to absolute path
case "$FILE_PATH" in
  /*) ABS="$FILE_PATH" ;;
  *)  ABS="$REPO_ROOT/$FILE_PATH" ;;
esac

# Simple resolution by stripping REPO_ROOT prefix
# Note: we assume REPO_ROOT is an absolute path without trailing slash
PREFIX="${REPO_ROOT%/}/"
case "$ABS" in
  "$PREFIX"*) REL="${ABS#$PREFIX}" ;;
  *) 
    printf '[record-touched-file] ⚠️ File %s is outside repository, rejected.\n' "$FILE_PATH" >&2
    exit 1
    ;;
esac

# Must be under source/
case "$REL" in
  source/*) ;;
  *) exit 0 ;; # Silently ignore files outside source/ (e.g. scripts)
esac

MANIFEST_DIR="$REPO_ROOT/.claude/tmp"
MANIFEST_FILE="$MANIFEST_DIR/touched-files"

mkdir -p "$MANIFEST_DIR" 2>/dev/null || {
  printf '[record-touched-file] ⚠️ Cannot create %s\n' "$MANIFEST_DIR" >&2
  exit 1
}

# Append directly; we deduplicate when reading
if ! printf '%s\n' "$REL" >> "$MANIFEST_FILE"; then
  printf '[record-touched-file] ⚠️ Failed to write to manifest.\n' >&2
  exit 1
fi

exit 0
