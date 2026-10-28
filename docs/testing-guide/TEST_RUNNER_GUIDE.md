# Interactive Console Test Runner

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
