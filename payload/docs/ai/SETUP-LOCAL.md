# Local runner mode (opt-in)

Chạy tool AI trực tiếp trên host để vòng lặp dev (lint/format/test) nhanh hơn và tránh các lỗi kết nối Docker.

## 1. Cài đặt trên máy host (Ubuntu/Debian)

Bạn cần cài PHP CLI và các extension thiết yếu (nếu là Ubuntu noble, mặc định là PHP 8.3). Đặc biệt chú ý cài `php-sqlite3` để chạy unit test và `php-intl` nếu dự án có yêu cầu.

```bash
sudo apt install php-cli php-mbstring php-xml php-curl php-bcmath php-gd php-mysql php-redis php-zip php-sqlite3 php-intl
```

*(Lưu ý: Không cần cài `composer` trên host vì thư mục `vendor/` đã được mount sẵn từ container).*

## 2. Bật local mode

Chạy lệnh sau ở thư mục gốc của project (nơi chứa file `Makefile.ai`):

```bash
touch .claude/runner.local
```

Khi file này tồn tại:
- Các lệnh phân tích tĩnh và test (`ai-lint`, `ai-pint`, `ai-test`) và các git hooks sẽ tự động chạy thông qua host PHP (cực nhanh).
- Các lệnh Artisan (`route-list`, `migrate-status`, `about`, `event-list`) **vẫn tiếp tục chạy qua Docker** (Hybrid mode).

## 3. Quy tắc version (QUAN TRỌNG)

Mặc dù bạn dùng PHP 8.3 trên host để kiểm tra cho nhanh, môi trường thật vẫn là **PHP 8.2**.

| Phạm vi | Ràng buộc Version | Chú thích |
|---|---|---|
| `source/src` + `source/app` | **BẮT BUỘC 8.2** | Verify cuối trước khi merge vẫn chạy qua Docker 8.2.31. Tuyệt đối không dùng syntax 8.3-only ở đây. |
| Code Test | *Khuyến nghị 8.2* | Nếu dùng syntax 8.3, test sẽ pass trên máy bạn nhưng **chạy `ai-test-docker` sẽ fail** và người khác không chạy được. |

**Trước khi merge**, hãy tự kiểm tra lại mọi thứ bằng môi trường Docker nguyên bản:
```bash
make -f Makefile.ai ai-check-docker
make -f Makefile.ai ai-test-docker
```

## 4. Tắt / Rollback

Nếu môi trường host có vấn đề và bạn muốn trở lại cách làm 100% qua Docker:
```bash
rm .claude/runner.local
```
