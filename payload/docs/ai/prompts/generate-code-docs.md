# PROMPT: Sinh tài liệu code cho Backend (HRM API)

> Prompt trung lập — dùng được với mọi AI. Trong Claude Code gọi qua `/code-docs`. Với AI khác: dán file này + chỉ định module/class cần viết docs.
>
> **Đọc trước:** `docs/ai/PROJECT-CONVENTIONS.md` §0 (cấm bịa) và §2 (kiến trúc).

## Nhiệm vụ
Viết tài liệu **logic nội bộ cho developer BE**, ghi vào `docs/<Module>/<Feature>.md` hoặc `docs/<Module>/README.md`. KHÁC `api-docs/` (contract cho FE).

**Tài liệu phải được suy ra từ CODE + TEST thực tế**, không chỉ dựa trên tên method hay yêu cầu ban đầu.

---

## Bắt buộc — đọc code thật (§0)

1. **Đọc class** — Handler, Command/Query, ValidationInterface + impl, Repository, Model, Entity, Mapper.
2. **Đọc test** — lấy behavior thật từ test case, edge case đã cover.
3. **Grep callers** — ai gọi module này? Có side effects gì?
4. **Đọc ServiceProvider** — binding nào? Listener nào?

---

## Template tài liệu

```markdown
# <Module/Feature Name>

## Mục đích
<1-2 câu mô tả module/feature này giải quyết vấn đề gì>

## Trách nhiệm chính
- <liệt kê các responsibility — mỗi dòng 1 trách nhiệm>

## Kiến trúc

### Files
| File | Vai trò |
|---|---|
| `Core/.../XCommand.php` | DTO input |
| `Core/.../XHandler.php` | Logic nghiệp vụ chính |
| `Core/.../XValidationInterface.php` | Contract validation |
| `Infrastructure/.../XValidation.php` | Impl validation rules |
| `Infrastructure/.../XRepository.php` | Data access |

### Luồng xử lý
```
Controller → Command/Query → ValidationInterface → Handler → Repository
                                                  → Event dispatch
                                                  → External API call
```

<Mô tả chi tiết từng bước trong luồng — chỉ khi phức tạp>

## Input / Output

### Input
| Field | Kiểu | Mô tả |
|---|---|---|
| ... | ... | ... |

### Output (return type)
```php
// shape thật từ Handler
['key' => 'value', ...]
```

## Quyết định nghiệp vụ quan trọng
- <Decision 1>: <lý do — tại sao chọn cách này; kèm bằng chứng `file:line` từ code/test>
- <Decision 2>: ...

> Đây là phần quan trọng nhất — developer mới cần hiểu **tại sao** code làm thế, không chỉ **làm gì**.
> Nếu không tìm thấy bằng chứng trong code/test/comment/commit context được cung cấp, ghi rõ `Chưa kiểm chứng` hoặc bỏ quyết định đó; không tự suy luận ý định từ tên method.

## Side Effects
- **Events dispatched**: <tên event + khi nào trigger>
- **Queue jobs**: <tên job + queue name + khi nào dispatch>
- **Cache**: <key pattern + khi nào forget/set>
- **Notifications**: <loại + kênh + khi nào gửi>
- **External API calls**: <service + endpoint + khi nào gọi>

> Chỉ liệt kê side effect **thật sự có trong code** — grep xác nhận.

## Transaction Boundary
- <Mô tả: bọc transaction ở đâu? Lock gì? Tại sao?>
- <Nếu không có transaction: ghi rõ "không bọc transaction — lý do">

## Trạng thái (State Machine)
<Nếu có state transition — vẽ diagram hoặc liệt kê>

```
STATE_A → STATE_B → STATE_C
STATE_A → STATE_D → STATE_C
                 → STATE_E
```

> Bỏ mục này nếu feature không có state machine.

## Failure & Retry Behavior
| Lỗi | Hành vi | Retry? |
|---|---|---|
| External API error | <hành vi thật từ code> | <Có/Không + lý do> |
| Domain exception | <message/status thật từ code> | <Có/Không + lý do> |
| ... | ... | ... |

## Những điều KHÔNG nên thay đổi
- <invariant 1 — vd: response shape phải giữ nguyên vì FE đang dùng>
- <invariant 2 — vd: enum values không được đổi tên>

> Giúp developer tránh break backward compatibility.

## Ví dụ sử dụng
```php
// Ví dụ gọi từ boundary thật của feature
$input = InputDto::fromRequest($request);
$result = $this->handler->handle($input);
return $this->jsonResponse($result, '<message thật>');
```

## Liên kết
- API docs FE: [`api-docs/<Module>/<Endpoint>.md`](../../api-docs/<Module>/<Endpoint>.md)
- Test: [`tests/Unit/<Feature>Test.php`](../../source/tests/Unit/<Feature>Test.php)
- Golden template: [`SaveZaloAccountStaff/`](../../source/src/Core/Components/OmnichannelChat/SaveZaloAccountStaff/)
```

---

## Quy tắc

1. **Suy ra từ code + test thật** — KHÔNG đoán behavior từ tên method.
2. **Ghi rõ "chưa kiểm chứng"** nếu không chắc một behavior (§0).
3. **Tiếng Việt**, trừ code snippet và tên class/method.
4. **Không lặp** thông tin đã có ở `api-docs/`.
5. Mục nào **không áp dụng** → bỏ mục đó, không để "N/A".
