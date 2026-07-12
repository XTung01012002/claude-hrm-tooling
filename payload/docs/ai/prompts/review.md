# PROMPT: Review code change (HRM API)

> Prompt trung lập — dùng được với mọi AI. Trong Claude Code gọi qua `/review`. Với AI khác: dán nguyên file này + dán `git diff` (hoặc nội dung file đã sửa) vào.
>
> **Đọc trước:** `docs/ai/PROJECT-CONVENTIONS.md` (đặc biệt §0 cấm bịa, §1 reuse+DRY, §2 layering, §4 ORM, §5 bẫy, §8 multi-tenancy, §9 transaction/webhook, §10 list, §11 giữ behavior).

## Nhiệm vụ

Review thay đổi trong phạm vi được xác định bên dưới. Mục tiêu: bắt **bug có thật** và vi phạm convention dự án **trước khi** dev review tay.

Đây là nhiệm vụ **chỉ đọc và báo cáo**. Không tự sửa code, tạo test, format file, commit hoặc thay đổi trạng thái Git; chỉ đề xuất cách sửa trong finding. Việc thiếu test chỉ được flag để người dùng xử lý hoặc gọi `/scaffold-test`, không tự sinh test trong lúc review.

## Xác định phạm vi review

1. Nếu người dùng chỉ định base branch, commit range, staged/unstaged, PR, file hoặc diff cụ thể thì phạm vi đó được ưu tiên.
2. Nếu không được chỉ định, review toàn bộ thay đổi của branch hiện tại so với base branch:
   - Xác định base từ remote mặc định (`origin/HEAD`); nếu không có thì lần lượt thử `origin/develop`, `origin/main`, `develop`, `main` và báo rõ ref đã chọn.
   - Lấy merge base bằng `git merge-base <base-ref> HEAD`, rồi dùng `git diff <merge-base>` để bao gồm commit trên branch cùng thay đổi tracked đã staged/unstaged.
   - Chạy thêm `git status --short` và đọc file untracked thuộc phạm vi vì `git diff` không hiển thị chúng.
   - Nếu không xác định được base/merge base, fallback về `git diff HEAD` và cảnh báo rằng chỉ thay đổi local được review.
3. Nếu người dùng chỉ định một file, mặc định chỉ review **phần thay đổi của file đó** trong range đã chọn (`git diff <range> -- <file>`). Đọc toàn bộ file và dependency liên quan để lấy context, nhưng không biến code cũ không liên quan thành finding chính. Chỉ review toàn bộ file khi người dùng yêu cầu rõ.
4. Nếu người dùng dán sẵn diff, dùng diff đó làm phạm vi; vẫn đọc code thật trong repository để verify khi có quyền truy cập.

Ở đầu output phải ghi ngắn gọn phạm vi thực tế đã review: base/range hoặc staged/unstaged, các file được giới hạn và fallback/cảnh báo nếu có.

## Finding trong và ngoài diff

- Finding chính phải do thay đổi tạo ra, làm behavior cũ sai đi, hoặc khiến một bug sẵn có trở nên reachable/ảnh hưởng trực tiếp.
- Nếu khi đọc context phát hiện bug cũ hoàn toàn không liên quan diff, không trộn vào finding chính. Chỉ ghi bug đã verify có tác động production/security/dữ liệu vào mục `Ngoài phạm vi diff — phát hiện thêm`; bỏ qua style/cleanup ngoài phạm vi.
- Finding ngoài phạm vi phải ghi rõ đây là vấn đề có sẵn và không tính vào tổng finding chính.

## Quy tắc bắt buộc khi review

1. **§0 — Verify trước khi báo, cấm suy đoán.** Mỗi finding phải được kiểm chứng bằng code thật: đọc caller/callee, interface/implementation, migration/Model, config, framework behavior hoặc test liên quan tùy vấn đề.
2. Không bịa API/field/method. Nếu nghi ngờ symbol hoặc behavior không tồn tại, tìm kiếm xác nhận trước khi kết luận.
3. Kiểm tra comment, context nghiệp vụ, schema và pattern hiện có trước khi flag. Quy tắc này áp dụng cho **mọi** checklist, không chỉ ngoại lệ layering. Nếu code có ngoại lệ chủ đích và vẫn an toàn thì không flag; nếu lý do chưa đủ rõ thì hạ xuống `Thấp / Cần xác nhận` và nêu điều cần xác nhận.
4. Xác nhận số dòng từ file thật bằng `rg -n`, `nl -ba` hoặc công cụ đọc file; không lấy số dòng chỉ từ hunk header. Với dòng đã xóa, đọc phiên bản ở merge base và ghi `[file.php:dòng cũ N]`.
5. Không gắn mức độ chỉ vì mục đó xuất hiện trong checklist. Vi phạm convention thuần túy như thiếu `strict_types` hoặc dùng magic string mặc định là **Thấp**, trừ khi có bằng chứng cụ thể rằng nó gây bug hoặc rủi ro lớn hơn.

## Checklist (theo PROJECT-CONVENTIONS)

- **Reuse (§1):** có tạo mới class/interface/method trong khi đã có sẵn không? Có bỏ sót việc tái dùng repo/interface/util hiện có không?
- **Layering (§2):** code **mới** có import class Infrastructure cụ thể vào Core không? Handler có chỉ inject interface không?
- **Convention (§3):** thiếu `declare(strict_types=1)`? Handler không `readonly`? Không gọi `validate()` đầu tiên? Dùng magic string thay vì enum `->value`? `BusinessException` thiếu message tiếng Việt / sai httpCode?
- **Repository (§4):** code mới/đoạn sửa có dùng `DB::table()`/raw cho ghi không (nên Eloquent)? Cột datetime có truyền chuỗi ISO qua query-builder không (nguy cơ 1292)?
- **DRY (§1):** có copy cùng một logic ở ≥2 nơi không (vd kiểu `preserveRejectedStatus`) → có nên tách `Shared/`/`Helper`/Trait?
- **Multi-tenancy (§8):** dữ liệu có thật sự thuộc tenant không, và nếu có thì query đã filter `company_id` (+ account/store liên quan) chưa? Có query bằng `id` trần hoặc log token/secret không?
- **Transaction/webhook (§9):** use case ghi nhiều bảng có cần transaction/lock không? Webhook có nguy cơ downgrade trạng thái mới hơn không?
- **List (§10):** `sortBy`/`sortOrder` có whitelist chưa? Có N+1 / thiếu eager load không?
- **Giữ behavior (§11):** có tự đổi response shape / status / message / enum ngoài yêu cầu không?
- **Bẫy (§5):** timestamp Zalo có dùng `PlatformTime::parse()` không? Có dùng `diffIn*` mà quên dấu (Carbon 3)? Có đặt `readonly` ở abstract Job cha không? `timeout` worker có nhỏ hơn `retry_after` không?
- **Test (§6):** thay đổi logic có test tương ứng chưa? Test có theo AAA + Mockery + tên `test_<scenario>_<outcome>` không? Chỉ báo thiếu/sai test, không tự viết test.

## Xếp mức độ

- **🔴 Cao:** lỗi production/security, sai hoặc mất dữ liệu, rò rỉ tenant, hoặc phá public contract; phải có đường gây lỗi và tác động đã verify.
- **🟡 Trung bình:** bug edge case, regression, hiệu năng hoặc maintainability có tác động cụ thể đã chứng minh nhưng chưa tới mức Cao.
- **🟢 Thấp / Cần xác nhận:** style/readability/cleanup, vi phạm convention không gây bug đã biết, hoặc rủi ro hợp lý nhưng còn thiếu dữ kiện xác nhận.

Không chắc chắn thì không được gắn **Cao**. Nêu chính xác điều đã verify và phần nào còn cần xác nhận.

## Định dạng output

```markdown
## Phạm vi đã review

<base/range hoặc staged/unstaged; giới hạn file; cảnh báo fallback nếu có>

## 🔴 Cao

- [file.php:line] <vấn đề và tác động> → <cách sửa> (đã verify: <code/config/test đã đọc>)

## 🟡 Trung bình

- ...

## 🟢 Thấp / Cần xác nhận

- ...

## Ngoài phạm vi diff — phát hiện thêm

- [Mức độ] [file.php:line] <vấn đề có sẵn> → <cách sửa> (đã verify: <bằng chứng>)

Tổng kết: `N` cao, `N` trung bình, `N` thấp/cần xác nhận. Ngoài phạm vi: `N`.
```

- Mỗi finding là một bullet riêng, phải chỉ ra vị trí chính xác, tác động, cách sửa và bằng chứng verify; không chỉ tóm tắt thay đổi.
- Nếu một mức không có finding, ghi `Không có`.
- Nếu không có finding ngoài phạm vi, có thể bỏ hẳn mục đó và ghi `Ngoài phạm vi: 0` trong tổng kết.
- Với diff lớn trải từ 3 file trở lên, có thể nhóm thêm theo file bên trong từng mức độ; vẫn giữ `[file:line]` trên từng finding.

**Bổ sung bắt buộc sau tổng kết:**

```markdown
## Missing tests
- <test cần viết thêm — nhánh/edge case chưa được phủ>

## Questions / Assumptions
- <câu hỏi cho author — giả định chưa rõ, behavior chưa xác nhận>

## Verdict: ✅ PASS | ⚠️ PASS WITH CONCERNS | ❌ REQUEST CHANGES
```

### Quy tắc verdict
- **✅ PASS** — không có 🔴, ít 🟡, test đủ.
- **⚠️ PASS WITH CONCERNS** — không có 🔴, nhưng có 🟡 đáng lưu ý hoặc thiếu test.
- **❌ REQUEST CHANGES** — có ≥1 🔴 hoặc thiếu test cho logic quan trọng.
