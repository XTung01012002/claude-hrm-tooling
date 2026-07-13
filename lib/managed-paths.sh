#!/usr/bin/env bash

# Danh sách các file và thư mục gốc của payload sẽ được quản lý bởi tooling.
# Không bao gồm các symlink tự động generate (như .agents/skills hay .claude/skills)
# và không bao gồm các path thuộc dự án (như api-docs/).

MANAGED_PATHS=(
  "CLAUDE.md"
  "AGENTS.md"
  "Makefile.ai"
  "docs/ai"
  ".agent/hooks.json"
  ".agent/workflows"
  ".claude/commands"
  ".claude/hooks"
  ".claude/scripts"
  ".claude/settings.json"
  ".codex/hooks.json"
  "skills"
)
