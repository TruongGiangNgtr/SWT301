# SWT301

SWT301 is a Software Testing coursework monorepo. Its current DateTimeChecker
application uses ASP.NET Core Razor Pages on .NET 10, with NUnit unit tests and
Playwright .NET browser tests using MSTest. This migration preserves the existing
application behavior and test expectations.

## Repository structure

```text
apps/web/                                      Razor Pages application (SWT)
tests/unit/SWT.NUnitTests/                      Existing NUnit unit suite
tests/web-e2e/DateTimeChecker.PlaywrightTests/   Existing Playwright/MSTest E2E suite
docs/requirements/                             Requirement record and context
docs/requirements/history/                     Earlier requirement drafts
docs/test-plan/                                Test cases and current test report
docs/test-plan/history/                        Historical cases and test report
docs/testing-guide/                            Build, run and test instructions
SWT.slnx                                       Single solution for all three projects
```

Phase 2 adds approved CI reporting, Razor Pages HTTP integration, visual regression,
local k6 characterization and a reviewed AI authoring demo. API and native mobile
testing still require concrete targets. See [Phase 2 results](docs/test-plan/PHASE2_REPORT.md).

## Prerequisites and commands

Install a .NET 10 SDK and PowerShell (`pwsh`) to run the generated Playwright
browser installation script. From the repository root:

```powershell
dotnet restore SWT.slnx
dotnet build SWT.slnx
dotnet run --project apps/web/SWT.csproj --no-build --no-launch-profile -- --urls http://127.0.0.1:5080
```

Open `http://127.0.0.1:5080` while the application runs. Choose another local port
if 5080 is occupied. The existing launch profile is also retained:
`dotnet run --project apps/web/SWT.csproj`.

```powershell
dotnet test tests/unit/SWT.NUnitTests/SWT.NUnitTests.csproj --no-build --list-tests
dotnet test tests/unit/SWT.NUnitTests/SWT.NUnitTests.csproj --no-build
pwsh tests/web-e2e/DateTimeChecker.PlaywrightTests/bin/Debug/net10.0/playwright.ps1 install chromium
dotnet test tests/web-e2e/DateTimeChecker.PlaywrightTests/DateTimeChecker.PlaywrightTests.csproj --no-build --list-tests
dotnet test tests/web-e2e/DateTimeChecker.PlaywrightTests/DateTimeChecker.PlaywrightTests.csproj --no-build --filter FullyQualifiedName~DateTimeChecker.PlaywrightTests.DateTimeCheckerTests
```

The browser script comes from the restored Playwright package, so it installs the
matching browser revision. E2E starts and stops its own local application server;
no manually started server is required. Normal E2E project builds also build the
web project through a project reference. `--no-build` requires a successful build
in the same configuration. For Release, build with `-c Release`, use the script
under `bin/Release/net10.0`, and run tests with `-c Release`.

The NUnit suite has 21 cases covering month lengths, leap-year branches, invalid
months and date boundaries. The browser suite has 9 cases covering controls,
Clear, Day validation, valid dates and leap/century behavior. These counts do not
prove full requirement coverage. See the [test plan](docs/test-plan/TEST_CASES.md)
and [verified results](docs/test-plan/TEST_REPORT.md).

## Requirements and limitations

[Requirements](docs/requirements/REQUIREMENTS.md) and
[context](docs/requirements/CONTEXT.md) retain the original requirement IDs and
ambiguities. The authoritative `ProjectIntroduction.docx` remains external at
the location recorded in those documents; its availability must be checked on
each machine. It has not been copied or replaced.

The original document describes Windows desktop behavior and legacy deployment
constraints. Keeping the web implementation for this structural migration is
approved; it does not certify conformance to desktop close confirmation or
resolve the ambiguous year-range/input rules.

Runtime data-protection keys and generated outputs are ignored. Previously
committed keys remain in Git history; removing them from the current index does
not revoke them or clean that history. Key rotation or history cleanup needs
separate approval.

See the [testing guide](docs/testing-guide/README.md) for lifecycle details and
troubleshooting. Historical documents are retained and explicitly distinguished
from current results.

## Phase 2 testing

The original NUnit 21 and browser 9 remain intact. The unit project now discovers
24 cases (21 original + 3 reviewed AI); the Playwright project discovers 15
(9 original + 4 HTTP + 1 candidate generator + 1 approved visual gate). CI runs
37 filtered cases; the visual gate is local to the approved Windows 10 rendering
environment. Candidate generation is preparation, not another regression gate.

- [CI and guarded TRX reporting](docs/testing-guide/ci.md)
- [Approved visual baseline and execution](docs/testing-guide/visual.md)
- [Local k6 workload and measurements](tests/performance/README.md)
- [Executed AI authoring demo](docs/testing-guide/ai-assisted.md)
- [API/mobile assessment and HTTP integration](docs/testing-guide/target-assessment.md)

The GitHub workflow has been implemented and checked locally; a GitHub runner run
has not occurred. Performance results are HTTP characterization without acceptance
thresholds and do not certify the one-second browser requirement.
