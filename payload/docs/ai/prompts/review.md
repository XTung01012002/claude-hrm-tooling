# PROMPT: Review code change (HRM API)

> Prompt trung lập — dùng được với mọi AI. Trong Claude Code gọi qua `/review`. Với AI khác: dán nguyên file này + dán `git diff` (hoặc nội dung file đã sửa) vào.
>
> **Đọc trước:** `docs/ai/PROJECT-CONVENTIONS.md` (đặc biệt §0 cấm bịa, §1 reuse, §2 layering, §4 ORM, §5 bẫy).

## Nhiệm vụ
Review thay đổi hiện tại (mặc định: output của `git diff`; nếu được chỉ định file cụ thể thì review file đó). Mục tiêu: bắt **bug đúng thật** + vi phạm convention dự án, **trước khi** dev review tay.

## Quy tắc bắt buộc khi review
1. **§0 — Verify trước khi báo, cấm suy đoán.** Mỗi finding phải kiểm chứng bằng đọc/`grep` code thật (grep callers, đọc migration/Model, check default framework). Chỉ gắn mức **Cao** khi đã verify. Không chắc → để **Thấp** và ghi "cần xác nhận".
2. Không bịa API/field/method. Nếu nghi ngờ một symbol không tồn tại → grep xác nhận rồi mới kết luận.

## Checklist (theo PROJECT-CONVENTIONS)
- **Reuse (§1):** có tạo mới class/interface/method trong khi đã có sẵn không? Có bỏ sót việc tái dùng repo/interface/util hiện có không?
- **Layering (§2):** code **mới** có import class Infrastructure cụ thể vào Core không (ngoài các ngoại lệ legacy đã biết)? Handler có chỉ inject interface không?
- **Convention (§3):** thiếu `declare(strict_types=1)`? Handler không `readonly`? Không gọi `validate()` đầu tiên? Dùng magic string thay vì enum `->value`? `BusinessException` thiếu message tiếng Việt / sai httpCode?
- **Repository (§4):** code mới/đoạn sửa có dùng `DB::table()`/raw cho ghi không (nên Eloquent)? Cột datetime có truyền chuỗi ISO qua query-builder không (nguy cơ 1292)?
- **Bẫy (§5):** timestamp Zalo có dùng `PlatformTime::parse()` không? Có dùng `diffIn*` mà quên dấu (Carbon 3)? Có đặt `readonly` ở abstract Job cha không? `timeout` worker có < `retry_after` không?
- **Test (§6):** thay đổi logic có test tương ứng chưa? Test có theo AAA + Mockery + tên `test_<scenario>_<outcome>` không?

## Định dạng output
Nhóm theo mức độ, mỗi finding 1 dòng:

```
## Cao
- [file.php:line] <vấn đề> → <cách sửa> (đã verify: <grep/đọc gì>)

## Trung bình
- ...

## Thấp / Cần xác nhận
- ...
```

Nếu không có vấn đề ở một mức → ghi "Không có". Kết thúc bằng 1 dòng tổng kết số finding mỗi mức.
