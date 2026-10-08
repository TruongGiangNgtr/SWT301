# DateTimeChecker verified migration test report

Validation date: 2026-10-08 (Asia/Bangkok). Branch:
`chore/monorepo-migration`. Environment: Windows 10 x64, .NET SDK 10.0.401,
ASP.NET Core runtime 10.0.12, Playwright .NET package 1.55.0 with the existing
Chromium/headless-shell revision 1187. No new package versions, frameworks or
browser installations were needed.

## Results

| Run | Discovered/total | Passed | Failed | Skipped | Not executed |
|---|---:|---:|---:|---:|---:|
| Baseline NUnit Debug before migration | 21 | 21 | 0 | 0 | 0 |
| Baseline Playwright discovery | 0 | N/A | N/A | N/A | 9 commented cases |
| Migrated NUnit Debug | 21 | 21 | 0 | 0 | 0 |
| Migrated Playwright Debug | 9 | 9 | 0 | 0 | 0 |
| Migrated Playwright Release | 9 | 9 | 0 | 0 | 0 |

Release repeats the same nine E2E cases; it does not add nine distinct tests.
The current suites contain 30 distinct cases. NUnit Release was built but not
executed; NUnit Debug was compared before and after migration.

Baseline and migrated restore succeeded. Migrated Debug and Release solution
builds succeeded with 0 warnings and 0 errors. Discovery listed all expected
21 NUnit and 9 browser cases. The original E2E file was entirely block commented;
no disabling rationale was recorded in the inspected source/documents.

## Commands executed after migration

```powershell
dotnet restore SWT.slnx
dotnet build SWT.slnx --no-restore
dotnet test tests/unit/SWT.NUnitTests/SWT.NUnitTests.csproj --no-build --no-restore --list-tests
dotnet test tests/unit/SWT.NUnitTests/SWT.NUnitTests.csproj --no-build --no-restore --logger "trx;LogFileName=unit-debug.trx" --results-directory <validation-output>/post-unit
dotnet test tests/web-e2e/DateTimeChecker.PlaywrightTests/DateTimeChecker.PlaywrightTests.csproj --no-build --no-restore --list-tests
dotnet test tests/web-e2e/DateTimeChecker.PlaywrightTests/DateTimeChecker.PlaywrightTests.csproj --no-build --no-restore --logger "trx;LogFileName=e2e-debug.trx" --results-directory <validation-output>/post-e2e
dotnet build SWT.slnx -c Release --no-restore
dotnet test tests/web-e2e/DateTimeChecker.PlaywrightTests/DateTimeChecker.PlaywrightTests.csproj -c Release --no-build --no-restore --logger "trx;LogFileName=e2e-release.trx" --results-directory <validation-output>/post-e2e-release
```

`<validation-output>` denotes the task's temporary validation directory; replace
it with a local writable path when reproducing. Developer commands are in the
[testing guide](../testing-guide/README.md), which uses ignored `TestResults/`.
TRX reports were saved separately from repository source and contain the actual
test outcomes, including server readiness/stop messages.

## Application smoke and compatibility

An independent HTTP smoke check started the migrated application with an OS
allocated loopback port, fetched `/`, `/css/site.css` and `/img/logo_fpt.png`, and
verified HTTP 200. Downloaded CSS/logo bytes matched the files at the new content
root. POSTs with the existing antiforgery mechanism verified the unchanged
`29/02/2000 is correct date time!` message and clearing all three fields. Browser
tests also exercised Check/Clear and the existing validation/result messages.

E2E server logs confirmed Debug and Release startup on distinct allocated ports
and server shutdown. The independent smoke server was also stopped. Cleanup
operated on the process trees started by the validation fixtures only.

SHA-256 comparisons confirmed all eight application files, the NUnit test file,
both canonical requirement documents and four historical documents were preserved
byte for byte. The nine E2E method bodies/expected results were compared with the
uncommented original and retained unchanged. Namespace, routes, launch profile,
static assets, parsing, date algorithms and UI remain unchanged. Local runtime
keys were copied unchanged to the new content root, retaining the original files.

## Git and repository checks

1,350 generated/runtime-key files were removed from the current Git index using
`git rm --cached`; local files were not deleted by index cleanup. No such files
remain tracked. Ignore rules cover .NET/IDE outputs, local keys, execution
results, Playwright runtime outputs, logs and temporary files. Both staged and
unstaged `git diff --check` passed.

The pre-existing uncommitted `AGENTS.md` additions were preserved, with authorized
path updates and additive monorepo rules. Migration changes are staged except
`AGENTS.md`, which retains those pre-existing changes unstaged. No commit, push,
force push, history rewrite or secret rotation was performed.

## Limits and pending decisions

Successful migration validates the existing web implementation and suites; it
does not certify every original requirement. Desktop close confirmation, legacy
Windows/.NET deployment constraints, year-range ambiguity, exact Month/Year copy,
unspecified input handling and the performance target remain open. There is no
measured code-coverage percentage or one-second performance claim.

Two previously tracked data-protection key files contained unencrypted key
material. Their values were not printed. Removing current tracking does not
remove exposure from Git history; any impact review, rotation or history cleanup
requires approval. The authoritative external Word document was available and
read at its original recorded location; it was not moved, copied into the
repository or modified.

No new API/integration/performance/visual/mobile/AI-assisted suites, GitHub Actions
workflows, Allure integration, backend or mobile application were implemented.
The earlier 8/8 desktop-console result is retained in the
[historical report](history/TEST_REPORT.md) as a historical claim only.
