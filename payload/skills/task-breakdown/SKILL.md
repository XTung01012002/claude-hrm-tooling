---
name: task-breakdown
description: Bẻ việc, bóc task, estimate theo HRM API rules (Size×Effort→Point).
---

# Bẻ Việc - Task Breakdown

> Áp dụng khi user yêu cầu: **bẻ việc**, **bóc task**, **breakdown**, **chia task**, **estimate**, hoặc gửi **User Story / Feature / Code snippet** cần phân tích.

Bạn là trợ lý giúp bẻ việc (task breakdown) theo chuẩn dự án. Khi thực hiện bóc task, bạn cần:
1. Đọc và tuân thủ các tài liệu tham khảo trong thư mục `references/`:
   - `sizing-rules.md`: ma trận Size×Effort→Point, quy tắc công bằng, giới hạn Point.
   - `task-types.md`: mapping size/point tham khảo cho kiến trúc HRM API.
   - `output-schema.md`: định dạng bảng bắt buộc (phải xuất đúng template này).
   - `dependency-rules.md`: quy tắc dependency, reuse và không cộng trùng point. Bắt buộc đọc khi scope có Handler, Repository hoặc nhiều file phụ thuộc nhau.
2. Tham khảo `examples/` để biết mức độ chi tiết của task, cách ghi File liên quan và Lý do point.

## 1. Xác định Scope
- Chỉ bẻ việc theo phạm vi user cung cấp (không tự thêm route/controller nếu user chỉ đưa handler snippet).
- Nếu thiếu thông tin, ưu tiên estimate theo giả định rõ ràng (ví dụ: "giả định scope là backend handler").
- Chỉ hỏi lại khi thiếu thông tin làm thay đổi hoàn toàn phạm vi công việc.

## 2. Nguyên Tắc Chia Task
- Độc lập, test/verify được độc lập.
- Không chia theo số file (1 file có thể có nhiều task nếu chạm nhiều boundary kỹ thuật như HTTP, DB, S3, Queue).
- Task lớn (> 2 Point) BẮT BUỘC phải chia nhỏ.
- Technical boundary: HTTP, DB Read, DB Write, File I/O, Queue, Event...

## 3. Rule Tái Sử Dụng (Cốt lõi)
- Phân biệt rõ viết mới và tái sử dụng.
- Nếu chỉ gọi lại interface/hàm đã có → KHÔNG tính phần logic bên trong interface/hàm đó (0 point cho phần implementation). Chỉ tính phần việc bao quanh lời gọi (mapping, check lỗi).
- Ghi rõ `(reuse)` vào các dependency được gọi lại.
- Áp dụng khi estimate nhiều file: file sau gọi lại logic định nghĩa ở file trước → tính là reuse.

## 4. Tên Task, File/Dependency, Lý Do Point
- Tên task: tiếng Việt, dễ hiểu (Nên: "Lưu tin nhắn vào database"; Không nên: "Persistence").
- Cột File/Dependency: Ghi file đang sửa, file cần tạo, dependency reuse. (ví dụ: `{File chính}`, `{Helper} (reuse)`).
- Cột Lý do point: Giải thích ngắn gọn vì sao đánh Size/Effort đó (ví dụ: "Point cao vì có upload S3", "Point thấp do reuse repository").

## 5. Sanity Check Bắt Buộc Trước Khi Xuất Kết Quả
- Đã xuất bảng theo đúng định dạng ở `references/output-schema.md` chưa?
- Có task nào quá lớn (> 2 Point) không?
- Đã trừ point (giảm effort) do reuse chưa?
- Point ở mỗi task là 1 con số duy nhất hay đang để range? (Cấm để range).
- Cột Lý do point có dễ hiểu không?
