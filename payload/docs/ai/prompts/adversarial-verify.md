# PROMPT: Adversarial verification (HRM API)

> Prompt trung lập — dùng được với mọi AI. Trong Claude Code gọi qua `/verify`.
>
> **Đọc trước:** `docs/ai/PROJECT-CONVENTIONS.md` và `docs/ai/prompts/_shared/review-contract.md`.

## Nhiệm vụ

Bạn là reviewer đối nghịch ở bước cuối trước merge. Nhiệm vụ là kiểm định xem thay đổi có an toàn để merge không, dựa trên yêu cầu gốc, diff thật và code hiện tại.

Đây là nhiệm vụ **chỉ đọc và báo cáo**. Không sửa code, không format, không tạo test, không commit.

Không dùng commit message làm nguồn sự thật cho yêu cầu gốc. Nguồn yêu cầu ưu tiên theo thứ tự:

1. Nội dung user truyền vào `/verify`.
2. Plan cuối đã được xác nhận.
3. Task/spec/ticket được user chỉ định.
4. Nếu không có nguồn yêu cầu đủ rõ → `BLOCKED_INSUFFICIENT_CONTEXT`.

## Xác định phạm vi code

Áp dụng theo thứ tự, luôn ghi rõ phạm vi thực tế ở đầu output:

1. Nếu user truyền diff trực tiếp, dùng diff đó làm boundary. Khi có repository, vẫn đọc file thật và dependency liên quan để verify.
2. Nếu user chỉ định base branch, commit range, staged/unstaged hoặc PR, dùng đúng range đó.
3. Nếu user chỉ định danh sách file, **file scope là ưu tiên cao nhất**:
   - Xác định base/range từ input. Nếu input không nêu range, xác định base từ `origin/HEAD`; nếu không có thì thử `origin/develop`, `origin/main`, `develop`, `main`.
   - Lấy merge base bằng `git merge-base <base-ref> HEAD` khi dùng base branch.
   - Lấy diff riêng cho file bằng:
     ```bash
     git diff <base-or-range> -- <explicit-files>
     git diff --staged -- <explicit-files>
     ```
   - Đọc toàn bộ file và dependency liên quan để hiểu context, nhưng finding chính chỉ được tạo cho phần thay đổi của file trong diff/range.
4. Nếu không có scope rõ, verify toàn bộ thay đổi hiện tại: unstaged, staged và untracked. Chạy `git ls-files --others --exclude-standard -z` và đọc trực tiếp file untracked thuộc phạm vi.
5. Nếu chỉ nhận nội dung file hiện tại dưới dạng attachment mà không có Git history, diff, base commit/range hoặc phiên bản cũ để đối chiếu, trả `BLOCKED_INSUFFICIENT_CONTEXT`. Nội dung file đơn lẻ không đủ để biết phần nào là thay đổi.

Nếu không xác định được base/merge base, fallback về `git diff HEAD` và cảnh báo rằng chỉ local diff được verify. Nếu fallback vẫn không cho biết phần thay đổi, dùng `BLOCKED_INSUFFICIENT_CONTEXT`.

## Nguyên tắc finding

- Finding chính phải do thay đổi tạo ra, làm behavior cũ sai đi, hoặc khiến bug sẵn có trở nên reachable/ảnh hưởng trực tiếp.
- Đọc code thật trước khi kết luận: caller/callee, interface/implementation, Model/migration/config/test khi cần.
- Mỗi finding phải có file/line thật. Với dòng đã xóa, đọc phiên bản ở base/range và ghi rõ `dòng cũ`.
- Không bịa field, route, enum, response shape, rule validate, config hoặc test output.
- Bug cũ không liên quan diff chỉ ghi ở mục `Ngoài phạm vi diff — phát hiện thêm` nếu đã verify có tác động production/security/dữ liệu.

## 12 chiều kiểm định bắt buộc

1. **Yêu cầu gốc/Plan:** implementation có đáp ứng đúng acceptance criteria không, có bỏ sót bước nào không.
2. **Diff boundary:** có thay đổi ngoài scope, file untracked/staged bị bỏ sót, hoặc attachment không đủ diff không.
3. **Reuse + DRY:** có bỏ qua interface/repository/util/trait sẵn có hoặc copy logic lặp không.
4. **Layering + feature convention:** Core có phụ thuộc Infrastructure mới không; Handler/Command/Query/ValidationInterface có đúng khuôn không.
5. **Input validation + DTO:** camelCase, ép kiểu, null/empty semantics, validation implementation và message có đúng không.
6. **Business errors + i18n:** `BusinessException`, httpCode, message user-facing và exception boundary có đúng không.
7. **Multi-tenancy + security:** filter `company_id`/account/store, permission, secret logging, injection, ownership lookup.
8. **Persistence + transaction:** Eloquent cho code ghi mới, datetime/query-builder, transaction/lock/idempotency khi ghi nhiều bảng.
9. **Webhook/cache/queue/concurrency:** ordering event, retry, lock, TTL, invalidation, timeout/retry_after khi liên quan.
10. **API contract/backward compatibility:** response envelope, key camelCase, enum/status/message, pagination, Resource/Mapper shape.
11. **Edge cases/runtime traps:** Zalo timestamp, Carbon 3 signed diff, timezone, N+1/list sort whitelist, abstract Job readonly.
12. **Tests/evidence:** test liên quan có tồn tại, cover nhánh quan trọng, assert behavior thật, và lệnh test/lint đã chạy trong container hay chưa.

## Verdict

Áp dụng đúng `docs/ai/prompts/_shared/review-contract.md`:

- `🚫 BLOCKED_INSUFFICIENT_CONTEXT`: thiếu yêu cầu gốc, diff/base/range, code hoặc test để kết luận.
- `❌ REQUEST_CHANGES`: có ít nhất một finding `Merge blocking: Yes`.
- `⚠️ PASS_WITH_CONCERNS`: không có finding chặn merge nhưng còn finding không chặn, thiếu test hoặc rủi ro.
- `✅ PASS`: không có finding actionable/rủi ro đáng kể và test đủ.

## Output bắt buộc

```markdown
## Adversarial Verification Report

### Phạm vi đã verify
- Requirement source: <nguồn yêu cầu đã dùng>
- Code scope: <base/range/diff/files/staged/unstaged/untracked>
- Fallback/cảnh báo: <nếu có>

### Kết quả 12 chiều
| # | Chiều kiểm định | Kết quả | Bằng chứng |
|---|---|---|---|
| 1 | Yêu cầu gốc/Plan | PASS/CONCERN/FAIL/BLOCKED | `file:line` hoặc lý do |

### Findings

#### 🔴 BLOCKER
- **[file.php:line]** <vấn đề>
  - Severity: BLOCKER
  - Merge blocking: Yes
  - Confidence: High | Medium | Low
  - Current behavior: <behavior sai>
  - Counterexample: <input/state cụ thể>
  - Impact: <tác động>
  - Evidence: <code/config/test đã đọc>
  - Minimal fix: <cách sửa ngắn nhất>
  - Required test: <test cần có>

#### 🟡 IMPORTANT
- ...

#### 🔵 SUGGESTION
- ...

#### ❓ QUESTION
- ...

### Missing tests
- <test hoặc nhánh chưa cover; nếu không có: Không có>

### Commands run
- `<command>` → <kết quả>; hoặc `Chưa chạy` → <lý do>

### Ngoài phạm vi diff — phát hiện thêm
- <nếu có>

### Verdict
✅ PASS | ⚠️ PASS_WITH_CONCERNS | ❌ REQUEST_CHANGES | 🚫 BLOCKED_INSUFFICIENT_CONTEXT

<2-3 câu giải thích lý do verdict và điều kiện cần xử lý trước merge.>
```
