# Interactive Console Test Runner

## Web dashboard (approved extension, 29/10/2026)

Chạy project `apps/web/SWT.csproj` bình thường trên Windows (Visual Studio
Run/F5 hoặc `dotnet run --project apps/web/SWT.csproj`) để mở đồng thời console
chọn topic 1–8 và `http://127.0.0.1:5090/dashboard`. Double-click
**`run-dashboard.cmd`** hoặc **`run-tests.cmd`** không có tham số cũng mở cùng
workspace. Dashboard là trang riêng; `/` vẫn là Date Time Checker.

Console và web dùng chung queue: chọn test ở console thì dashboard hiện cùng
run ID, tiến trình và kết quả. Console mặc định bật cửa sổ Chromium/Android;
checkbox trên web áp dụng cho lượt chạy được bắt đầu từ web. Nhập `0` thoát
menu và dừng server do cửa sổ workspace đó sở hữu. Nếu có lượt test đang chạy
từ web, hãy chờ nó xong trước khi đóng workspace. Khi mở workspace lần hai,
launcher tái sử dụng dashboard tương thích đang chạy; thoát cửa sổ thứ hai
không dừng server thuộc cửa sổ đầu tiên. Không dừng server lạ chỉ vì trùng port.

Advanced: `run-dashboard.cmd -DashboardOnly` mở riêng dashboard.
`pwsh -File ci/test-menu.ps1` mở console riêng. Các lệnh unattended như
`run-tests.cmd -Run unit` giữ nguyên chế độ chạy một lần và không tự mở web.
Server do các test khởi động luôn có tham số `--urls`, nên không mở thêm menu
hay trình duyệt. Có thể dùng `--web-only` để bỏ qua workspace khi chạy server
thủ công. Bootstrap ban đầu bàn giao sang cửa sổ workspace rồi kết thúc để
giải phóng build outputs trên Windows; đóng workspace bằng `0` hoặc Ctrl+C.

- Dashboard có 8 topic và HTTP integration, nút chạy từng suite, chọn Newman
  hoặc Playwright API, chọn profile k6 và chạy toàn bộ local suites.
- Hiển thị hàng đợi, suite đang chạy, log, kết quả thực từ `session.json`,
  counts, metrics và link tới báo cáo. Các trạng thái không có evidence không
  được hiển thị là pass. Kết quả lịch sử là báo cáo local, không phải cam kết
  môi trường hiện tại đã được kiểm tra lại.
- Checkbox **Hiện cửa sổ E2E & Android** mặc định bật. E2E mở Chromium với
  thao tác chậm 150 ms để dễ theo dõi; Android mở cửa sổ emulator khi runner
  khởi động AVD. Nếu dùng emulator đã chạy ẩn trước đó, checkbox không biến
  tiến trình đó thành một cửa sổ mới. Tắt emulator đó trước để runner tự mở.
- Mobile cài lại APK vừa build bằng `adb install -r` trước khi chạy Appium,
  tránh việc Appium giữ ứng dụng cũ khi versionCode không đổi.
- Không nhúng hay stream màn hình thiết bị vào dashboard. Cửa sổ trình duyệt
  và emulator mở riêng trên cùng máy, đóng khi lượt chạy do runner sở hữu kết thúc.
- CI/CD mở GitHub Actions; không dispatch, push hay merge tự động. Chạy tất
  cả local không chạy workflow remote.
- Console trong workspace và dashboard chỉ thực thi một lượt tại một thời
  điểm. Console độc lập / lệnh unattended vẫn cần tránh chạy song song với
  workspace vì các cổng mobile/Newman có thể trùng nhau.
- Server chỉ bind loopback. Chỉ launcher bật quyền thực thi qua
  `SWT301_DASHBOARD=1`; các server do test khởi động không nhận quyền này.
  POST dùng antiforgery token và chỉ chấp nhận suite trong danh sách cố định.
- Launcher chạy bản copy ở `TestResults/dashboard-host/` để các build do test
  thực hiện không bị khóa output trên Windows. Không cần framework/package mới.
  Port mặc định 5090; có thể gọi `run-dashboard.cmd -Port 5095`.
- Test results ở `TestResults/interactive/dashboard-<id>/`. Khởi động lại server
  vẫn đọc lịch sử đã lưu; log console trong bộ nhớ chỉ thuộc phiên server hiện tại.

Theo yêu cầu UI ngày 29/10/2026, web và Android được sắp xếp theo ảnh tham chiếu:
logo trái trên, tiêu đề xanh bên dưới, ba hàng Day/Month/Year, Clear trái và
Check phải. Dùng lại logo có sẵn trong repo (khác phiên bản logo trong ảnh).
Giữ nguyên logic, messages, IDs và test expectations. Android giữ phần cấu hình
Local API URL bên dưới khối giao diện chính để không bỏ chức năng hiện có.
Thay đổi bố cục làm visual gate khác baseline cũ; không tự cập nhật baseline,
không giảm ngưỡng 0 pixel. User đã xem candidate và trả lời **Duyệt baseline
Windows 26200** cho bố cục này; chỉ baseline `windows-11-26200-chromium-140`
được thay bằng ảnh đã duyệt. Hai baseline Windows 10/Windows 2025 vẫn giữ bố
cục cũ và cần capture/review riêng trước khi dùng để kiểm chứng bố cục mới.
GitHub workflow trên Windows 2025 hiện vẫn dùng baseline cũ, nên visual gate
ở môi trường đó dự kiến báo khác ảnh cho tới khi có review riêng; không được
suy kết quả local thành CI pass.

Double-click **`run-tests.cmd`** ở repository root. Nhập lựa chọn và Enter. Sau mỗi lần chạy, xem kết quả rồi Enter để về menu; `0` thoát. Không cần nhập lệnh testing hoặc chạy website trước.

| Chọn | Thực thi |
|---|---|
| 1 | NUnit unit qua `ci/run-tests.ps1 -Suite unit` |
| 2 | Chọn Playwright API hoặc Newman collection |
| 3 | Chín Web E2E Playwright cases hiện có |
| 4 | Build APK, chuẩn bị emulator, chạy `ci/run-mobile.py` |
| 5 | Chọn Characterization, Load hoặc Stress từ workload hiện có |
| 6 | Visual gate dùng baseline được duyệt; không sửa baseline |
| 7 | Ba AI-reviewed NUnit cases hiện có |
| 8 | Mở GitHub Actions, hoặc dispatch bằng `gh` đã đăng nhập sau khi nhập `YES` |
| 9 | Bốn HTTP integration cases hiện có |
| A | Xác nhận chạy tuần tự tất cả local suites, Newman và cả ba k6 workloads; không dispatch GitHub |
| S | Xem các phiên kết quả gần đây; tùy chọn mở thư mục bằng Explorer |

## Môi trường

Launcher tìm PowerShell 7 trong PATH, `%ProgramFiles%\PowerShell\7`, hoặc thư mục portable tương đối `../tools-swt301/powershell`. Nếu không có, thông báo và giữ console mở; không tự cài phần mềm hay đổi execution policy hệ thống. `RemoteSigned` chỉ áp dụng tiến trình runner.

Runner dùng repository root lấy từ vị trí script, nên double-click hoặc gọi từ thư mục khác đều được. Nếu đã setup portable ở `../tools-swt301/env.ps1`, menu nạp cấu hình đó và in đường dẫn. Có thể chỉ định file môi trường riêng qua biến `SWT301_ENV_FILE`; tùy chọn `-NoLocalEnvironment` bỏ qua cả hai. File môi trường là script local do bạn quản lý, không được commit chứa đường dẫn/credentials cá nhân.

- Các suite .NET cần **.NET 10 SDK**, không chỉ runtime. Release build/restore tự chạy ở lần đầu; tái sử dụng trong phiên nếu source không đổi và outputs còn đủ.
- E2E/Visual cần Chromium đúng revision của Playwright package. Khi thiếu, menu gợi ý lệnh `pwsh tests/web-e2e/DateTimeChecker.PlaywrightTests/bin/Release/net10.0/playwright.ps1 install chromium` sau build. Không tự download.
- Newman cần Node/npm, Python 3.10+, và `npm ci --prefix tests/api` đã được bạn thực hiện.
- k6 cần executable trong PATH; workload, ngưỡng và giới hạn loopback giữ nguyên. Characterization chỉ đo/kiểm tra workflow, không có acceptance thresholds.
- Mobile cần JDK 17/`JAVA_HOME`, Android SDK platform 35/`ANDROID_HOME`, adb, Appium trong `tests/mobile-e2e/node_modules` và driver UiAutomator2 4.2.9 trong repo `.appium`. Xem `USER_GUIDE.md` để cài các prerequisites sau khi bạn chấp thuận.

Mobile chọn `ANDROID_SERIAL` nếu có; nếu chỉ có một emulator kết nối thì dùng nó. Khi chưa có emulator, chọn AVD đã tồn tại qua `SWT301_AVD` hoặc dùng AVD duy nhất. Không tạo/download AVD. Emulator do runner khởi động chạy nền, chờ boot rồi được dừng khi xong; emulator có sẵn được giữ chạy. Chỉ hỗ trợ demo Android API 35 emulator, không tự cấu hình điện thoại thật. Appium Settings helper/IME được chuẩn bị trên emulator để tránh lỗi Gboard; IME của emulator có sẵn được khôi phục sau test.

Không chạy website riêng ở 5080/5081 hoặc Appium riêng ở 4723 khi chọn Mobile/Newman. Runner phát hiện cổng bận, báo `ENVIRONMENT BLOCKED`, không kill server của bạn. Các suite chạy tuần tự để tránh xung đột. APK dùng Gradle incremental build hiện có.

Visual kiểm tra baseline `APPROVED`, OS, Arial hash, image hash và browser version. `SWT_VISUAL_BASELINE` chọn baseline cụ thể; nếu chưa đặt, menu chỉ chọn khi có đúng một baseline đã duyệt khớp OS/font. Không tự chụp/duyệt/cập nhật baseline hoặc nới ngưỡng để làm test pass.

## Kết quả

Mỗi lần chạy ghi riêng tại `TestResults/interactive/<session-id>/<suite-id>/`:

- `result.json`: trạng thái, counts thực tế nếu có, exit code, lỗi và report paths.
- `execution.log`: log build/runner; output được chuyển ra console khi script con xuất dữ liệu. Một số script hiện có buffer output cho đến khi bước hoàn tất.
- `evidence/`: TRX/JSON, screenshots, Newman reports hoặc k6 measurements do scripts hiện có tạo.
- `session.json` ở thư mục phiên: các suite đã chọn trong phiên đó, gồm cả suite bị chặn/chưa thực thi.

Các trạng thái: `PASSED`, `FAILED`, `SKIPPED`, `NOT EXECUTED`, `ENVIRONMENT BLOCKED`. Thiếu dependency hoặc môi trường không khớp không được tính pass. Nếu không có fresh report hợp lệ, exit 0 cũng không được suy thành test pass. .NET giữ discovery/name/TRX guards từ scripts có sẵn. Lỗi đầu tiên trong TRX được hiển thị cùng đường dẫn log.

Newman hiển thị requests/assertions; k6 hiển thị metrics/thresholds. Không cộng assertion/sample hoặc lần chạy lặp thành NUnit/MSTest cases. k6 không chứng minh NFR-003 browser click-to-result.

GitHub Actions là remote. Dispatch chỉ gửi yêu cầu, không tự coi queued/running là pass; mở Actions để xem kết quả thật. Runner không push, merge, đổi workflows, cài CLI hay đăng nhập thay bạn.

## Chạy một lần từ terminal (tùy chọn)

```powershell
pwsh -NoProfile -File ci/test-menu.ps1 -Run unit
pwsh -NoProfile -File ci/test-menu.ps1 -Run all
pwsh -NoProfile -File ci/test-menu.ps1 -Run results
```

Các lựa chọn `-Run`: `unit`, `api`, `newman`, `web-e2e`, `mobile`, `performance-characterization`, `performance-load`, `performance-stress`, `visual`, `ai-assisted`, `http-integration`, `all`, `results`, `ci`. Single-run không hỏi cài đặt hay dispatch. Suite/all trả exit 0 chỉ khi tất cả phần được yêu cầu `PASSED`; trả 1 khi failed/skipped/blocked/not executed. `results`/`ci` chỉ hiển thị thông tin, không phải test evidence.

Ví dụ `run-tests.cmd -Run unit` cũng hoạt động. Launcher giữ console khi lỗi. Chế độ menu luôn cho Enter quay về sau thất bại; EOF hoặc lựa chọn 0 thoát mà không lặp vô hạn.
