# Visual regression on the approved Windows environment

Source files live under `tests/visual/` and are linked into the existing Playwright .NET/MSTest project. No extra project or NuGet dependency was added. The original nine E2E cases remain separate.

## Reviewed baseline

The user reviewed the candidate image and approved: “Duyệt baseline và chính sách 0 pixel cho môi trường này”. Approval date: 2026-10-08. The official baseline and review metadata are in `tests/visual/baselines/windows-10-chromium-140/`.

| Setting | Approved value |
|---|---|
| OS | Microsoft Windows 10.0.19045 |
| Playwright / browser | 1.55.0 / Chromium 140.0.7339.16, headless |
| Viewport / device scale | 1280 × 720 / 1 |
| Font | Installed Arial; SHA-256 recorded in approval.json |
| Locale / timezone | en-US / Asia/Bangkok |
| Color / motion | Light / reduced motion; screenshot animations disabled |
| Capture | Viewport screenshot, CSS pixels, caret hidden; fonts and images awaited |
| Difference policy | Exactly 0 changed RGBA pixels |

The test checks OS, browser version, Arial hash and baseline image hash before capture. A mismatch fails explicitly. A Windows 2025/Linux baseline needs its own rendering environment and review. The currently approved image is not portable between these environments.

## Execute the approved gate

After Release build and Chromium installation, run from repository root:

```powershell
$env:SWT_VISUAL_OUTPUT = Join-Path (Get-Location) 'TestResults/visual-regression/local'
dotnet test tests/web-e2e/DateTimeChecker.PlaywrightTests/DateTimeChecker.PlaywrightTests.csproj -c Release --no-build --no-restore --filter FullyQualifiedName~DateTimeCheckerVisualRegressionTests --logger 'trx;LogFileName=visual.trx' --results-directory $env:SWT_VISUAL_OUTPUT -- Playwright.BrowserName=chromium
Remove-Item Env:SWT_VISUAL_OUTPUT
```

The comparer uses installed Windows PowerShell and System.Drawing to produce `actual.png`, `diff.png`, `comparison.json`, and TRX. Changed pixels appear magenta; unchanged pixels are shown in grayscale. Exit 1 means a difference; exit 0 means identical pixels. Its process uses `-ExecutionPolicy RemoteSigned` for locally generated scripts only; it does not persist a system policy change.

To compare manually, use Windows PowerShell (not PowerShell 7):

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File tests/visual/compare-screenshots.ps1 -Baseline tests/visual/baselines/windows-10-chromium-140/date-time-checker.png -Actual TestResults/visual-regression/local/actual.png -OutputDirectory TestResults/visual-comparison
```

The candidate generator is a separate `VisualCandidate` case. Run `--filter FullyQualifiedName~DateTimeCheckerVisualCandidateTests` only when preparing a review. It produces candidate/repeat images and metadata; it never replaces the baseline. No test or utility updates baselines automatically. A changed image requires inspection and a new explicit approval record before manual replacement.

Local results: candidate preparation 1/1 passed; repeat capture 0 differing pixels; approved regression 1/1 passed, 0 differing pixels. The comparer also rejected a deliberately different image with exit 1 and a diff artifact. That negative fixture was a utility check, not a failed application regression.
