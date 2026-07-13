#!/usr/bin/env bash

set -uo pipefail

if [ -z "${REPO_ROOT:-}" ]; then
  printf '[validate-tooling-tmp] REPO_ROOT is not set.\n' >&2
  exit 2
fi

PHYSICAL_ROOT="$(cd "$REPO_ROOT" 2>/dev/null && pwd -P)" || {
  printf '[validate-tooling-tmp] Cannot resolve physical REPO_ROOT.\n' >&2
  exit 2
}

CLAUDE_DIR="$REPO_ROOT/.claude"
TMP_DIR="$CLAUDE_DIR/tmp"

if [ -L "$CLAUDE_DIR" ] || [ -L "$TMP_DIR" ]; then
  printf '[validate-tooling-tmp] Unsafe tooling temp symlink.\n' >&2
  exit 2
fi

if [ -e "$CLAUDE_DIR" ] && [ ! -d "$CLAUDE_DIR" ]; then
  printf '[validate-tooling-tmp] .claude is not a directory.\n' >&2
  exit 2
fi

if [ -e "$TMP_DIR" ] && [ ! -d "$TMP_DIR" ]; then
  printf '[validate-tooling-tmp] .claude/tmp is not a directory.\n' >&2
  exit 2
fi

umask 077
mkdir -p -- "$TMP_DIR" || exit 2

PHYSICAL_TMP="$(cd "$TMP_DIR" 2>/dev/null && pwd -P)" || {
  printf '[validate-tooling-tmp] Cannot resolve physical tmp dir.\n' >&2
  exit 2
}

if [ "$PHYSICAL_TMP" != "$PHYSICAL_ROOT/.claude/tmp" ]; then
  printf '[validate-tooling-tmp] Tooling temp directory resolves outside repository.\n' >&2
  exit 2
fi

chmod 700 "$TMP_DIR" 2>/dev/null || true
