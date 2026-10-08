# Building and testing SWT301

All commands below run from the repository root and use the single `SWT.slnx`.
The three projects target `net10.0`. NuGet versions are preserved during migration:

| Project | Dependencies |
|---|---|
| Web | ASP.NET Core shared framework; no extra PackageReference |
| Unit | Microsoft.NET.Test.Sdk 17.12.0; NUnit 4.2.2; NUnit3TestAdapter 4.6.0 |
| Web E2E | Microsoft.NET.Test.Sdk 17.12.0; MSTest.TestAdapter/TestFramework 3.6.3; Microsoft.Playwright.MSTest 1.55.0 |

## Build and launch

```powershell
dotnet restore SWT.slnx
dotnet build SWT.slnx
dotnet run --project apps/web/SWT.csproj --no-build --no-launch-profile -- --urls http://127.0.0.1:5080
```

The content root is `apps/web/`, including `wwwroot` and the local
`.data-protection-keys` directory. The launch profile, routes, Razor Pages and
validation code remain unchanged. Existing local keys are copied to the new
content root during migration without deleting the old copies or rotating keys.
Old `SWT/`, `SWT.NUnitTests/`, `DateTimeChecker.PlaywrightTests/` and `SWT.Tests/`
directories may still contain ignored artifacts; they are not current projects.

## Unit tests

```powershell
dotnet test tests/unit/SWT.NUnitTests/SWT.NUnitTests.csproj --no-build --list-tests
dotnet test tests/unit/SWT.NUnitTests/SWT.NUnitTests.csproj --no-build --logger "trx;LogFileName=unit.trx" --results-directory TestResults/unit
```

The existing 21 test cases, names and assertions are retained byte for byte.
The unit project references `../../../apps/web/SWT.csproj`. No new business test
cases are added as part of structural migration.

## Web E2E tests

```powershell
pwsh tests/web-e2e/DateTimeChecker.PlaywrightTests/bin/Debug/net10.0/playwright.ps1 install chromium
dotnet test tests/web-e2e/DateTimeChecker.PlaywrightTests/DateTimeChecker.PlaywrightTests.csproj --no-build --list-tests
dotnet test tests/web-e2e/DateTimeChecker.PlaywrightTests/DateTimeChecker.PlaywrightTests.csproj --no-build --filter FullyQualifiedName~DateTimeChecker.PlaywrightTests.DateTimeCheckerTests --logger "trx;LogFileName=web-e2e.trx" --results-directory TestResults/web-e2e
```

The original E2E class filter must show 9 tests. Phase 2 whole-project discovery shows 15; use the class filter to isolate the original cases. A test command exiting successfully while discovering
zero tests is not a successful validation. Both discovery and execution are
required. The previous file contained all nine cases inside a block comment; no
reason for disabling them was documented. They are restored with the same test
bodies and expected results.

The E2E project references the web project with `ReferenceOutputAssembly=false`
to build it without adding production types to browser tests. Its fixture finds
the repository root above the test output directory and uses the test assembly's
Debug/Release configuration. It runs `dotnet run --no-build --no-restore
--no-launch-profile` with the web project directory as content root.

Kestrel binds `127.0.0.1:0`, allowing the OS to allocate a port without a
reserve-and-release race. The fixture reads the actual listening address from
console logs, then polls the existing page for a successful HTTP response. The
startup budget is 45 seconds; each HTTP attempt is limited to 2 seconds. Polling
is condition based rather than a fixed startup sleep. Standard output/error are
drained and the last 200 lines are retained for startup diagnostics. Initialization
failure and class cleanup stop only the owned server process tree, with a
10-second exit budget. Development mode and no launch profile make the existing
console logging and local static-file behavior deterministic.

This root lookup assumes normal project outputs beneath the repository. Custom
output directories outside the repository require a separately reviewed runner
configuration. Do not manually reuse an unrelated server or kill processes by
port/name.

For Release:

```powershell
dotnet build SWT.slnx -c Release
pwsh tests/web-e2e/DateTimeChecker.PlaywrightTests/bin/Release/net10.0/playwright.ps1 install chromium
dotnet test tests/web-e2e/DateTimeChecker.PlaywrightTests/DateTimeChecker.PlaywrightTests.csproj -c Release --no-build --filter FullyQualifiedName~DateTimeChecker.PlaywrightTests.DateTimeCheckerTests
```

Browser launch failures must be reported as failures/environment limitations.
Use the generated browser script for this package version; do not change business
expectations to make tests pass. Browser installation and runtime guidance:
[Playwright .NET installation](https://playwright.dev/dotnet/docs/intro) and
[test runners](https://playwright.dev/dotnet/docs/test-runners).

## Historical records and future work

[Current plan](../test-plan/TEST_CASES.md) and
[current report](../test-plan/TEST_REPORT.md) describe this implementation.
[Historical records](../test-plan/history/README.md) preserve previous desktop
test claims without treating them as current evidence.

Phase 2 implements approved [CI reporting](ci.md), [HTTP integration](target-assessment.md),
[visual regression](visual.md), [local k6 characterization](../../tests/performance/README.md),
and [AI-assisted authoring](ai-assisted.md). The solution still has three projects
and the same package versions. Additional visual/HTTP sources are linked from their
separate directories into the existing Playwright project.

The unit project now discovers 24 cases overall; 21 are the unchanged original
class and 3 are the reviewed AI class. The browser project discovers 15 overall;
9 are original E2E, 4 HTTP integration, 1 candidate generator and 1 approved visual
regression. Use the documented filters and CI scripts to select each suite. A
whole-project browser run includes the Windows-specific gate and will explicitly
fail on an environment with no approved baseline; use the intended suite filters.

See [Phase 2 actual results](../test-plan/PHASE2_REPORT.md). The structural migration
report remains a dated record. API contract tests and native mobile tests remain
blocked by missing concrete targets; no endpoints or mobile applications were added.
