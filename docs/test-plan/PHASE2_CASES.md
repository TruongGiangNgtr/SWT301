# Phase 2 additional automated cases

Date: 2026-10-08. The original 21 NUnit and 9 Playwright cases in TEST_CASES.md are preserved. Canonical requirements have not changed. These cases are separate extensions or implementation checks.

| Case / source | Test input and assertion | Basis |
|---|---|---|
| AI-01 / AiReviewedCenturyTests | DayInMonth(1900,2) equals 28 | Approved BR-001/002 example |
| AI-02 / AiReviewedCenturyTests | IsValidDate(1900,2,28) equals true | Approved BR-003 month end |
| AI-03 / AiReviewedCenturyTests | IsValidDate(1900,2,29) equals false | Approved BR-003 day beyond month end |
| HTTP-01 / DateTimeCheckerHttpTests | GET root, CSS, logo return 200; content exists | Current Razor Pages/static asset behavior |
| HTTP-02 / DateTimeCheckerHttpTests | GET actual CSRF token/cookie; POST Check 29/02/2000 returns 200 and existing success message | Existing valid-date workflow |
| HTTP-03 / DateTimeCheckerHttpTests | GET actual token/cookie; POST Clear returns 200 and three blank fields | Existing Clear workflow |
| HTTP-04 / DateTimeCheckerHttpTests | Isolated context POST without CSRF token returns 400 | Existing antiforgery protection; implementation check |
| VIS-01 / DateTimeCheckerVisualRegressionTests | Approved fixed Windows screenshot equals baseline at every RGBA pixel | Human-reviewed rendering baseline, separate from functional requirements |

VisualCandidate prepares candidate/repeat images for review and is not counted as a regression case. The local k6 workload measures GET → Check → Clear with actual tokens/cookies; its response checks are not separate NUnit/MSTest cases, and its observed timings are not expected results.

Execution and evidence are recorded in [Phase 2 report](PHASE2_REPORT.md). For review records, see [AI demo](../testing-guide/ai-assisted.md), [visual policy](../testing-guide/visual.md), and [target assessment](../testing-guide/target-assessment.md).
