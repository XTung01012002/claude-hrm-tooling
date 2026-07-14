---
name: writing-hrm-skills
description: Hướng dẫn cách viết một skill cho hệ thống. Chỉ dùng khi user yêu cầu tạo hoặc sửa đổi một skill.
disable-model-invocation: true
---

# Writing HRM Skills

Khi bạn được yêu cầu viết hoặc sửa một skill cho hệ thống agent, hãy tuân thủ các quy tắc sau (chắt lọc từ chuẩn viết skill của mattpocock/skills):

## 1. Description là Trigger
Trường `description` trong YAML frontmatter chính là cơ chế để AI tự kích hoạt skill.
- Đưa các từ khoá (trigger) lên đầu.
- 1 trigger / 1 nhánh logic.
- Đừng lặp lại nội dung của phần body trong description.

## 2. Progressive Disclosure (Tiết lộ lũy tiến)
Đừng nhét mọi thứ vào 1 file `SKILL.md` hoặc 1 file prompt duy nhất, nó sẽ làm phình to context. Hãy chia làm 3 tầng:
1. **Phải làm (Inline):** Các bước cốt lõi mà nhánh nào cũng chạy → Viết thẳng trong body.
2. **Tra cứu chung (Inline):** Những rule cần thiết cho mọi nhánh nhưng ngắn gọn.
3. **Chi tiết cục bộ (References):** Bảng biểu dài, ví dụ cụ thể, format xuất kết quả chi tiết mà chỉ vài nhánh cần → Đẩy ra thư mục `references/` và đặt pointer trong body (VD: *"Xem định dạng chi tiết tại `references/format.md`"*).

## 3. Không có "No-op" (No-operation)
Nếu một dòng hướng dẫn không làm thay đổi hành vi mặc định của AI, hãy **XOÁ HẲN** nó đi. Càng ngắn gọn càng tốt.

## 4. Nói khẳng định
Viết lệnh dưới dạng khẳng định những việc cần làm, thay vì cấm đoán những việc không được làm (trừ khi đó là constraint thực sự quan trọng như "TUYỆT ĐỐI KHÔNG sửa code nếu chưa có test đỏ").

## 5. Failure Modes cần tránh
- **Premature completion:** AI dừng quá sớm khi chưa xong việc. Khắc phục: Yêu cầu AI chờ user xác nhận mới đi tiếp.
- **Duplication:** AI làm lại những việc đã làm. Khắc phục: Hướng dẫn rõ điểm bắt đầu.
- **Sediment:** Nội dung cũ tồn đọng. Khắc phục: Chỉ cung cấp thứ cần thiết theo progressive disclosure.
- **Negation:** Viết câu phủ định ("đừng làm X") có thể khiến AI vô tình chú ý đến X nhiều hơn. Thay vào đó, hãy nói "hãy làm Y".
