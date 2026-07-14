---
name: grilling
description: Phỏng vấn user một cách có cấu trúc để làm rõ các yêu cầu, thiết kế, hoặc giả định bị thiếu. Dùng khi requirement còn mơ hồ, khi cần chốt schema/behavior, hoặc khi thực hiện Bước 5 của lệnh /implement.
---

# Grilling (Phỏng vấn làm rõ yêu cầu)

Khi yêu cầu (requirement) chưa đủ rõ ràng để code, hoặc khi bạn có nhiều giả định ảnh hưởng đến behavior, database schema, API contract, hoặc luồng nghiệp vụ, bạn **KHÔNG ĐƯỢC** xổ ra một loạt danh sách giả định rồi tự ý quyết định. Hãy dùng kỹ năng "Grilling" để phỏng vấn user.

## Nguyên tắc cốt lõi của Grilling

1. **Hỏi từng câu một:** Tuyệt đối không hỏi một list 3-5 câu cùng lúc. Hỏi 1 câu, chờ user trả lời, rồi mới hỏi tiếp. Điều này giúp tránh việc user bỏ sót câu hỏi.
2. **Kèm theo đề xuất (Default Option):** Với mỗi câu hỏi, LUÔN đưa ra một phương án đề xuất kèm lý do để user có thể dễ dàng đồng ý bằng một từ ("Ok", "Đồng ý").
   _Ví dụ:_ "Theo bạn, trường `status` nên dùng kiểu `string` hay `Enum`? Tôi đề xuất dùng `Enum` vì nó an toàn hơn cho validation. Bạn đồng ý không?"
3. **Phân biệt Rõ Fact và Decision:**
   - **Fact (Sự thật):** Những thứ có thể tra cứu được trong code (ví dụ: "Bảng này đã có trường X chưa?", "Hàm Y nằm ở đâu?"). **TUYỆT ĐỐI KHÔNG HỎI FACT**. Bạn phải tự dùng công cụ (`grep`, đọc file) để tìm fact.
   - **Decision (Quyết định):** Những thứ liên quan đến ý định thiết kế, quy trình nghiệp vụ chưa có tiền lệ. Đây là thứ bạn phải hỏi user.
4. **Đi theo cây quyết định:** Bắt đầu bằng những câu hỏi lớn có ảnh hưởng đến các lựa chọn sau đó. Giải quyết xong mới đi vào chi tiết (như tên biến, HTTP code lỗi).

## Khi nào dừng Grilling?

Dừng phỏng vấn khi bạn đã có đủ **shared understanding** (hiểu biết chung) để bắt tay vào code mà không phải đoán mò bất cứ chi tiết nào quan trọng. 
Trước khi chuyển từ pha phỏng vấn sang pha thực hiện (code), hãy tóm tắt lại các quyết định đã chốt và **nhờ user xác nhận** lần cuối.
