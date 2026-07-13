#!/usr/bin/env bash

# Danh sách các file và thư mục gốc của payload sẽ được quản lý bởi tooling.
# Không bao gồm các symlink tự động generate (như .agents/skills hay .claude/skills)
# và không bao gồm các path thuộc dự án (như api-docs/).

MANAGED_PATHS=(
  "CLAUDE.md"
  "AGENTS.md"
  "ai_workflows_reference.md"
  "Makefile.ai"
  "docs/ai"
  ".agents/hooks.json"
  ".agents/workflows"
  ".claude/commands"
  ".claude/hooks"
  ".claude/scripts"
  ".claude/settings.json"
  ".codex/hooks.json"
  "skills"
)
