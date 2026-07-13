# claude-hrm-tooling

Bộ AI tooling cá nhân cho **HRM API**, tách khỏi repo code team. Đồng bộ nhiều máy qua remote private của bạn, cài vào project bằng `install.sh`. Hỗ trợ **Claude Code · Codex · Antigravity** dùng chung 1 nguồn chân lý.

> **Hướng dẫn dùng & cài chi tiết: [`HUONG-DAN-SU-DUNG.md`](HUONG-DAN-SU-DUNG.md)** — đây là nguồn chuẩn; README chỉ tóm tắt.

## Nội dung (`payload/` — mirror cấu trúc project; `install.sh` copy hết)
- `CLAUDE.md` (Claude) · `AGENTS.md` (Antigravity/Codex/Cursor) — pointer rule, trỏ về `docs/ai/PROJECT-CONVENTIONS.md`.
- `ai_workflows_reference.md` — bảng tham chiếu nhanh các workflow/skill/slash command đang dùng trong HRM API.
- `docs/ai/PROJECT-CONVENTIONS.md` + `docs/ai/prompts/*.md` — nguồn chân lý trung lập (13+ prompt: review, review-vs-plan, implement, scaffold-test, api-docs, code-docs, diff-review, verify, refactor, commit-message, find-reuse, scaffold-feature, task-breakdown).
- `.claude/commands/*.md` + `.claude/hooks/*.sh` + `.claude/scripts/*.sh` — 13+ slash commands + hook lint/format/test + wrapper Docker an toàn (Claude).
- `.agents/workflows/*.md` + `.agents/hooks.json` — 13+ workflows + hooks (Antigravity).
- `.codex/hooks.json` — hooks (Codex); prompts cài vào `~/.codex/prompts` qua `install.sh`.

## Đẩy lên remote private (lần đầu)
```bash
cd /duong-dan/toi/claude-hrm-tooling
git remote add origin https://github.com/<your-username>/claude-hrm-tooling.git
git push -u origin main
```

## Cài trên máy mới
```bash
git clone https://github.com/<your-username>/claude-hrm-tooling.git
cd claude-hrm-tooling
./install.sh /duong-dan/toi/hrm-api
```
Một-lần mỗi tool (chi tiết ở [HUONG-DAN-SU-DUNG.md](HUONG-DAN-SU-DUNG.md) mục C):
- **Claude Code**: dán khối `hooks` trong [`hooks-snippet.json`](hooks-snippet.json) vào `<project>/.claude/settings.local.json` → restart.
- **Codex**: mở project → hiện *"hooks need review"* → **Review hooks** rồi trust → restart.
- **Antigravity**: chỉ mở project (tự đọc `AGENTS.md` + `.agents/workflows/` + `.agents/hooks.json`) → restart.

## Cập nhật tooling về sau
```bash
./sync-from-project.sh /duong-dan/toi/hrm-api   # project → payload/
git add -A && git commit -m "update tooling" && git push
# máy khác: git pull && ./install.sh /duong-dan/toi/hrm-api
```

> - `install.sh` tự thêm các file AI (`CLAUDE.md`, `AGENTS.md`, `.claude/`, `.agents/hooks.json`, `.agents/workflows/`, `.codex/`, `docs/ai/`) vào `<project>/.git/info/exclude` → **không lỡ commit vào repo team** (`api-docs/` không bị exclude vì có thể thuộc project).
> - `.claude/settings.local.json` không nằm trong repo này (gitignore + chứa path theo máy) → đăng ký hook qua `hooks-snippet.json`.
> - `.claude/hooks/*.sh` và `.claude/scripts/*.sh` là **code tự chạy** — nên liếc lại sau mỗi `git pull`.
