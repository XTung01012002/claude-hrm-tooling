# Shared Review Contract

File này là contract dùng chung cho mọi prompt review/diff-review/review-vs-plan/verify/refactor trong HRM API.

## Severity

- **BLOCKER**: lỗi production/security, sai hoặc mất dữ liệu, rò rỉ tenant, hoặc phá public contract; phải có đường gây lỗi và tác động đã verify.
- **IMPORTANT**: bug edge case, regression, hiệu năng hoặc maintainability có tác động cụ thể đã chứng minh nhưng chưa tới mức BLOCKER.
- **SUGGESTION**: style/readability/cleanup, vi phạm convention không gây bug đã biết, hoặc cải thiện hợp lý.
- **QUESTION**: rủi ro chưa đủ dữ kiện xác nhận, cần author/owner trả lời.

Không dùng taxonomy legacy hoặc nhãn severity/verdict tự chế khác để xếp finding.

## Finding schema bắt buộc

- Mọi finding **BLOCKER** và **IMPORTANT** phải có trường `Merge blocking: Yes | No`.
- **BLOCKER** mặc định là `Merge blocking: Yes`. Chỉ dùng `No` khi finding không còn nằm trong phạm vi merge hiện tại và phải ghi rõ lý do.
- **IMPORTANT** có thể `Yes` hoặc `No`, nhưng phải nêu tác động cụ thể và điều kiện để merge an toàn.
- **SUGGESTION** và **QUESTION** là không chặn merge, trừ khi vấn đề được nâng cấp thành IMPORTANT/BLOCKER có schema đầy đủ.

## Verdict

Chọn verdict theo thứ tự ưu tiên, các nhánh bên dưới là bất giao nhau:

- **BLOCKED_INSUFFICIENT_CONTEXT**: thiếu code/test/diff/base/Plan/context để kết luận an toàn.
- **REQUEST_CHANGES**: có ít nhất một finding `Merge blocking: Yes`.
- **PASS_WITH_CONCERNS**: không có finding chặn merge, nhưng còn finding không chặn merge, thiếu test, hoặc rủi ro/giả định cần nêu rõ.
- **PASS**: không có finding actionable, không còn rủi ro/giả định đáng kể, và test đủ.

Không dùng verdict rút gọn dạng nhị phân trong output review.
