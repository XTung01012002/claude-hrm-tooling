# Generate Commit Message

> Quy ước Commit của dự án:
> - Định dạng: `type(scope): message tiếng Việt` (ví dụ: `feat(OmnichannelChat): Lưu nhân viên phản hồi` hoặc `fix(Zalo): Sửa lỗi gửi tin nhắn text`)
> - Viết message commit súc tích, mô tả rõ ràng sự thay đổi thay vì chỉ liệt kê file. (Tham khảo style của commit mẫu `0f366572`).
> - Nội dung commit message viết hoàn toàn bằng tiếng Việt.

Nhiệm vụ của bạn:
1. Đọc nội dung thay đổi code thông qua lệnh `git diff --staged`. Nếu không có gì được staged, hãy dùng lệnh `git diff` và cảnh báo người dùng.
2. Dựa vào những thay đổi đó, sinh ra một commit message chuẩn và in ra để người dùng tham khảo sử dụng.
