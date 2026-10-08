# Agent Instructions

## Project Source of Truth

- `C:\Users\nttgi\OneDrive\Desktop\Labs\Labs\ProjectIntroduction.docx` is the authoritative source for business requirements, scope, actors, workflows, rules, constraints, and expected behavior.
- `docs/requirements/REQUIREMENTS.md` is the structured requirement record derived from that document.
- `docs/requirements/CONTEXT.md` is the high-level project context derived from that document.
- Existing source code describes the current implementation only. It must not be treated as the correct requirement when it conflicts with the Project Introduction.
- The older files under `docs/requirements/history/PROJECT_CONTEXT.md` and `docs/requirements/history/PROJECT_REQUIREMENTS.md` are previous drafts and are not authoritative for new requirement decisions.

## Before Changing the Project

1. Read `docs/requirements/CONTEXT.md`.
2. Read the relevant section of `docs/requirements/REQUIREMENTS.md`.
3. Check the Project Introduction when the requirement is ambiguous, conflicting, or missing from the Markdown documentation.
4. Inspect the existing implementation and repository structure.
5. Identify discrepancies between the verified requirement and the implementation before making changes.
6. Implement only the verified requirement and the user's explicitly requested change.

## Requirement Discipline

- Do not invent actors, permissions, workflows, states, business rules, data fields, integrations, APIs, jobs, or technical architecture.
- Do not infer behavior from common practices or from the name of the application.
- Do not change a documented requirement merely to match existing code.
- When the Project Introduction does not specify something, write `Not specified in the Project Introduction.` or `TBD`.
- When the source is contradictory, preserve the contradiction in the documentation and request clarification before changing externally visible behavior.

## Scope Discipline

- Do not add features outside the scope stated in the Project Introduction unless the user explicitly requests them.
- Avoid speculative abstractions, infrastructure, integrations, frameworks, libraries, and refactors.
- Preserve existing behavior outside the requested change.
- Do not modify the Project Introduction document.

## Business and Technical Separation

- Document what the system must do separately from how the code implements it.
- Technical choices must support verified requirements and must not redefine them.
- Do not infer authentication, authorization, persistence, database structure, payment behavior, notifications, or background processing unless the Project Introduction explicitly requires them.

## Documentation Changes

- If an approved requirement changes, update `docs/requirements/REQUIREMENTS.md` and `docs/requirements/CONTEXT.md` when relevant.
- Keep requirement IDs and traceability entries consistent.
- Do not silently remove an unresolved ambiguity; record it under the appropriate TBD or open-question section.

## Validation Before Completion

Confirm that:

- the implementation matches the verified requirement;
- documented business rules were not changed accidentally;
- unsupported assumptions were not added;
- documented failure and exception behavior is covered where specified; and
- `docs/requirements/CONTEXT.md`, `docs/requirements/REQUIREMENTS.md`, and `AGENTS.md` use consistent terminology.


## Architecture and Platform Discipline

- The current implementation uses ASP.NET Core Razor Pages with .NET 10.
- The original Project Introduction describes a Windows desktop application.
- Treat this discrepancy as an unresolved requirement-to-implementation difference.
- Do not migrate, replace, or redesign the application platform without explicit user approval.
- Do not change existing business behavior merely to make automated tests pass.

## Software Testing Rules

- The repository is used for Software Testing coursework and automation demonstrations.
- Testing infrastructure may be extended within the explicitly approved task scope.
- Keep production code and test code logically separated.
- Preserve existing NUnit and Playwright test suites.
- Do not comment out, remove, skip, or weaken failing tests merely to obtain a passing result.
- Write deterministic, isolated, maintainable test cases.
- Use requirement-based expected results whenever the requirements are sufficiently defined.
- Report contradictions between requirements and existing implementation rather than silently adjusting expectations.
- Do not introduce new business APIs, mobile applications, or application features without explicit approval.
- Do not create unnecessary abstractions, frameworks, or test projects.

## Git and Repository Safety

- Inspect the current branch, working tree, and existing worktrees before modifying files.
- Do not modify the main branch directly.
- Use a dedicated working branch for approved changes.
- Do not overwrite unrelated or uncommitted user changes.
- Do not commit or push unless explicitly requested.
- Never force-push or rewrite Git history without approval.
- Do not delete local project files as part of Git index cleanup.
- Exclude generated build artifacts and temporary test results from version control.
- Do not commit credentials, secrets, or machine-specific sensitive data.

## Testing Infrastructure and Architecture

- Prefer the existing solution and test projects before creating new ones.
- Reuse the existing application for applicable testing categories.
- Keep testing dependencies isolated where practical.
- Add API endpoints only after their purpose and contract have been approved.
- Keep visual regression baselines under version control when appropriate.
- Performance testing must use a controlled environment and approved workload.
- Mobile testing requires an actual supported mobile target; do not assume one exists.
- AI-assisted testing must produce reviewable test artifacts and must not replace independent verification.

## Execution and Verification

After an approved implementation:

1. Run restore and build for the affected solution or projects.
2. Verify that the intended tests are discovered by the test runner.
3. Execute the relevant unit and integration or E2E tests.
4. Report passed, failed, skipped, and undiscovered tests accurately.
5. Identify environment limitations separately from product defects.
6. Check for unexpected changes in production behavior.
7. Review the final Git diff and working tree.
8. Report any incomplete tasks and approval requirements.

Never claim that a test passed unless it was actually executed successfully.

## Missing Information and Approval

- Ask the user when a missing or conflicting requirement materially affects a decision.
- Separate verified facts from assumptions and recommendations.
- State which information is missing and why it is needed.
- Present reasonable options and their consequences before requesting approval.
- Continue with independent, explicitly authorized work when another task is blocked.
- Do not infer approval from silence.

## Monorepo Conventions

- `apps/` contains application code; the current Razor Pages application is `apps/web/`.
- `tests/` contains test projects and automation assets. Keep NUnit unit tests in `tests/unit/SWT.NUnitTests/` and Playwright .NET/MSTest E2E in `tests/web-e2e/DateTimeChecker.PlaywrightTests/`.
- Keep all current .NET projects in the root `SWT.slnx`; preserve existing namespaces unless a technical need requires otherwise.
- `docs/` contains documentation. Canonical requirements and context are in `docs/requirements/`; test plans and current results are in `docs/test-plan/`; execution instructions are in `docs/testing-guide/`.
- `.github/workflows/` is reserved for approved GitHub Actions, `ci/` for necessary helper scripts, and `reports/` for reports that need retention. Create these directories only when they have approved content.
- Do not add `apps/backend/`, `apps/mobile/`, extra layers, abstractions or testing tools without an approved task and a concrete need.
- The web platform and monorepo structure are approved for the current implementation. Keep desktop-specification discrepancies recorded; structural approval does not redefine the original business requirements.
- Treat earlier documents under `docs/**/history/` as historical records, not current requirements or test evidence.
- Verify access to the external Project Introduction on each machine; do not assume a personal-machine path is available. Ask when missing or conflicting requirements affect a decision.
- Preserve uncommitted user changes when updating instructions. Do not move or delete files outside an approved migration scope.
- Validate restore/build, test discovery, test execution, Git diff and documentation consistency. Report discovered, passed, failed, skipped and unexecuted tests, and explain blockers accurately.
