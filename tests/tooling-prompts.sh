#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILURES=0

pass() {
  printf 'ok - %s\n' "$1"
}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  FAILURES=$((FAILURES + 1))
}

run_test() {
  local name="$1"
  shift

  if "$@"; then
    pass "$name"
  else
    fail "$name"
  fi
}

test_frontmatter_descriptions_are_yaml_safe() {
  local file line end_line

  while IFS= read -r file; do
    line="$(sed -n '1p' "$file")"
    [ "$line" = "---" ] || continue

    end_line="$(awk 'NR > 1 && $0 == "---" { print NR; exit }' "$file")"
    [ -n "$end_line" ] || {
      printf '%s: missing closing frontmatter marker\n' "$file" >&2
      return 1
    }

    if sed -n "2,$((end_line - 1))p" "$file" |
      awk '
        /^[[:space:]]*description:/ {
          value = $0
          sub(/^[[:space:]]*description:[[:space:]]*/, "", value)
          if (value !~ /^['\''"]/ && value ~ /:/) {
            found = 1
          }
        }
        END { exit found ? 0 : 1 }
      '; then
      printf '%s: quote description values that contain colon characters\n' "$file" >&2
      return 1
    fi
  done < <(find "$ROOT/payload/.claude/commands" "$ROOT/payload/.agents/workflows" "$ROOT/payload/skills" -type f -name '*.md' | LC_ALL=C sort)
}

test_antigravity_uses_canonical_agents_paths() {
  [ -d "$ROOT/payload/.agents/workflows" ] || return 1
  [ -f "$ROOT/payload/.agents/hooks.json" ] || return 1
  [ ! -e "$ROOT/payload/.agent" ] || return 1
  grep -q '".agents/hooks.json"' "$ROOT/lib/managed-paths.sh" || return 1
  grep -q '".agents/workflows"' "$ROOT/lib/managed-paths.sh" || return 1
}

test_every_antigravity_workflow_has_frontmatter_and_description() {
  local file end_line

  while IFS= read -r file; do
    [ "$(sed -n '1p' "$file")" = "---" ] || {
      printf '%s: missing frontmatter\n' "$file" >&2
      return 1
    }

    end_line="$(awk 'NR > 1 && $0 == "---" { print NR; exit }' "$file")"
    [ -n "$end_line" ] || {
      printf '%s: missing closing frontmatter marker\n' "$file" >&2
      return 1
    }

    sed -n "2,$((end_line - 1))p" "$file" | grep -Eq '^[[:space:]]*description:' || {
      printf '%s: missing frontmatter description\n' "$file" >&2
      return 1
    }
  done < <(find "$ROOT/payload/.agents/workflows" -type f -name '*.md' | LC_ALL=C sort)
}

test_antigravity_hooks_json_has_object_schema() {
  jq -e '
    type == "object" and
    (keys == ["hooks"]) and
    (.hooks | type == "object") and
    (.hooks.PreToolUse | type == "array") and
    (.hooks.PostToolUse | type == "array")
  ' "$ROOT/payload/.agents/hooks.json" >/dev/null
}

test_antigravity_hooks_use_native_tool_matchers() {
  local file="$ROOT/payload/.agents/hooks.json"

  jq -e '
    (.hooks.PreToolUse[]?.matcher | contains("run_command")) and
    (.hooks.PostToolUse[]?.matcher | contains("write_to_file")) and
    (.hooks.PostToolUse[]?.matcher | contains("replace_file_content"))
  ' "$file" >/dev/null
}

test_api_docs_wrappers_do_not_infer_from_diff() {
  local file

  for file in \
    "$ROOT/payload/.claude/commands/api-docs.md" \
    "$ROOT/payload/.agents/workflows/api-docs.md"; do
    ! grep -q 'lấy các Controller mới/đổi trong `git diff`' "$file" || return 1
    grep -q 'không tự suy luận endpoint từ `git diff`' "$file" || return 1
  done
}

test_scaffold_test_wrappers_do_not_override_test_path_rules() {
  local file

  for file in \
    "$ROOT/payload/.claude/commands/scaffold-test.md" \
    "$ROOT/payload/.agents/workflows/scaffold-test.md"; do
    ! grep -Eq 'source/tests/Unit/<ClassName>Test\.php|\[Đường_dẫn\]|AI_TEST=tests/Unit' "$file" || {
      printf '%s: wrapper must delegate test path rules to generate-test.md\n' "$file" >&2
      return 1
    }
  done
}

test_generate_test_profile_b_has_explicit_scope() {
  local file="$ROOT/payload/docs/ai/prompts/generate-test.md"

  ! grep -q 'A +' "$file" || return 1
  grep -q 'Baseline bắt buộc' "$file" || return 1
  grep -q 'Applicability scan bắt buộc' "$file" || return 1
}

test_diff_review_uses_review_verdict_rules() {
  local file="$ROOT/payload/docs/ai/prompts/diff-review.md"

  ! grep -q 'PASS WITH CONCERNS' "$file" || return 1
  ! grep -q 'REQUEST CHANGES' "$file" || return 1
  grep -q 'PASS_WITH_CONCERNS' "$file" || return 1
  grep -q 'REQUEST_CHANGES' "$file" || return 1
  grep -q 'BLOCKED_INSUFFICIENT_CONTEXT' "$file" || return 1
  grep -q 'review.md' "$file" || return 1
  grep -q 'Merge blocking: Yes' "$file" || return 1
}

test_diff_review_workflow_preserves_merge_blocking_gate() {
  local file="$ROOT/payload/.agents/workflows/diff-review.md"

  ! grep -q 'Không sinh commit khi có Blocker' "$file" || return 1
  grep -q 'PASS_WITH_CONCERNS' "$file" || return 1
  grep -q 'BLOCKED_INSUFFICIENT_CONTEXT' "$file" || return 1
  grep -q 'Merge blocking: Yes' "$file" || return 1
}

test_implement_quality_gate_requires_all_changed_files() {
  local file="$ROOT/payload/docs/ai/prompts/implement-requirement.md"

  ! grep -q 'AI_FILE=source/path/to/File.php make -f Makefile.ai ai-lint' "$file" || return 1
  grep -qi 'mọi PHP file' "$file" || return 1
  grep -qi 'mọi test' "$file" || return 1
  grep -q 'exit code `0`' "$file" || return 1
}

test_review_prompts_use_shared_contract() {
  local file

  for file in \
    "$ROOT/payload/CLAUDE.md" \
    "$ROOT/payload/docs/ai/prompts/review.md" \
    "$ROOT/payload/docs/ai/prompts/review-vs-plan.md" \
    "$ROOT/payload/docs/ai/prompts/refactor.md" \
    "$ROOT/payload/.claude/commands/refactor.md"; do
    ! grep -Eq 'PASS/FAIL|Thấp / Cần xác nhận|🔴 Cao|🟡 Trung bình|🔵 Gợi ý|❌ Không đạt' "$file" || {
      printf '%s: legacy severity/verdict wording found\n' "$file" >&2
      return 1
    }
  done

  grep -q 'review-contract.md' "$ROOT/payload/docs/ai/prompts/review.md" || return 1
  grep -q 'review-contract.md' "$ROOT/payload/docs/ai/prompts/review-vs-plan.md" || return 1
  grep -q 'review-contract.md' "$ROOT/payload/docs/ai/prompts/refactor.md" || return 1
  grep -q 'PASS_WITH_CONCERNS' "$ROOT/payload/CLAUDE.md" || return 1
  grep -q 'BLOCKED_INSUFFICIENT_CONTEXT' "$ROOT/payload/CLAUDE.md" || return 1
}

test_implement_requires_baseline_and_final_audit() {
  local file="$ROOT/payload/docs/ai/prompts/implement-requirement.md"

  grep -q 'Bước 0 — Workspace baseline' "$file" || return 1
  grep -q 'git status --short' "$file" || return 1
  grep -q 'Sửa/tạo code theo loại task' "$file" || return 1
  grep -q 'Final diff audit' "$file" || return 1
  grep -q 'Workspace audit' "$file" || return 1
  ! grep -q 'Theo khuôn feature §3: Command/Query + Handler + ValidationInterface' "$file" || return 1
}

test_all_skills_live_under_payload_skills() {
  [ -f "$ROOT/payload/skills/task-breakdown/SKILL.md" ] || return 1
  [ -f "$ROOT/payload/skills/find-reuse-candidates/SKILL.md" ] || return 1
  [ ! -e "$ROOT/payload/.claude/skills/find-reuse-candidates/SKILL.md" ] || return 1
}

test_task_sizing_does_not_reward_copy_paste() {
  local file="$ROOT/payload/skills/task-breakdown/references/sizing-rules.md"

  ! grep -q 'Copy-paste và sửa nhẹ' "$file" || return 1
  grep -q 'Có template gần giống nhưng không sao chép business logic' "$file" || return 1
  grep -q 'Không giảm effort chỉ vì có thể copy-paste' "$file" || return 1
}

test_scaffold_feature_quality_gate_checks_all_files() {
  local file="$ROOT/payload/docs/ai/prompts/generate-feature.md"

  grep -q 'toàn bộ PHP file vừa tạo' "$file" || return 1
  grep -q 'ai-check' "$file" || return 1
  grep -q 'ai-pint' "$file" || return 1
}

test_api_docs_trace_uses_boundaries() {
  local file="$ROOT/payload/docs/ai/prompts/generate-api-docs.md"

  ! grep -q 'tối đa \*\*2 tầng lời gọi tính từ Handler' "$file" || return 1
  grep -q 'boundary rõ ràng' "$file" || return 1
  grep -q 'lỗi sâu hơn chưa được verify' "$file" || return 1
}

test_code_docs_examples_are_domain_neutral() {
  local file="$ROOT/payload/docs/ai/prompts/generate-code-docs.md"

  ! grep -q 'NONE → REQUEST_SENT' "$file" || return 1
  ! grep -q 'Zalo API 500' "$file" || return 1
  grep -q 'STATE_A → STATE_B → STATE_C' "$file" || return 1
  grep -q 'External API error' "$file" || return 1
}

run_test "frontmatter descriptions are YAML-safe" test_frontmatter_descriptions_are_yaml_safe
run_test "Antigravity uses canonical .agents paths" test_antigravity_uses_canonical_agents_paths
run_test "Antigravity workflows require frontmatter" test_every_antigravity_workflow_has_frontmatter_and_description
run_test "Antigravity hooks JSON has object schema" test_antigravity_hooks_json_has_object_schema
run_test "Antigravity hooks use native tool matchers" test_antigravity_hooks_use_native_tool_matchers
run_test "api-docs wrappers do not infer from diff" test_api_docs_wrappers_do_not_infer_from_diff
run_test "scaffold-test wrappers delegate test paths" test_scaffold_test_wrappers_do_not_override_test_path_rules
run_test "generate-test Profile B has explicit scope" test_generate_test_profile_b_has_explicit_scope
run_test "diff-review uses review verdict rules" test_diff_review_uses_review_verdict_rules
run_test "diff-review workflow preserves merge gate" test_diff_review_workflow_preserves_merge_blocking_gate
run_test "implement quality gate checks all changed files" test_implement_quality_gate_requires_all_changed_files
run_test "review prompts use shared contract" test_review_prompts_use_shared_contract
run_test "implement requires baseline and final audit" test_implement_requires_baseline_and_final_audit
run_test "skills live under payload/skills" test_all_skills_live_under_payload_skills
run_test "task sizing does not reward copy-paste" test_task_sizing_does_not_reward_copy_paste
run_test "scaffold-feature checks all generated files" test_scaffold_feature_quality_gate_checks_all_files
run_test "api-docs trace uses boundaries" test_api_docs_trace_uses_boundaries
run_test "code-docs examples are domain-neutral" test_code_docs_examples_are_domain_neutral

if [ "$FAILURES" -ne 0 ]; then
  printf '%s test(s) failed\n' "$FAILURES" >&2
  exit 1
fi
