#!/usr/bin/env bash
# Safe Docker entrypoint for Makefile.ai.
# User-controlled values are read from environment variables, validated, then
# passed to docker compose as argv entries. Do not concatenate them into shell.
set -euo pipefail

command_name="${1:-}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

die() {
  echo "❌ $*" >&2
  exit 2
}

container_exec() {
  (
    cd "$repo_root/docker/local"
    exec docker compose exec -T hrm-api "$@"
  )
}

runner_local_enabled() {
  local conf_file="$repo_root/.claude/runner.local"
  [ -f "$conf_file" ] || return 1
  ensure_not_symlink "$conf_file"

  # Validate content
  local content
  content="$(cat "$conf_file")"
  if [ -n "$content" ]; then
    [[ "$content" =~ ^[A-Za-z0-9./_-]+$ ]] || die "Invalid runner.local content: $content"
    [ -x "$content" ] || die "PHP binary in runner.local does not exist or is not executable: $content"
    php_bin="$content"
  else
    php_bin="php"
    command -v "$php_bin" >/dev/null 2>&1 || die "Default 'php' not found on host"
  fi
  return 0
}

host_exec() {
  echo "⚠️ LOCAL MODE — PHP <8.3.x> trên host; chuẩn cuối vẫn là container 8.2.31 (chạy ai-check-docker/ai-test-docker trước khi merge)." >&2
  (
    cd "$repo_root/source"
    exec "$php_bin" "$@"
  )
}

ensure_not_symlink() {
  local abs_path="$1"

  if [ -L "$abs_path" ]; then
    die "Symlink path is not allowed: ${abs_path#$repo_root/}"
  fi
}

ensure_existing_file_under() {
  local abs_path="$1"
  local root_path="$2"
  local rel_path="${abs_path#$repo_root/}"
  local root_physical
  local dir_physical

  [ -f "$abs_path" ] || die "File does not exist: $rel_path"
  ensure_not_symlink "$abs_path"

  root_physical="$(cd "$root_path" && pwd -P)"
  dir_physical="$(cd "$(dirname "$abs_path")" && pwd -P)"

  case "$dir_physical/" in
    "$root_physical"/* | "$root_physical/") ;;
    *) die "Path escapes allowed root: $rel_path" ;;
  esac
}

source_php_file() {
  local raw="${AI_FILE:-}"

  [ -n "$raw" ] || die "Missing AI_FILE=source/path/to/File.php"
  [[ "$raw" =~ ^source/[A-Za-z0-9_./-]+\.php$ ]] || die "Invalid FILE path: $raw"
  [[ "$raw" != *..* ]] || die "Path traversal is not allowed: $raw"

  ensure_existing_file_under "$repo_root/$raw" "$repo_root/source"
  printf '%s' "${raw#source/}"
}

test_php_file() {
  local raw="${AI_TEST:-}"

  [ -n "$raw" ] || die "Missing AI_TEST=tests/Unit/FooTest.php"
  [[ "$raw" =~ ^tests/[A-Za-z0-9_./-]+Test\.php$ ]] || die "Invalid TEST path: $raw"
  [[ "$raw" != *..* ]] || die "Path traversal is not allowed: $raw"

  ensure_existing_file_under "$repo_root/source/$raw" "$repo_root/source/tests"
  printf '%s' "$raw"
}

route_path_arg() {
  local route_path="${AI_ROUTE_PATH:-}"

  [ -n "$route_path" ] || return 0
  [[ "$route_path" =~ ^[A-Za-z0-9_./:{}-]+$ ]] || die "Invalid ROUTE_PATH: $route_path"
  [[ "$route_path" != -* ]] || die "ROUTE_PATH must not be an option: $route_path"
  [[ "$route_path" != *..* ]] || die "Path traversal is not allowed: $route_path"

  printf '%s' "--path=$route_path"
}

case "$command_name" in
  lint)
    file="$(source_php_file)"
    if [ "${AI_FORCE_DOCKER:-0}" != "1" ] && runner_local_enabled; then
      host_exec -l "$file"
    else
      container_exec php -l "$file"
    fi
    ;;
  pint)
    file="$(source_php_file)"
    if [ "${AI_FORCE_DOCKER:-0}" != "1" ] && runner_local_enabled; then
      host_exec vendor/bin/pint "$file"
    else
      container_exec vendor/bin/pint "$file"
    fi
    ;;
  pint-check)
    file="$(source_php_file)"
    if [ "${AI_FORCE_DOCKER:-0}" != "1" ] && runner_local_enabled; then
      host_exec vendor/bin/pint --test "$file"
    else
      container_exec vendor/bin/pint --test "$file"
    fi
    ;;
  test)
    test_file="$(test_php_file)"
    if [ "${AI_FORCE_DOCKER:-0}" != "1" ] && runner_local_enabled; then
      host_exec vendor/bin/phpunit --do-not-cache-result "$test_file"
    else
      container_exec vendor/bin/phpunit --do-not-cache-result "$test_file"
    fi
    ;;
  php-version)
    if [ "${AI_FORCE_DOCKER:-0}" != "1" ] && runner_local_enabled; then
      host_exec -v
    else
      container_exec php -v
    fi
    ;;
  route-list)
    path_arg="$(route_path_arg)"
    if [ -n "$path_arg" ]; then
      container_exec php artisan route:list "$path_arg"
    else
      container_exec php artisan route:list
    fi
    ;;
  migrate-status)
    container_exec php artisan migrate:status
    ;;
  about)
    container_exec php artisan about
    ;;
  event-list)
    container_exec php artisan event:list
    ;;
  *)
    die "Unknown ai-docker command: ${command_name:-<empty>}"
    ;;
esac
