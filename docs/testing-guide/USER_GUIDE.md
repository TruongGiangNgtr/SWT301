# SWT301 — Hướng dẫn sử dụng và demo testing

Cập nhật 08/10/2026. Chạy các lệnh từ **repository root** chứa `SWT.slnx`. Đây là hướng dẫn mới duy nhất của Phase 3. Tài liệu Phase 2 giữ làm snapshot lịch sử; trạng thái hiện tại xem mục 17 và machine-readable artifacts.

## 1. Giới thiệu và tám nhóm testing

DateTimeChecker nhập Day/Month/Year, Check và Clear. Website dùng ASP.NET Core Razor Pages/.NET 10. Android native gọi REST API; API gọi **DateValidator hiện có**, không sao chép thuật toán Gregorian sang Java.

| Nhóm | Công cụ | Demo |
|---|---|---|
| Unit | NUnit | Month lengths, leap-year/date boundaries |
| API | Playwright APIRequestContext/MSTest; Postman/Newman | Status, JSON, positive/negative/boundaries |
| Web E2E | Playwright .NET/MSTest | Browser thật, input, Check/Clear |
| Mobile | Appium 2.19.0 / UiAutomator2 4.2.9 | Native Android controls trên emulator |
| Performance | k6 2.3.0 | HTTP load/stress nhẹ và demo thresholds |
| Visual | Playwright + exact RGBA comparer | Baseline/actual/diff cùng môi trường |
| AI-assisted | Reviewed NUnit authoring | Proposal → review → script → real execution |
| CI/CD | GitHub Actions, TRX/JSON/artifacts | Restore/build/discovery/guards/upload |

HTTP integration Razor Pages là suite riêng, không phải REST API testing. API và Android là demo extensions được phép ở Phase 3; không sửa requirement gốc hoặc tuyên bố toàn bộ desktop specification đã đạt.

## 2. Kiến trúc và source/test

```text
apps/web/                  Razor Pages, DateValidator, Api/DateApi.cs
apps/mobile/               Native Java Android app, Gradle 8.9 wrapper
tests/unit/SWT.NUnitTests/  Original 21 + AI-reviewed 3
tests/api/                 API tests, contract.json, Postman collection, Newman package/lock
tests/integration/         Razor Pages HTTP integration (4)
tests/web-e2e/             Existing Playwright project, nine E2E cases, server fixture
tests/visual/              Candidate, gate, comparer, reviewed baselines
tests/performance/         k6 script/configs, managed local server
tests/mobile-e2e/          Appium package/lock, native Python unittest
ci/                       Manifest, discovery/TRX scripts, Newman/mobile runners
.github/workflows/        tests.yml, mobile.yml, performance.yml
reports/performance/      Actual retained Phase 2/3 measurements (JSON)
reports/verification.json Verified execution references (JSON)
docs/testing-guide/USER_GUIDE.md
SWT.slnx                  Three existing .NET projects
```

API/HTTP/visual C# sources được link vào project Playwright; Android ngoài .slnx. NUnit whole-project discovery: **24**; browser project: **34** (9 E2E + 4 HTTP + 19 API + 1 visual + 1 candidate generator). CI chọn **57 .NET cases**, không chạy candidate preparation như một regression gate. Native suite có **5 cases**. Chạy lặp lại cùng case, hay chạy cùng contract qua Newman, không tạo thêm cases.

## 3. Prerequisites

| Software | Mục đích |
|---|---|
| Git, .NET 10 SDK | Restore/build/run/test |
| PowerShell 7 (`pwsh`), Windows PowerShell (`powershell.exe`) | Scripts; System.Drawing comparer |
| Node.js 22 LTS, npm | Newman và Appium |
| Python 3.10+ trong PATH (`python`) | Stdlib process runners; không cần pip packages |
| Chromium matching Playwright 1.55.0 | Cài bằng generated browser script |
| k6 2.3.0 | Performance |
| Postman desktop, tùy chọn | UI import/Collection Runner |
| JDK 17, Android Studio/SDK, Emulator | Chỉ cần cho Android local |

Lệnh `pwsh/python/node/npm/k6` giả định prerequisites đã cài và PATH đúng. Session local dùng bundled executable paths cụ thể. Java/Android SDK/emulator chưa có trên Windows local; native được kiểm chứng bằng GitHub Ubuntu 24.04/API 35 emulator. Các lệnh Android Windows dưới đây là hướng dẫn tái lập, **chưa chạy local**.

```powershell
dotnet --info
pwsh --version
python --version
node --version
npm --version
```

Không dùng AI service/Appium cloud trả phí, larger runners hoặc secret mới. Workflows dùng standard runners của public repository.

## 4. Restore/build

```powershell
dotnet restore SWT.slnx
dotnet build SWT.slnx -c Release --no-restore
```

`--no-build` yêu cầu build cùng configuration. Debug hỗ trợ bằng `-c Debug` với browser script tương ứng. DateValidator, page UI/handlers và canonical requirements giữ nguyên. API Year 1000–3000 là current implementation/demo policy, không giải quyết ambiguity gốc về field range.

## 5. Website

```powershell
dotnet run --project apps/web/SWT.csproj -c Release --no-build --no-launch-profile -- --urls http://127.0.0.1:5080
```

Mở `http://127.0.0.1:5080`; thử 29/02/2000, 29/02/1900 và Clear. Ctrl+C dừng server terminal này. Local data-protection keys được ignore, không upload keys.

Managed test runners tự khởi chạy/dừng server riêng. Newman dùng port 5081; mobile dùng 5080. Dừng website trước mobile runner để tránh xung đột; không kill tất cả dotnet/node processes.

## 6. NUnit

```powershell
pwsh ci/run-tests.ps1 -Suite unit -Configuration Release
pwsh ci/run-tests.ps1 -Suite ai-assisted -Configuration Release
dotnet test tests/unit/SWT.NUnitTests/SWT.NUnitTests.csproj -c Release --no-build --list-tests
```

`unit` chọn 21 cases gốc; `ai-assisted` chọn ba reviewed cases 1900. Adapter discovery có thể liệt kê cả 24 dù class filter; script xác minh tên scoped cases và actual filtered TRX. Exit discovery 0 không đồng nghĩa test pass.

## 7. API và Postman

Contract **POST /api/dates/check**, numeric JSON integers `day/month/year`. Khi website đang chạy, ví dụ PowerShell:

```powershell
$body = @{ day = 29; month = 2; year = 2000 } | ConvertTo-Json
Invoke-RestMethod -Uri http://127.0.0.1:5080/api/dates/check -Method Post -ContentType application/json -Body $body
```

Response gồm day/month/year, boolean isValid, daysInMonth và message dd/mm/yyyy. 31/04/2024 trả **200/isValid=false**; day 32 trả **400**. 400 cho missing/null/malformed/non-integer/range errors với problem JSON; 415 unsupported media type; GET 405. JSON string `"29"` không thay numeric 29. Chi tiết `tests/api/contract.json`. API stateless không lưu state; Razor Pages CSRF vẫn bật.

```powershell
pwsh ci/run-tests.ps1 -Suite api
npm ci --prefix tests/api
python ci/run-postman.py
```

API suite có 19 cases. Newman runner start server 5081, chạy collection thật, xuất `TestResults/postman/newman.json`, run.json và logs. Kết quả: 19 requests/61 assertions; không cộng assertions thành test cases.

Postman UI: import `tests/api/DateTimeChecker.postman_collection.json`, collection variable `baseUrl=http://127.0.0.1:5080`, start website rồi Collection Runner → Run toàn bộ requests. UI chưa được điều khiển trong session; **collection đã verified bằng Newman thật**, local và GitHub.

## 8. Browser E2E và HTTP integration

```powershell
pwsh tests/web-e2e/DateTimeChecker.PlaywrightTests/bin/Release/net10.0/playwright.ps1 install chromium
pwsh ci/run-tests.ps1 -Suite web-e2e
pwsh ci/run-tests.ps1 -Suite http-integration
```

E2E 9 cases dùng browser thật. HTTP 4 cases kiểm tra page/static assets, real token/cookie-bound Check/Clear và POST thiếu CSRF bị 400. Fixture chọn port loopback OS cấp, readiness timeout và cleanup owned process. Full project có 34 cases gồm visual/candidate; dùng filters đúng suite, không giả định full run chỉ có chín E2E.

## 9. Visual regression

Hai reviewed baselines tách biệt:
- `windows-10-chromium-140`: Windows 10.0.19045, user duyệt Phase 2.
- `windows-2025-chromium-140`: GitHub windows-2025, runtime OS description Microsoft Windows 10.0.26100; delegated technical review Phase 3 sau inspect candidate và repeat 0 pixel.

Cùng Playwright 1.55.0/Chromium 140.0.7339.16, headless 1280×720, scale 1, Arial, en-US, Asia/Bangkok, light, fonts/images awaited, animations disabled/caret hidden. Test kiểm tra OS/browser/font hash/image hash; **0 RGBA pixel differences**, không auto-update. Runtime 10.0.26100 là runner Windows 2025, không phải baseline Windows 10 local.

Local approved Windows 10:

```powershell
$env:SWT_VISUAL_BASELINE = 'windows-10-chromium-140'
pwsh ci/run-tests.ps1 -Suite visual
Remove-Item Env:SWT_VISUAL_BASELINE
```

CI chọn Windows 2025 baseline. Xem `TestResults/ci/visual/<run-id>/visual/actual.png`, `diff.png`, `comparison.json` và TRX ở run folder. Magenta là pixels khác; phần giống màu xám. Comparer dùng Windows PowerShell/System.Drawing và process RemoteSigned; không thay system policy.

Candidate preparation để review môi trường mới:

```powershell
$env:SWT_VISUAL_OUTPUT = Join-Path (Get-Location) 'TestResults/visual-candidate'
dotnet test tests/web-e2e/DateTimeChecker.PlaywrightTests/DateTimeChecker.PlaywrightTests.csproj -c Release --no-build --no-restore --filter FullyQualifiedName~DateTimeCheckerVisualCandidateTests --logger 'trx;LogFileName=candidate.trx' --results-directory $env:SWT_VISUAL_OUTPUT -- Playwright.BrowserName=chromium
Remove-Item Env:SWT_VISUAL_OUTPUT
```

Inspect UI dự kiến, kiểm tra repeat stability và ghi review metadata trước manual baseline replacement. Không copy baseline giữa OS hoặc sửa ảnh để che regression. Linux chưa có approved baseline.

## 10. k6 performance

```powershell
pwsh tests/performance/run-local.ps1 -K6Path k6
pwsh tests/performance/run-local.ps1 -K6Path k6 -WorkloadFile tests/performance/demo-load.json
pwsh tests/performance/run-local.ps1 -K6Path k6 -WorkloadFile tests/performance/demo-stress.json
```

| Profile | Workload | Demo thresholds |
|---|---|---|
| characterization | 1 VU/30s | Không acceptance thresholds |
| load | 3 VUs/30s, closed loop | Errors=0, checks=100%; GET/Check/Clear p95<100ms, p99<250ms |
| stress demo | 0→2→4→8→0 VUs, mỗi stage 5s | Errors=0, checks=100%; p95<200ms, p99<500ms |

Budgets dựa trên Phase 2 local p95 khoảng 1.1ms ở 1 VU, chừa overhead concurrency/instrumentation cho demo. **Không phải NFR-003**. Stress cap tám VUs, chưa tìm saturation/capacity. Chỉ loopback, redirects tắt. Workflow GET → Check → Clear xử lý real tokens/cookies. Logging Warning/lifetime Information, Development và raw output collection là measurement context.

Outputs mỗi run: workload.json, measurements.json, summary.json, raw metrics.json, version/logs, run.json/cleanup. `thresholdResults.<metric>.<expression>.ok` và k6 exit code cho biết demo pass/fail; đừng tăng thresholds chỉ để pass. Rate error `passes` là samples true, `fails` là samples false, nên rate=0 là 0% lỗi. Min 0ms có thể do timer resolution. Functional checks không phải số NUnit/MSTest cases.

Phase 2 measurements giữ tại `reports/performance/phase2-characterization.json`; load/stress tại phase3-load.json/phase3-stress.json. HTTP latency không bao gồm browser render và click-to-result. **NFR-003 một giây chưa verified**, cần browser measurement/environment/workload riêng.

## 11. Android/Appium

**Native APK build và năm Appium cases đã chạy trên GitHub Ubuntu/API 35 emulator thật. Windows local thiếu JDK/SDK/emulator; các lệnh Windows sau chưa chạy local.**

Cài JDK 17, Android Studio; SDK Manager cài Platform 35, Build Tools, Platform Tools, Emulator. Device Manager tạo/start Pixel 2 Google APIs API 35 x86_64 AVD. Đặt JAVA_HOME/ANDROID_HOME đúng paths; thêm Java/platform-tools vào PATH. Gradle wrapper 8.9 distribution checksum pinned; Android plugin 8.7.3.

```powershell
.\apps\mobile\gradlew.bat -p apps/mobile --no-daemon assembleDebug
adb devices
adb install -r apps/mobile/app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.swt301.datetimechecker/.MainActivity
```

App nhập Day/Month/Year, Check/Clear, API URL mặc định `http://10.0.2.2:5080` (emulator truy cập host). Calendar logic đến từ API. App chỉ nhận local URLs; cleartext cho phép riêng 10.0.2.2/127.0.0.1/localhost, không bật toàn cục cho public hosts.

Sau khi .NET Release và APK build, emulator boot:

```powershell
npm ci --prefix tests/mobile-e2e
$env:APPIUM_HOME = Join-Path (Get-Location) '.appium'
node tests/mobile-e2e/node_modules/appium/index.js driver install uiautomator2@4.2.9
$env:ANDROID_SERIAL = 'emulator-5554'
python ci/run-mobile.py
```

Chọn serial đúng từ adb devices. Runner start owned API 5080/Appium 4723, wait readiness, set absolute APK path, chạy Python unittest qua **Appium W3C protocol/UiAutomator2 thật**, không cần Python client package. Cleanup chỉ API/Appium owned processes, để emulator của bạn chạy.

Cases: launch/controls, non-integer validation, valid 29/02/2000, invalid 29/02/1900, Clear. `TestResults/mobile/results.json`, per-case screenshots, execution/API/Appium logs và run.json. Init không chạy case được ghi EnvironmentBlocked; không tính thành passed. GitHub artifact có debug APK; source không chứa keystore/private key. Chưa kiểm chứng iOS, physical-device variant hoặc Android Windows local.

## 12. AI-assisted demo

Proposal thực tế Phase 2: February 1900 có 28 ngày; ngày 28 valid, 29 invalid theo BR-001/002/003. Human response thực tế: **“Duyệt 3 cases năm 1900 cho demo AI”**. Source `AiReviewedCenturyTests.cs` có ba assertions; Phase 3 chạy lại.

Mở canonical leap-year flowchart → giải thích divisible by 100 nhưng không 400 → inspect generated assertions → execute:

```powershell
pwsh ci/run-tests.ps1 -Suite ai-assisted
```

Đối chiếu TRX. Không case nào trong proposal này được human-rejected; input/year ambiguities và desktop behavior không biến thành expected results mới. Không tuyên bố Playwright MCP/AI tool ngoài đã được dùng.

Failure analysis thật: Phase 2 sửa Form/ValueTask framework mismatch sau build failure; Phase 3 sửa CP1252/UTF-8 trong Newman Windows runner rồi chạy lại. AI có thể invent requirements, sai framework API, duplicate cases hoặc viết assertions tự khớp implementation. Review/source/build/execution độc lập vẫn cần; không bịa AI accuracy/coverage.

## 13. GitHub Actions

`tests.yml`: Windows 2025, restore/build, six scoped suites (57 cases), Newman, matching browser, approved visual gate, summary/upload. `mobile.yml`: Ubuntu 24.04, Java/Gradle/APK, Appium/driver, Android emulator và screenshots/APK. `performance.yml`: checksum-verified k6, owned loopback load/stress.

Actions pin SHA, contents read, checkout không persist credentials; không deploy/merge. tests chạy push main/chore branches hoặc PR main; mobile/performance push chỉ khi paths tương ứng thay đổi; cả ba có workflow_dispatch.

GitHub → Actions → workflow → Run workflow → chọn feature branch nếu UI cho phép; manual UI availability phụ thuộc workflow file trên default branch. **Session này trigger bằng push feature branch**, không merge main để chạy workflow. Không ghi một dispatch CLI chưa thực thi thành command verified.

## 14. Reports/artifacts

```powershell
pwsh ci/summarize-tests.ps1
```

Chạy sau cả sáu scoped suites trong cùng results root. Summary kiểm tra fresh run IDs/names/TRX/counters; zero, missing, stale, failed, skipped hoặc renamed/duplicate evidence không pass. `TestResults/ci/summary-all.json/.md` là output tự sinh, không phải manual Phase 3 report. TRX: `<suite>/<run-id>/tests.trx`, metadata latest.json.

GitHub completed run → Jobs/steps → Artifacts: test-evidence-* (TRX/discovery/logs/Newman/actual/diff), android-appium-* (native results/screenshots/debug APK), k6-local-* (metrics/thresholds/cleanup). Retention 14 ngày; tải trước expiry. Summary/upload dùng always để giữ available evidence sau failure; terminated runner có thể chưa upload xong. Không upload keys, .appium, node_modules hay debug keystore.

`reports/verification.json` chứa actual run references/status; `reports/performance/*.json` là measurements, không phải yêu cầu performance suy ra tự động.

## 15. Troubleshooting

| Lỗi | Khắc phục |
|---|---|
| pwsh/python/npm not found | Cài prerequisites, mở terminal mới, kiểm tra PATH/absolute executable |
| --no-build thiếu assembly | Build đúng configuration trước |
| Browser thiếu | Generated Release playwright.ps1 install chromium |
| Zero/summary failure | Đối chiếu manifest/discovery/TRX; không skip/đổi counts để pass |
| OS/browser/font baseline mismatch | Đúng reviewed environment, hoặc capture/review baseline mới |
| Pixels changed | Inspect baseline/actual/diff, tìm UI/environment cause; không auto-update |
| Comparer Restricted | Process RemoteSigned như runner; không đổi system policy |
| Ports occupied | Dừng server demo của bạn trước wrapper; không kill all dotnet/node |
| Newman Windows Unicode | Dùng runner explicit UTF-8 đã sửa |
| API 400 | Numeric integers, đủ fields, đúng ranges; string không thay number |
| Android SDK/JDK thiếu | Verified GitHub workflow hoặc cài prerequisites; không giả native pass |
| API unreachable từ emulator | Host API 5080 sẵn sàng, URL 10.0.2.2, xem API logs |
| Appium không thấy device | adb devices, boot/unlock, serial/JAVA_HOME/ANDROID_HOME/driver đúng |
| k6 thresholds fail | Xem ok=false/exit/log/workload; ghi actual failure, không tăng ngưỡng để che lỗi |
| Job queued/cancelled | Chờ runner; cancelled bởi newer push không phải pass |

Current tests không chứng minh full desktop conformance hoặc coverage percentage. Range-field ambiguity/desktop close behavior vẫn trong canonical requirements. Keys từng tồn tại trong Git history không bị xóa bằng Phase 3; không rewrite history hay merge main.

## 16. Quick demo cho giảng viên

Sau prerequisites, từ repository root trên approved Windows local:

```powershell
dotnet restore SWT.slnx
dotnet build SWT.slnx -c Release --no-restore
pwsh tests/web-e2e/DateTimeChecker.PlaywrightTests/bin/Release/net10.0/playwright.ps1 install chromium
pwsh ci/run-tests.ps1 -Suite unit
pwsh ci/run-tests.ps1 -Suite ai-assisted
pwsh ci/run-tests.ps1 -Suite api
pwsh ci/run-tests.ps1 -Suite http-integration
pwsh ci/run-tests.ps1 -Suite web-e2e
pwsh ci/run-tests.ps1 -Suite visual
pwsh ci/summarize-tests.ps1
npm ci --prefix tests/api
python ci/run-postman.py
pwsh tests/performance/run-local.ps1 -K6Path k6 -WorkloadFile tests/performance/demo-load.json
```

Visual trên Windows 2025 chọn baseline tương ứng; Linux không có approved baseline. Native khi local chưa có SDK: mở actual Android workflow/results/screenshots, tải APK; không giả vờ chạy Windows native. Khi local sẵn sàng, theo mục 11 rồi chạy python ci/run-mobile.py.

## 17. Trạng thái kiểm chứng thực tế

| Suite | Scoped discovered | Executed | Passed | Failed | Skipped | Environment verified |
|---|---:|---:|---:|---:|---:|---|
| unit | 21 | 21 | 21 | 0 | 0 | Windows 10 local + GitHub Windows 2025 |
| web-e2e | 9 | 9 | 9 | 0 | 0 | Windows 10 local + GitHub Windows 2025 |
| ai-assisted | 3 | 3 | 3 | 0 | 0 | Windows 10 local + GitHub Windows 2025 |
| http-integration | 4 | 4 | 4 | 0 | 0 | Windows 10 local + GitHub Windows 2025 |
| api | 19 | 19 | 19 | 0 | 0 | Windows 10 local + GitHub Windows 2025 |
| visual | 1 | 1 | 1 | 0 | 0 | Windows 10 local + GitHub Windows 2025 |
| Native mobile | 5 | 5 | 5 | 0 | 0 | GitHub Ubuntu 24.04 / Android API 35 emulator |

**57/57 .NET + 5/5 native cases pass**, không cộng repeated runs. Whole-project .NET discovery 24+34 gồm candidate preparation không chọn ở CI. Newman: 19 requests/61 assertions, 0 failures local và GitHub. Builds Debug/Release local pass (0 warnings/errors); native APK build trên GitHub pass. Visual local và Windows 2025 runner đều 0 changed pixels.

Actual verified runs:
- [.NET/TRX/Newman/approved visual gate](https://github.com/TruongGiangNgtr/SWT301/actions/runs/37754159951), commit f56b54f; artifacts đã tải và SHA-256 verified.
- [Native Android/Appium](https://github.com/TruongGiangNgtr/SWT301/actions/runs/37753092998), commit 1330212; năm assertions cases thực thi trên emulator, APK/screenshots đã kiểm tra.
- [k6 load/stress](https://github.com/TruongGiangNgtr/SWT301/actions/runs/37753093168), commit 1330212; actual thresholdResults đều ok, 0% HTTP/workflow errors.

Local load: 96,612 requests, ~3,219.94 requests/s, Check p95 ~1.091ms. Local stress: 52,269 requests, ~2,613.33 requests/s, Check p95 ~1.996ms. GitHub load/stress requests lần lượt 110,001/36,864, demo thresholds pass. Không diễn giải throughput giữa machines như benchmark tương đương. Raw counts và timing chính xác ở JSON artifacts.

Các run references là source/test commits đã đo, không tự gắn results cũ vào mọi future commit. Final guide/docs commit không thay app/mobile test scenarios. Một job trước bị cancelled khi newer push xuất hiện không được tính pass.

Không cộng repeated runs thành cases mới hoặc cộng Newman assertions vào NUnit/MSTest. Android Windows local vẫn environment blocked, nhưng native category đã verified trên GitHub emulator thật. NFR-003 click-to-result **NOT VERIFIED**. Postman UI import/Runner chưa được thao tác; cùng collection đã verified bằng Newman.
