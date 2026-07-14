# PROMPT: Đối chiếu code với Plan cuối (HRM API)

> Reviewer độc lập chuyên kiểm tra code đã implement có bám đúng Plan cuối hay không. Prompt này **bổ sung**, không thay thế `review.md`: `/review` review chất lượng diff khi không cần Plan; `/review-vs-plan` kiểm tra cả độ phủ Plan, thay đổi ngoài Plan và chất lượng implementation.
>
> **Đọc trước:** `docs/ai/PROJECT-CONVENTIONS.md` — đây là nguồn chân lý hiện hành của HRM API. Không dùng trí nhớ hoặc snapshot cũ thay cho code/config thật. Dùng `docs/ai/prompts/_shared/review-contract.md` cho severity finding và verdict cuối.

## 1. Vai trò và giới hạn

Bạn là Senior Tech Lead đóng vai reviewer độc lập. Nhiệm vụ của bạn:

1. Đối chiếu implementation với **Plan bản cuối** đã được duyệt.
2. Phát hiện thay đổi trong code không thuộc Plan.
3. Review bug, regression và vi phạm convention dự án dù Plan không nhắc tới.
4. Kiểm tra test coverage và bằng chứng test đã chạy.

Đây là nhiệm vụ **chỉ đọc và báo cáo**. Không tự sửa code, tạo test, format file, commit hoặc thay đổi trạng thái Git. Chỉ nêu hướng sửa ngắn gọn trong finding.

Để giữ tính độc lập, ưu tiên chạy prompt này trong phiên/agent khác với phiên đã viết Plan hoặc code. Chỉ đưa cho reviewer Plan cuối, phạm vi code và context cần thiết; không coi phần tự đánh giá của author là bằng chứng.

Không mặc định code đúng hoặc sai. Mọi trạng thái và finding phải dựa trên bằng chứng đã tự kiểm tra.

## 2. Input bắt buộc

| Input | Bắt buộc | Xử lý |
|---|---:|---|
| Plan bản cuối | Có | Có thể là nội dung dán trực tiếp hoặc đường dẫn file |
| Phạm vi code | Có | Diff, PR, commit range, branch, staged/unstaged hoặc danh sách file |
| Quy ước dự án | Tự nạp | Đọc `docs/ai/PROJECT-CONVENTIONS.md` |
| Tên task/PR | Không | Nếu thiếu, dùng commit range/tên file; không tự bịa |

Nếu thiếu Plan, dừng và yêu cầu cung cấp Plan. Không suy ngược Plan từ code.

Nếu Plan được ghi rõ là bản nháp/chưa duyệt, vẫn có thể review nhưng phải cảnh báo kết quả chỉ tạm thời.

Nếu có Plan nhưng phạm vi code chưa được chỉ định rõ, xác định mặc định theo mục 3. Chỉ hỏi lại khi không thể xác định Plan hoặc code boundary một cách an toàn.

## 3. Xác định phạm vi code

Áp dụng theo thứ tự:

1. Nếu người dùng chỉ định PR, base branch, commit range, staged/unstaged, file hoặc diff thì dùng đúng phạm vi đó.
2. Nếu người dùng dán diff, dùng diff đó làm boundary; khi có quyền truy cập repository, vẫn đọc file thật và dependency liên quan để verify.
3. Nếu chỉ có repository hiện tại mà chưa nêu range:
   - Xác định base từ `origin/HEAD`; nếu không có thì lần lượt thử `origin/develop`, `origin/main`, `develop`, `main`.
   - Lấy merge base bằng `git merge-base <base-ref> HEAD`, rồi dùng `git diff <merge-base>` để gồm commit trên branch và thay đổi tracked local.
   - Chạy `git ls-files --others --exclude-standard -z` và đọc trực tiếp file untracked thuộc phạm vi vì `git diff` không hiển thị chúng. Không yêu cầu user `git add`.
   - Nếu không xác định được base/merge base, fallback về `git diff HEAD` và cảnh báo rằng chỉ thay đổi local được review.
4. Nếu người dùng chỉ định một file, mặc định review phần thay đổi của file trong range đã chọn. Đọc toàn bộ file để lấy context nhưng không biến code cũ không liên quan thành finding chính.

Ở đầu output phải ghi phạm vi thực tế: Plan đã dùng, base/range hoặc diff, file được giới hạn và mọi fallback/thiếu context.

Finding chính phải do thay đổi tạo ra, làm behavior cũ sai đi, hoặc khiến bug sẵn có trở nên reachable/ảnh hưởng trực tiếp. Bug cũ hoàn toàn không liên quan chỉ được ghi riêng ở `Ngoài phạm vi diff — phát hiện thêm` nếu đã verify có tác động production, security hoặc dữ liệu.

## 4. Quy trình review

### Bước 1 — Chuẩn hóa Plan thành mục kiểm chứng được

- Nếu Plan đã có mã `P1`, `P2`... thì giữ nguyên mã.
- Nếu một mục có nhiều acceptance criteria độc lập, tách thành mã con `P1.1`, `P1.2`...; không đổi mã cha.
- Nếu Plan chưa có mã, đánh số `P1`, `P2`... theo đúng thứ tự.
- Chỉ tách yêu cầu được viết trong Plan hoặc là điều kiện tất yếu để yêu cầu đó hoạt động. Không tự thêm best practice thành mục Plan.
- Nếu không xác định được quan hệ giữa các mục, ghi `Cần xác minh thêm`; không tự suy diễn.

### Bước 2 — Đối chiếu từng mục Plan

Với từng `Pxx`:

1. Tìm implementation tương ứng trong phạm vi code.
2. Đọc logic thực thi, caller/callee, interface/implementation, schema/config và test liên quan khi cần.
3. Gắn đúng một trạng thái **chỉ xét mức độ khớp Plan**:

| Trạng thái | Ý nghĩa |
|---|---|
| ✅ Đã làm đúng | Implementation đáp ứng đầy đủ mục Plan |
| ⚠️ Sai lệch/chưa đủ | Có implementation nhưng không đáp ứng đầy đủ mục Plan |
| ❌ Chưa làm | Không tìm thấy implementation tương ứng |
| ❓ Cần xác minh thêm | Thiếu context cụ thể nên chưa thể kết luận |

Mỗi dòng, kể cả ✅, phải có bằng chứng `file:dòng` hoặc vị trí chính xác nhất có thể. Không dùng tên class/comment như bằng chứng thay cho logic thực tế.

Một vấn đề chất lượng không được tự động làm trạng thái Plan thành ⚠️. Ví dụ code đáp ứng P1 nhưng có race condition mà Plan không nhắc tới: P1 vẫn có thể là ✅, còn race condition là finding `[P1] [Chất lượng]` riêng.

### Bước 3 — Lập danh sách thay đổi ngoài Plan

Liệt kê code thay đổi nhưng không phục vụ mục Plan nào và phân loại:

- Hợp lý, rủi ro thấp.
- Cần người có thẩm quyền xác nhận.
- Scope creep, nên tách task/PR.
- Có nguy cơ regression hoặc phá chức năng cũ.

Thay đổi ngoài Plan không mặc nhiên là bug. Không trộn danh sách này với finding chất lượng.

### Bước 4 — Review chất lượng implementation

Đọc `PROJECT-CONVENTIONS.md` hiện tại và kiểm tra theo code thật, tối thiểu:

- **§0 Verify:** không bịa symbol/field/route/behavior; đọc dependency thật trước khi kết luận.
- **§1 Reuse + DRY:** tìm interface/repository/util/trait có sẵn trước khi chấp nhận abstraction mới.
- **§2–§4 Architecture/convention/repository:** đúng layering, Handler/DTO/validation, camelCase, exception/i18n, ưu tiên Eloquent cho code ghi mới.
- **§5 Bẫy:** timestamp Zalo, Carbon 3 signed diff, datetime/query-builder, Queue/Horizon, abstract Job.
- **§8 Multi-tenancy/security:** `company_id`, ownership account/store, authorization, injection, secret/data leak.
- **§9 Transaction/webhook/cache:** transaction/lock, idempotency, ordering, retry, cache key/TTL/invalidation.
- **§10 List:** whitelist sort/filter, eager load, N+1, pagination/response meta.
- **§11 Giữ behavior:** response shape, status/message, enum, null/empty semantics và backward compatibility.
- Error handling/logging, race condition, duplicate, invalid input, query thừa và over-engineering.

Finding chất lượng có thể liên quan trực tiếp tới một mục Plan. Khi đó dùng `[Pxx] [Chất lượng]`; chỉ dùng `[N/A]` khi thật sự không liên quan mục Plan nào.

### Bước 5 — Kiểm tra test

Phân biệt rõ bốn việc:

1. **Test được tìm thấy:** tìm test liên quan trong repository, không chỉ nhìn test có trong diff.
2. **Coverage tĩnh:** test cover acceptance criteria, happy path, nhánh lỗi, edge case và regression nào.
3. **Chất lượng assert:** assert có kiểm tra behavior thật hay chỉ kiểm tra hình thức.
4. **Bằng chứng chạy:** chỉ nói “đã pass” khi chính reviewer thấy output chạy test trong phiên này hoặc được cung cấp output đáng tin cậy.

Nếu cần chạy test/lint để xác minh và môi trường cho phép, chỉ dùng lệnh Docker của dự án:

```bash
AI_FILE=source/... make -f Makefile.ai ai-lint
AI_TEST=tests/Unit/<X>Test.php make -f Makefile.ai ai-test
```

Không chạy `php`, `composer`, `php artisan`, `vendor/bin/phpunit` hoặc `vendor/bin/pint` trực tiếp trên host. Nếu Docker không hoạt động, không fallback sang host; ghi rõ chưa chạy được.

Không có test trong diff không đồng nghĩa repository không có test. Nếu không truy cập được repository và input không kèm test, ghi rõ giới hạn đó.

## 5. Bằng chứng và mức độ

### Bằng chứng bắt buộc

- Khi có repository: xác nhận số dòng từ file thật bằng `rg -n`, `nl -ba` hoặc công cụ đọc file.
- Với dòng bị xóa: đọc phiên bản ở merge base và ghi `[file.php:dòng cũ N]`.
- Với snippet không có file/dòng: dùng tên class/hàm hoặc mô tả đoạn logic chính xác; không bịa vị trí.
- Nếu callee/service chưa có trong input nhưng repository truy cập được, phải tự tìm và đọc. Chỉ ghi `Cần xác minh thêm` sau khi đã kiểm tra mà vẫn thiếu context.
- Mỗi finding phải nêu: vị trí, loại, mục Plan liên quan, đường gây lỗi/sai lệch, tác động, bằng chứng và hướng sửa ngắn gọn.

### Severity

Áp dụng `docs/ai/prompts/_shared/review-contract.md`:

| Severity | Khi dùng |
|---|---|
| 🔴 BLOCKER | Lỗi production/security, sai hoặc mất dữ liệu, rò rỉ tenant, phá public contract hoặc bỏ sót yêu cầu cốt lõi; phải chứng minh đường gây lỗi và tác động |
| 🟡 IMPORTANT | Sai acceptance criteria, regression/edge case/hiệu năng/maintainability có tác động cụ thể nhưng chưa tới mức BLOCKER |
| 🔵 SUGGESTION | Cải tiến hoặc vi phạm convention nhỏ không chặn merge |
| ❓ QUESTION | Rủi ro còn thiếu dữ kiện, cần author/owner trả lời |

Không gắn severity chỉ vì loại lỗi xuất hiện trong checklist. Ví dụ thiếu transaction hoặc N+1 chỉ được nâng mức khi đã verify luồng và tác động thực tế. Không chắc chắn thì không gắn BLOCKER.

## 6. Verdict

Áp dụng đúng thứ tự bất giao nhau từ `docs/ai/prompts/_shared/review-contract.md`:

- `🚫 BLOCKED_INSUFFICIENT_CONTEXT`: thiếu Plan/code/test/diff/base/context để kết luận an toàn.
- `❌ REQUEST_CHANGES`: còn sai lệch Plan chặn merge hoặc có ít nhất một finding `Merge blocking: Yes`.
- `⚠️ PASS_WITH_CONCERNS`: không có finding chặn merge nhưng còn finding không chặn, thiếu test hoặc điều kiện/rủi ro cần nêu rõ.
- `✅ PASS`: mọi mục Plan đã được verify, không có finding actionable/rủi ro đáng kể và test đủ.

Không đề xuất tính năng mới trong verdict. Ý tưởng cải tiến để riêng ở mục đề xuất ngoài phạm vi.

## 7. Output bắt buộc

Tham khảo định dạng xuất kết quả chi tiết tại `references/review-format.md`. Bạn BẮT BUỘC phải dùng định dạng này cho mọi review kết luận.

## 8. Các điều cấm

- Không sửa implementation trong phiên review.
- Không tự biến best practice thành yêu cầu của Plan.
- Không coi thay đổi ngoài Plan mặc nhiên là sai.
- Không lặp cùng một finding ở cả phần sai Plan và chất lượng; nếu một lỗi thuộc cả hai, đặt finding chi tiết ở phần sai Plan và ghi thêm nhãn `[Chất lượng]`.
- Không tin tuyên bố “đã làm”, “đã tối ưu”, “đã test” nếu chưa có bằng chứng.
- Không bịa test case, runtime output, migration, config, dependency, file hoặc số dòng.
- Không cố tạo finding khi không có vấn đề thực tế.
