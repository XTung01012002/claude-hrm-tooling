# Shared Review Contract

File này là contract dùng chung cho mọi prompt review/diff-review/review-vs-plan/refactor trong HRM API.

## Severity

- **BLOCKER**: lỗi production/security, sai hoặc mất dữ liệu, rò rỉ tenant, hoặc phá public contract; phải có đường gây lỗi và tác động đã verify.
- **IMPORTANT**: bug edge case, regression, hiệu năng hoặc maintainability có tác động cụ thể đã chứng minh nhưng chưa tới mức BLOCKER.
- **SUGGESTION**: style/readability/cleanup, vi phạm convention không gây bug đã biết, hoặc cải thiện hợp lý.
- **QUESTION**: rủi ro chưa đủ dữ kiện xác nhận, cần author/owner trả lời.

Không dùng taxonomy legacy hoặc nhãn severity/verdict tự chế khác để xếp finding.

## Verdict

- **PASS**: không có BLOCKER, không có IMPORTANT bắt buộc sửa (`Merge blocking: Yes`), test đủ.
- **PASS_WITH_CONCERNS**: không có BLOCKER, nhưng có IMPORTANT không chặn merge (`Merge blocking: No`), thiếu test, hoặc còn rủi ro đã nêu rõ.
- **REQUEST_CHANGES**: có ít nhất một BLOCKER hoặc IMPORTANT bắt buộc sửa (`Merge blocking: Yes`) trước merge.
- **BLOCKED_INSUFFICIENT_CONTEXT**: thiếu code/test/context để kết luận an toàn.

Không dùng verdict rút gọn dạng nhị phân trong output review.
