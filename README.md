# claude-hrm-tooling

Bộ AI tooling cá nhân cho dự án **HRM API**, tách khỏi repo code của team. Đồng bộ giữa nhiều máy (vd máy nhà ↔ máy công ty) qua **remote private của riêng bạn** — không commit gì vào repo team.

## Nội dung (`payload/` — mirror đúng cấu trúc thư mục project)
- `CLAUDE.md` — tóm tắt, trỏ về `docs/ai/PROJECT-CONVENTIONS.md`.
- `docs/ai/PROJECT-CONVENTIONS.md` + `docs/ai/prompts/*.md` — nguồn chân lý trung lập (dùng cho mọi AI).
- `.claude/commands/*.md` — slash command `/review`, `/api-docs`, `/scaffold-test`.
- `.claude/hooks/*.sh` — hook lint/format + chạy test liên quan.
- `api-docs/**` — docs FE (HRM-specific; có thể regenerate bằng `/api-docs`).

> Phần tooling tái dùng = `CLAUDE.md` + `docs/ai/` + `.claude/`. `api-docs/` là nội dung riêng của HRM.
> `.claude/settings.local.json` **không** nằm ở đây (bị gitignore + chứa path tuyệt đối theo máy). Việc đăng ký hook làm thủ công qua `hooks-snippet.json`.

## Lần đầu: đẩy lên remote private của bạn
```bash
cd /Users/macbook/Desktop/claude-hrm-tooling
# tạo 1 repo PRIVATE trên GitHub/GitLab cá nhân (vd: tungtx/claude-hrm-tooling), rồi:
git remote add origin git@github.com:<your-username>/claude-hrm-tooling.git
git push -u origin main
```

## Trên máy công ty: cài vào project
```bash
git clone git@github.com:<your-username>/claude-hrm-tooling.git
cd claude-hrm-tooling
./install.sh /duong-dan/toi/hrm-api      # copy file vào đúng chỗ trong project
```
Sau đó merge khối `hooks` trong [`hooks-snippet.json`](hooks-snippet.json) vào `<project>/.claude/settings.local.json` của máy đó, rồi khởi động lại Claude Code.

## Khi cập nhật tooling (máy gốc)
```bash
./sync-from-project.sh /duong-dan/toi/hrm-api   # copy file mới nhất từ project về payload/
git add -A && git commit -m "update tooling" && git push
```
Máy công ty: `git pull && ./install.sh /duong-dan/toi/hrm-api`.
