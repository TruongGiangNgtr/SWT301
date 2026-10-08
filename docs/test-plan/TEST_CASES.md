# DateTimeChecker current test plan

This plan describes existing tests against the current Razor Pages implementation.
It preserves requirement ambiguities and distinguishes automated evidence from
manual or historical acceptance cases. No test cases or expected results are
added or changed by structural migration.

## Existing automated suites

| Suite | Cases | Scope | Requirement links |
|---|---:|---|---|
| NUnit | 21 | Month lengths, leap years, invalid months, valid/invalid days | BR-001, BR-002, BR-003 |
| Playwright .NET/MSTest | 9 | Controls, Clear, Day format/range, Day boundaries, April 31, February 29 in 2000/1900 | FR-001, FR-003, FR-004, FR-005, FR-006 |

The NUnit source contains 9 `DayInMonth` cases and 12 `IsValidDate` cases.
Existing UTCID names refer to Lab 2; that separate lab's provenance has not been
reverified here. Cases are retained unchanged and their outputs agree with the
verified algorithm for the existing input values.

The nine browser cases are:

1. `RequiredFieldsAndButtonsArePresent`
2. `Clear_ShouldClearAllInputFields`
3. `Day_NonNumeric_ShouldShowIncorrectFormatMessage`
4. `Day_BelowMinimum_ShouldShowOutOfRangeMessage`
5. `Day_AboveMaximum_ShouldShowOutOfRangeMessage`
6. `Day_Boundaries_ShouldPassDayRangeValidation`
7. `April31_ShouldBeInvalidDate`
8. `LeapYear_February29_ShouldBeValid`
9. `NonLeapYear_February29_ShouldBeInvalid`

Test names, bodies, assertions and expected messages are preserved. Server
startup and cleanup are infrastructure changes only. The boundary test checks
two input dates within one case; it still counts as one discovered test.

## Retained acceptance cases and status

| ID | Action/input | Original expected result | Current scope/status |
|---|---|---|---|
| UI-01 | `abc`, `01`, `2024`; Check | Day format message | Existing E2E uses year 2000 for equivalent Day branch |
| UI-02 | `0`, `01`, `2024`; Check | Day range message | Existing E2E uses year 2000 for equivalent Day branch |
| UI-03 | `01`, `13`, `2024`; Check | Month range message | Not covered by existing E2E; exact copy requires clarification |
| UI-04 | `01`, `01`, `999`; Check | Year range message | Historical case; range-field ambiguity remains open |
| UI-05 | `31`, `12`, `3000`; Check | Valid-date message | Not covered at year 3000; range ambiguity remains open |
| UI-06 | `31`, `04`, `2024`; Check | Invalid-date message | Existing E2E |
| UI-07 | `29`, `02`, `2000`; Check | Valid-date message | Existing E2E |
| UI-08 | `29`, `02`, `1900`; Check | Invalid-date message | Existing E2E |
| UI-09 | Enter values; Clear | All fields empty | Existing E2E (FR-003) |
| UI-10 | Window close; No | Application remains open | Desktop requirement; not implemented/tested by web suite |
| UI-11 | Window close; Yes | Application exits | Desktop requirement; not implemented/tested by web suite |

## Coverage gaps and unresolved requirements

NUnit does not exercise every month branch, the 1900 century branch directly, or
year-range boundaries. Existing browser coverage exercises the 1900 branch but
does not test Month/Year input validation comprehensively, every logo/style
requirement, installation/deployment constraints or the one-second performance
target. There is no measured coverage percentage or full-conformance claim.

The source specification leaves blank/whitespace/sign/decimal handling, padding,
exact Month/Year messages, the 1000-3000 field association and its placement in
the algorithms unresolved. Existing code uses signed integer parsing without
whitespace trimming and echoes the entered date strings. These are implementation
observations, not newly approved requirements. Do not revise expectations or
business logic without clarification.

See [requirements](../requirements/REQUIREMENTS.md),
[historical cases](history/TEST_CASES.md), [test results](TEST_REPORT.md) and
[execution guide](../testing-guide/README.md).
