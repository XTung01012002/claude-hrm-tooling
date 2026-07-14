---
name: hrm-quality-gate
description: Đảm bảo chất lượng code sau khi sửa. Dùng ngay sau khi bạn vừa tạo mới hoặc chỉnh sửa xong một hoặc nhiều file PHP.
---

# HRM Quality Gate (Kiểm tra chất lượng bắt buộc)

Đây là kỷ luật tự giác bắt buộc sau mỗi lần bạn sửa đổi hoặc tạo mới file PHP. Hệ thống không có hook tự động cho AI, nên bạn phải TỰ chạy các lệnh này trước khi báo cáo kết quả cho user.

## Các bước bắt buộc

Với MỖI file PHP bạn vừa sửa/tạo (`<path/to/file.php>`), bạn phải chạy lần lượt 3 lệnh sau (hoặc gộp biến môi trường nếu chạy nhiều file):

1. **Format Code (Pint):**
   `AI_FILE=<path/to/file.php> make -f Makefile.ai ai-pint`
2. **Lint Code (PHPStan/Lint):**
   `AI_FILE=<path/to/file.php> make -f Makefile.ai ai-lint`
3. **Run Unit Tests (nếu có):**
   Nếu file bạn sửa có file test tương ứng (VD: sửa `XHandler.php` thì chạy `XHandlerTest.php`), bạn BẮT BUỘC phải chạy test:
   `AI_TEST=<path/to/Test.php> make -f Makefile.ai ai-test`

## Tiêu chí hoàn thành (Exit Code 0)

Bạn chỉ được phép coi nhiệm vụ (hoặc bước sửa code) là hoàn tất và đánh dấu ✅ khi TẤT CẢ các lệnh trên đều trả về **Exit Code 0** (thành công).
- Nếu lệnh chạy ra lỗi (đỏ), bạn phải quay lại sửa code cho đến khi lệnh chạy xanh.
- Nếu bạn quên chạy lệnh, bạn chưa hoàn thành nhiệm vụ. Đừng báo cáo "Tôi đã sửa xong" khi chưa chạy quality gate.
