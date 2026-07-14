# Edge Cases Checklist

Khi phân tích yêu cầu, hãy đảm bảo bạn đã xem xét các trường hợp sau:
- Null/empty input → hành vi gì?
- Duplicate request → idempotent hay lỗi?
- Race condition → cần lock?
- Webhook event trễ/lặp → downgrade status?
- Dữ liệu legacy/cũ → tương thích?
- Timezone → UTC hay local?
