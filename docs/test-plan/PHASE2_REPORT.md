# Phase 2 — Software Testing progress report

Ngày 08/10/2026. Repository `SWT301`, branch `chore/monorepo-migration`; migration và Phase 2 chưa commit/push. Phạm vi: mở rộng testing trên Razor Pages hiện tại, giữ ba .NET projects và toàn bộ business logic. Yêu cầu mới nhất cho phép tiếp tục mọi phương án đã đề xuất mà không hỏi lại; những target chưa tồn tại vẫn được ghi đúng trạng thái.

## 1. Trạng thái sáu nhóm

| Nhóm | Trạng thái thực tế | Evidence / giới hạn |
|---|---|---|
| CI/CD & reporting | IMPLEMENTED; LOCAL VERIFIED; GitHub NOT EXECUTED | Workflow, actionlint exit 0; 37 scoped cases pass local; TRX guards hoạt động. Chưa có runner run hoặc artifact GitHub để xác nhận. |
| Visual regression | COMPLETED trong môi trường Windows đã duyệt | Candidate review, baseline approval, 1/1 regression pass, 0 pixel khác biệt; negative comparer fixture bị reject. |
| Performance | CHARACTERIZATION EXECUTED | Local 1 VU/30s; HTTP latency/throughput/error được đo; acceptance thresholds trống. Không kết luận NFR-003. |
| AI-assisted testing | EXECUTED REVIEWED DEMO | Prompt/proposal, human approval, ba cases 1900, code và TRX thật. Không tuyên bố đã dùng Playwright MCP. |
| REST API testing | BLOCKED — Awaiting approved API target | Chưa có REST contract/endpoint. HTTP integration Razor Pages riêng: 4/4 pass. |
| Native mobile / Appium | BLOCKED — No approved mobile application | Chưa có app/package, platform hoặc device/emulator được xác định. Không tạo app hay cài Appium. |

Không còn câu hỏi approval cho những cấu hình đã duyệt. Các thiếu sót còn lại là target/contract hoặc môi trường đo cần dữ liệu cụ thể, không thể suy ra từ approval chung.

## 2. Audit, kiến trúc và bảo toàn

Đã đọc AGENTS, README, canonical requirements, test plans/reports, source và dependencies thực tế. Đã kiểm tra branch, worktrees, staged/unstaged migration trước Phase 2 và lưu SHA-256 snapshot. Ứng dụng dùng Razor Pages/MapRazorPages, không có REST backend và không có mobile target. Project Introduction bên ngoài đã được kiểm tra, gồm flowchart BR-001/002/003; tài liệu đó không bị sửa.

Tái sử dụng NUnit cho AI cases và Playwright/MSTest cho HTTP, candidate và regression. Ba file C# visual/HTTP được link vào project hiện có nhưng nằm trong thư mục riêng. Không thêm NuGet dependency, framework reporting, project .NET, endpoint hay feature. HTTP APIRequestContext không cần browser, và có cookie jar riêng cho mỗi test. Fixture server dùng port OS cấp và chỉ dừng process tree mà nó sở hữu.

Final validation so sánh byte hash với snapshot Phase 2 cho 26/29 files; ba files được cập nhật có chủ đích là README, guide README và Playwright csproj. Production tám files, 21 NUnit source cases, chín E2E source cases, fixture, solution, AGENTS và requirements/history giữ nguyên byte. Git index migration được so sánh nguyên trạng; các additions Phase 2 vẫn untracked và các updates vẫn unstaged. Main giữ `24b577f`. Không stage lại migration, commit, push, stash, thay baseline tự động hay xóa artifacts local.

## 3. Kết quả thực thi thật

Restore pass. Debug và Release build pass, 0 warnings, 0 errors. Whole-project discovery: NUnit **24**, Playwright/MSTest **15**. Số scoped cases được bảo vệ bằng manifest tên và TRX thực tế:

| Suite | Scoped discovered | Executed | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|---:|
| unit | 21 | 21 | 21 | 0 | 0 |
| web-e2e | 9 | 9 | 9 | 0 | 0 |
| ai-assisted | 3 | 3 | 3 | 0 | 0 |
| http-integration | 4 | 4 | 4 | 0 | 0 |
| Approved visual regression | 1 | 1 | 1 | 0 | 0 |

Tổng các suite CI local: **37/37 pass**. Thêm visual regression: **38/38 pass**. Candidate preparation đã chạy riêng **1/1 pass** trước approval, không tính là thêm một regression gate. Không đo coverage và không suy ra đầy đủ requirement coverage từ các counts.

Guard self-checks: 10/10 hoạt động đúng (valid evidence được accept; missing TRX, zero, failed, skipped, renamed, duplicate, nonzero exit, missing discovery, stale run bị reject). Đây là fixture hạ tầng có chủ đích, không phải test kết quả sản phẩm. YAML actionlint v1.7.12 exit 0. Chưa chạy GitHub Actions; local validation không xác nhận một pipeline trên GitHub thành công.

Visual: Windows 10.0.19045, Playwright 1.55.0 / Chromium 140.0.7339.16, headless 1280×720, scale 1, Arial hash, en-US, Asia/Bangkok, light, fonts/images awaited, animations disabled. User approval: “Duyệt baseline và chính sách 0 pixel cho môi trường này”. Baseline image SHA-256 `9d35646748ffc9c0b331d8e32b4c05f31007a41187a7289a6833011fc10ffb34`. Actual giống baseline: **0 changed pixels**. Windows 2025/Linux cần baseline riêng; CI hiện chỉ chạy bốn scoped suites được chỉ định.

## 4. Performance measurements

Run ID `ed22cea5f32545e2a9f774d33eb9e6dc`; portable k6 v2.3.0 verified bằng official release checksum. Local Release server riêng, Development mode, logging Default Warning/lifetime Information. Workload **1 VU/30s**, closed loop, không think time; mỗi iteration GET → Check → Clear. Không chạy song song với các .NET test suites. Token/cookies antiforgery thật được dùng. Server đã dừng, exit k6 0.

- HTTP requests: **33,924**, rate **1130.67 requests/s**.
- Iterations: **11,308**, rate **376.89/s**.
- HTTP error rate: **0%**; workflow error rate: **0%**.
- Functional checks: **90,464 passed**, **0 failed**; đây không phải số test cases.

| HTTP workflow | Avg ms | Median ms | p95 ms | p99 ms | Max ms |
|---|---:|---:|---:|---:|---:|
| GET | 0.4408 | 0.5234 | 1.0565 | 1.2973 | 15.2591 |
| Check POST | 0.5109 | 0.5469 | 1.1218 | 1.4558 | 14.5473 |
| Clear POST | 0.5075 | 0.5451 | 1.1116 | 1.4609 | 27.5277 |

HTTP metrics không bao gồm browser render/interaction. Empty thresholds có nghĩa chưa có performance verdict. Những số trên chỉ mô tả một lần chạy local với workload cụ thể, không phải production capacity hoặc chứng nhận NFR-003 phản hồi một giây sau click. Giá trị minimum 0ms có thể xuất hiện trong measurements với độ phân giải timer local; không được hiểu là request không tốn thời gian. Trong k6 Rate metrics, `httpErrors.passes=0` là số sample lỗi=true, còn `fails=33924` là sample lỗi=false; `rate=0` là 0% lỗi, không phải 33.924 HTTP failures.

## 5. Files changed trong Phase 2

| Files | Mục đích |
|---|---|
| `.github/workflows/tests.yml` | Restore/build, matching Chromium, suites, summary, upload always |
| `ci/run-tests.ps1`, `ci/summarize-tests.ps1`, `ci/test-suites.json` | Discovery, unique runs, TRX, guards, Markdown/JSON reporting |
| `tests/unit/SWT.NUnitTests/AiReviewedCenturyTests.cs` | Ba cases đã được review |
| `tests/web-e2e/DateTimeChecker.PlaywrightTests/DateTimeChecker.PlaywrightTests.csproj` | Link ba C# sources, dependencies giữ nguyên |
| `tests/integration/DateTimeCheckerHttpTests.cs` | Bốn real HTTP cases trên Razor Pages |
| `tests/visual/DateTimeCheckerVisualCandidateTests.cs`, `DateTimeCheckerVisualRegressionTests.cs`, `compare-screenshots.ps1` | Candidate capture, approved gate, exact comparer/diff |
| `tests/visual/baselines/windows-10-chromium-140/date-time-checker.png`, `approval.json` | Baseline và review/hash metadata |
| `tests/performance/date-time-checker.js`, `local-characterization.json`, `run-local.ps1`, `README.md` | k6 workload/exports/server lifecycle và hướng dẫn |
| `docs/testing-guide/ci.md`, `visual.md`, `ai-assisted.md`, `target-assessment.md` | Các guides, review records, limitations |
| `docs/test-plan/PHASE2_CASES.md`, `PHASE2_REPORT.md` | Additional cases và actual results |
| `README.md`, `docs/testing-guide/README.md` | Current commands/counts/links; không ghi đè original report/history |

## 6. Commands executed

Các lệnh dưới là mẫu tương ứng với execution thật từ repo root; local runs dùng `-ResultsDirectory` tuyệt đối vào thư mục evidence ngoài repo. PowerShell 7 dùng bundled runtime khi `pwsh` không nằm trong PATH; k6/actionlint dùng portable executable đã checksum-verify.

```powershell
dotnet restore SWT.slnx
dotnet build SWT.slnx -c Release --no-restore
dotnet build SWT.slnx -c Debug --no-restore
dotnet test tests/unit/SWT.NUnitTests/SWT.NUnitTests.csproj -c Release --no-build --no-restore --list-tests
dotnet test tests/web-e2e/DateTimeChecker.PlaywrightTests/DateTimeChecker.PlaywrightTests.csproj -c Release --no-build --no-restore --list-tests
pwsh ci/run-tests.ps1 -Suite unit
pwsh ci/run-tests.ps1 -Suite ai-assisted
pwsh ci/run-tests.ps1 -Suite http-integration
pwsh ci/run-tests.ps1 -Suite web-e2e
pwsh ci/summarize-tests.ps1
dotnet test tests/web-e2e/DateTimeChecker.PlaywrightTests/DateTimeChecker.PlaywrightTests.csproj -c Release --no-build --no-restore --filter FullyQualifiedName~DateTimeCheckerVisualRegressionTests --logger 'trx;LogFileName=visual.trx' -- Playwright.BrowserName=chromium
pwsh tests/performance/run-local.ps1 -K6Path '<actual portable k6.exe path>'
actionlint .github/workflows/tests.yml
git diff --check
git diff --cached --check
```

Candidate capture, exact comparer identical/negative self-checks, TRX guard self-checks, SHA-256/index/doc-link validation và owned-process check cũng được thực hiện. Browser matching Chromium đã cài bằng generated script của Playwright package 1.55.0; không cài browser revision tùy ý.

Một build ban đầu fail vì HTTP test dùng Dictionary cho Form và Task thay ValueTask trong Playwright 1.55. Đã sửa sang CreateFormData/await DisposeAsync, build lại thành công, rồi mới chạy và ghi kết quả bốn HTTP cases. Không skip test hoặc sửa expected/business behavior để pass. Windows comparer lần đầu gặp default script execution policy Restricted; local process dùng RemoteSigned, không thay persistent policy. Những lần thử này không bị diễn giải là successful runs.

## 7. Remaining issues và next plan

1. CI: khi migration/Phase 2 được commit và push theo một yêu cầu riêng, kiểm tra runner run thật, download artifacts, đối chiếu TRX counts/guards. Hiện không có GitHub URL/run để chứng minh pass.
2. Visual: giữ approved Windows 10 gate; nếu muốn gate trên Windows 2025/Linux, chuẩn bị candidate theo môi trường đó rồi review riêng. Không reuse baseline khác OS hoặc auto-update.
3. Performance: giữ workload characterization đã chốt. Cần môi trường, workload và phép đo browser cụ thể để đánh giá NFR-003; không tự thêm acceptance thresholds.
4. REST/API và mobile: cần concrete API contract/URL hoặc app package/platform/device để có target thật. Không có implementation bổ sung trong phạm vi hiện tại.
5. Year-range/input ambiguities và desktop-to-web discrepancy vẫn được giữ trong canonical requirements. Key cleanup từ migration không xóa history; Phase 2 không thay key hoặc history.

## 8. Evidence và đọc tiếp

Local evidence gồm TRX các scoped suites, real discovery/execution logs, summary JSON/Markdown, visual candidate/actual/diff/approval metadata, k6 measurements/summary/raw metrics/version/run metadata, guard self-check results, actionlint result và final validation. Outputs được xuất thành report và zip cùng SHA-256 manifest; generated evidence không được thêm vào Git index.

Repository guides: [CI](../testing-guide/ci.md), [visual](../testing-guide/visual.md), [AI](../testing-guide/ai-assisted.md), [API/mobile](../testing-guide/target-assessment.md), [k6](../../tests/performance/README.md), [additional cases](PHASE2_CASES.md).
