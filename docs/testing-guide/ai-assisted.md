# Executed AI-assisted test authoring demo

This is an actual requirement → AI proposal → human review → generated NUnit code → local execution demo from this session. Playwright MCP was not configured or used. No separate AI account, MCP service or autonomous browser-agent capability is claimed.

## Prompt and evidence trail

The user's Phase 2 prompt, headed “ROLE — Senior Software Test Automation Engineer & .NET Architect”, requested AI requirement analysis, proposed cases, engineer review of assertions, real execution, and limitations. Its relevant instruction was: “Không đánh đồng AI-generated test với một test đã được xác minh.” The session analyzed canonical BR-001/002/003 and verified the leap-year flowchart in the external Project Introduction. The following is the exact review proposal sent in the session, not a fabricated second model invocation:

> Demo AI-assisted: bạn có duyệt bổ sung case riêng cho tháng 2 năm 1900: DaysInMonth=28, ngày 28 hợp lệ, ngày 29 không hợp lệ không? Những kết quả này bám flowchart BR-001/002/003 đã xác minh. Tôi sẽ giữ nguyên 21 cases cũ, ghi prompt/proposal/review và chạy cases mới riêng sau khi bạn duyệt.

Human response: **“Duyệt 3 cases năm 1900 cho demo AI”**. The user subsequently authorized continuing the proposed work without further questions. Review date: 2026-10-08.

## Accepted cases and reviewed expectations

| Test name | Input / assertion | Basis and review rationale |
|---|---|---|
| AiReviewed_February1900_Has28Days | DayInMonth(1900, 2) = 28 | BR-001/002: divisible by 100, not 400 |
| AiReviewed_February28_1900_IsValid | IsValidDate(1900, 2, 28) = true | BR-003: valid month and day at month end |
| AiReviewed_February29_1900_IsInvalid | IsValidDate(1900, 2, 29) = false | BR-003: day exceeds 28 |

Source: `tests/unit/SWT.NUnitTests/AiReviewedCenturyTests.cs`. Names, inputs and assertions can be inspected independently. They complement the existing leap-year cases without changing any of the original 21 cases or DateValidator.

No proposed case was recorded as human-rejected in this demo. Year-range interpretations, whitespace handling and desktop-only behavior were excluded from the proposal because their requirements remain ambiguous or conflict with this web implementation; they are not invented “rejected” approvals. Approval of these three cases does not resolve those ambiguities.

## Run and outcome

```powershell
pwsh ci/run-tests.ps1 -Suite ai-assisted -Configuration Release
```

Release execution: 3 discovered for the scoped run, 3 executed/passed, 0 failed, 0 skipped. The unit project's discovery output lists 24 cases overall. TRX and discovery/execution logs are retained by the CI script. The Phase 2 report links the actual local evidence. This demonstrates one reviewed authoring cycle, not general AI accuracy, exhaustive coverage or an independently run human code review.

AI can invent expected results, miss source contradictions, duplicate existing tests, or generate framework-incompatible code. The session caught and repaired a Playwright API mismatch during compilation of the separate HTTP tests before their successful execution. Human approval, traceability, code inspection, actual build/test output and unmodified production logic remain necessary. Model output alone is never test evidence.
