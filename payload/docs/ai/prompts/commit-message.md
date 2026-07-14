# Generate Commit Message

> Quy ước commit của dự án:
> - Định dạng: `type(scope): message tiếng Việt` (ví dụ: `feat(OmnichannelChat): Lưu nhân viên phản hồi` hoặc `fix(Zalo): Sửa lỗi gửi tin nhắn text`).
> - `type` chỉ được chọn từ danh sách: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `style`, `perf`.
> - `scope` lấy theo tên module hoặc namespace chứa phần lớn thay đổi, ưu tiên tên module Laravel (ví dụ: `OmnichannelChat`, `Zalo`, `HRM`). Nếu thay đổi không thuộc module Laravel, chọn tên thành phần hoặc phạm vi nghiệp vụ ngắn gọn và nhất quán với lịch sử commit.
> - Dòng subject không vượt quá 72 ký tự, súc tích và mô tả mục đích của thay đổi thay vì chỉ liệt kê file.
> - Nội dung commit message viết hoàn toàn bằng tiếng Việt; tên kỹ thuật, tên module và định danh trong code được giữ nguyên khi cần thiết.
> - Tham khảo cách diễn đạt của commit mẫu `0f366572` bằng lệnh `git show -s --format=%s 0f366572`. Nếu commit này không tồn tại trong lịch sử cục bộ, tiếp tục dựa trên các quy ước ở trên và không coi đây là lỗi chặn.

Nhiệm vụ của bạn:
1. Chạy `git diff --staged` để đọc toàn bộ thay đổi đã được staged.
2. Nếu không có thay đổi nào được staged, chạy `git diff` để đọc thay đổi chưa staged và cảnh báo rõ rằng commit message được sinh từ nội dung chưa staged.
3. Luôn chạy `git ls-files --others --exclude-standard -z` để phát hiện file untracked. Nếu có untracked file liên quan, đọc nội dung file đó và đưa vào phân tích; cảnh báo rõ rằng file mới chưa được staged nên commit message có thể không khớp nếu user commit ngay.
4. Nếu staged, unstaged và untracked đều trống, thông báo không có thay đổi để phân tích và không tự tạo commit message.
5. Xác định mục đích chính của thay đổi rồi sinh commit message theo đúng quy ước trên.
6. Nếu diff chứa nhiều nhóm thay đổi không liên quan về mục đích hoặc module, đề xuất tách thành nhiều commit và cung cấp một commit message riêng cho từng nhóm thay vì cố gộp thành một message.
7. Chỉ in commit message để người dùng tham khảo. **Không tự chạy `git commit` hoặc thay đổi trạng thái Git dưới bất kỳ hình thức nào.**
