# Điều kiện tự động nâng STRICT (Escalation Triggers)

Nếu bạn gặp bất kỳ điều kiện nào sau đây trong lúc phân tích yêu cầu, hãy tự động nâng mode lên **STRICT** và chờ user duyệt trước khi thực thi:

1.  Migration hoặc thay đổi schema
2.  Thay đổi API contract (request/response shape)
3.  Thay đổi public interface
4.  Thay đổi authorization hoặc permission
5.  Liên quan thanh toán, tính tiền hoặc dữ liệu nhạy cảm
6.  Queue, webhook, retry hoặc idempotency
7.  Transaction nhiều bảng
8.  Xóa hoặc cập nhật dữ liệu hàng loạt
9.  Thay đổi từ 5 file trở lên
10. Có giả định nghiệp vụ chưa được xác minh
11. Có từ 2 phương án triển khai khác nhau đáng kể
12. Có nguy cơ backward compatibility
13. AI không tìm được test hoặc code liên quan
