# Agent Instructions

## Project Source of Truth

- `C:\Users\nttgi\OneDrive\Desktop\Labs\Labs\ProjectIntroduction.docx` is the authoritative source for business requirements, scope, actors, workflows, rules, constraints, and expected behavior.
- `REQUIREMENTS.md` is the structured requirement record derived from that document.
- `CONTEXT.md` is the high-level project context derived from that document.
- Existing source code describes the current implementation only. It must not be treated as the correct requirement when it conflicts with the Project Introduction.
- The older files under `docs/PROJECT_CONTEXT.md` and `docs/PROJECT_REQUIREMENTS.md` are previous drafts and are not authoritative for new requirement decisions.

## Before Changing the Project

1. Read `CONTEXT.md`.
2. Read the relevant section of `REQUIREMENTS.md`.
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

- If an approved requirement changes, update `REQUIREMENTS.md` and `CONTEXT.md` when relevant.
- Keep requirement IDs and traceability entries consistent.
- Do not silently remove an unresolved ambiguity; record it under the appropriate TBD or open-question section.

## Validation Before Completion

Confirm that:

- the implementation matches the verified requirement;
- documented business rules were not changed accidentally;
- unsupported assumptions were not added;
- documented failure and exception behavior is covered where specified; and
- `CONTEXT.md`, `REQUIREMENTS.md`, and `AGENTS.md` use consistent terminology.
