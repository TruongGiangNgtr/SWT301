# API and mobile target assessment

## API testing

**BLOCKED — Awaiting approved API target.** Inspection found ASP.NET Core Razor Pages, `MapRazorPages`, static assets and page handlers. No REST API controller, minimal API contract, OpenAPI document or separate backend exists. A Razor Pages form POST is not being reported as REST API testing.

HTTP integration is separately implemented under `tests/integration/DateTimeCheckerHttpTests.cs`, compiled into the existing Playwright/MSTest project. APIRequestContext exercises actual GET/static files, token/cookie-bound Check and Clear POST, and rejection of POST without CSRF. Four cases passed locally; no browser is needed for this suite. These are current implementation/security checks, not a new REST contract or new business requirements.

Minimal future options are (1) a specifically identified training API outside this application with an approved contract and environment, preserving architecture, or (2) a separately authorized API feature with explicit routes, methods, payloads and business scope, which changes application scope. No target or endpoint has been selected, and no Postman collection with imaginary URLs was created. General approval cannot supply a missing URL or contract.

Run current HTTP integration after Release build:

```powershell
pwsh ci/run-tests.ps1 -Suite http-integration
```

## Mobile testing

**BLOCKED — No approved mobile application.** The solution has only the web app, NUnit project and Playwright project. No Android/iOS native or hybrid app/package, platform, emulator/device environment or supported Appium target was identified. No Appium dependency or empty mobile project was installed. Mobile viewport screenshots are not being claimed as native tests.

Future options are a concrete, approved training app/package with platform and emulator/device details, or an existing owned mobile application with its environment and expected scenarios. Creating a mobile app would be a separate product task. Execution also needs package/build identity, app entry/activity or bundle ID, Appium driver/server versions and initial data/state. This is missing technical input, not another pending permission request.

Continue the independent CI, visual, HTTP, performance and reviewed AI work while these targets remain absent. No additional API/mobile implementation is claimed.
