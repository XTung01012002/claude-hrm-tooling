---
name: diagnosing-bugs
description: Chẩn đoán bug một cách có hệ thống. Dùng khi user báo code chạy sai, bị lỗi, không đúng kết quả, test bị đỏ (failed), gặp exception, regression, hoặc test chạy chập chờn (flaky).
---

# Diagnosing Bugs (Chẩn đoán lỗi HRM API)

Khi bạn được yêu cầu fix một bug (code chạy sai, exception, test đỏ), **TUYỆT ĐỐI KHÔNG** nhảy vào sửa code ngay hay đoán mò. Bạn phải tuân thủ nghiêm ngặt quy trình 6 bước dưới đây.

## Ràng buộc môi trường HRM (BẮT BUỘC)
- **Môi trường:** Luôn chạy qua `Makefile.ai`. Không gọi trực tiếp `php`, `phpunit` hay `artisan` trên host.
- **Phạm vi:** Chỉ sửa các file nằm trong phạm vi của bug. Không refactor code xung quanh nếu không liên quan.
- **Behavior:** Giữ nguyên behavior hiện tại của hệ thống, trừ phần gây ra bug.

## Quy trình 6 Bước Chẩn đoán

### Phase 1: Dựng tín hiệu đỏ (Red Signal)
Trước khi đưa ra bất kỳ dự đoán nào về nguyên nhân:
1. Viết một test PHPUnit **chạy thất bại (đỏ) đúng với mô tả bug này**.
2. Chạy thử test bằng lệnh: `AI_TEST=tests/Unit/<TestFile>.php make -f Makefile.ai ai-test`.
3. Nếu bạn không thể tạo ra tín hiệu đỏ (test vẫn xanh), **bạn không được phép sửa code ứng dụng**. Thay vào đó, hãy xem lại Phase 2 hoặc hỏi thêm user.

### Phase 2: Repro & Thu nhỏ (Minimization)
1. Rút gọn scenario gây lỗi về trạng thái nhỏ nhất có thể mà vẫn giữ được tín hiệu đỏ.
2. Bỏ dần các yếu tố không cần thiết (các mock không liên quan, các dữ liệu thừa) trong test case.

### Phase 3: Giả thuyết (Hypotheses)
1. Viết ra **3–5 giả thuyết xếp hạng** theo độ khả thi.
2. Mỗi giả thuyết phải được phát biểu dưới dạng có thể kiểm chứng (falsifiable). Ví dụ: *"Nếu X là nguyên nhân, thì việc thay đổi Y thành Z sẽ làm cho bug biến mất"*.
3. **Chưa được sửa code thật** ở bước này.

### Phase 4: Instrument (Đo đạc & Gắn probe)
1. Mỗi probe (như `Log::debug()`, `dump()`) chỉ được gắn với đúng 1 dự đoán ở Phase 3.
2. Sử dụng tag riêng cho log (VD: `Log::debug('[BUG-123] ...')`) để sau này dọn dẹp dễ dàng.
3. Nếu là bug liên quan đến hiệu năng, hãy đo đạc baseline trước khi thử sửa.

### Phase 5: Fix & Regression Test
1. Xác định seam (điểm nối nơi bug thực sự phát sinh trong luồng thực thi tự nhiên) và đảm bảo test bao phủ đúng call site đó. Test phải có **trước** khi fix.
2. Tiến hành sửa code để fix bug.
3. Chạy lại test PHPUnit: `AI_TEST=... make -f Makefile.ai ai-test`. Test lúc này phải chuyển sang **Xanh (Pass)**.
4. Chạy toàn bộ suite liên quan: `AI_FILE=source/src/... make -f Makefile.ai ai-test` để đảm bảo không bị regression.

### Phase 6: Dọn dẹp & Review
1. Gỡ bỏ toàn bộ instrument (log, dump) đã thêm ở Phase 4.
2. Chạy `ai-lint` và `ai-pint` cho file vừa sửa.
3. Đề xuất các thay đổi nhỏ về kiến trúc hoặc naming (nếu cần) để phòng tránh bug tương tự tái diễn trong tương lai.
