---
description: Sinh unit test PHPUnit + Mockery (AAA) cho class chỉ định vào source/tests/Unit/
---

Đọc `docs/ai/PROJECT-CONVENTIONS.md` §6 rồi `docs/ai/prompts/generate-test.md` và thực thi đúng prompt đó.

Class cần test: đường dẫn class nêu trong yêu cầu (tham số `$ARGUMENTS`, thường là `*Handler`); nếu chưa nêu rõ thì HỎI lại, đừng tự đoán.

Bắt buộc bám code thật: đọc class + các interface dependency để mock đúng method/đối số; phủ happy-path + từng nhánh `BusinessException`. Ghi vào `source/tests/Unit/<ClassName>Test.php` theo AAA, tên `test_<scenario>_<outcome>`. Kiểm chứng bằng Docker: `AI_TEST=tests/Unit/<ClassName>Test.php make -f Makefile.ai ai-test`.
