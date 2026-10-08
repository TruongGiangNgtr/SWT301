# Project Requirements

## Source and status

This file is the Markdown normalization of the supplied requirement document:
`C:/Users/nttgi/OneDrive/Desktop/Labs/Labs/ProjectIntroduction.docx`.

The source document is a product requirement specification for the
`DateTimeChecker` application. It is not an instruction to edit the source
document or to perform any action outside this project.

## Product objective

Build a user-friendly C# desktop application that checks whether an entered
day, month, and year form a valid Gregorian calendar date.

## Functional requirements

### FR-01 User interface

The application must provide:

- FPT University logo at the top-left of the form.
- Title text `Date Time Checker` in blue Arial font, size 26.
- Left-aligned labels for `Day`, `Month`, and `Year`.
- One text box for each of Day, Month, and Year.
- `Clear` and `Check` buttons.
- A form without Maximize and Minimize buttons.

The supplied document includes a screen-layout image that should be treated as
the visual reference for the arrangement of these controls.

### FR-02 Close behavior

When the user selects the window close button, show a confirmation message:

`Are you sure to exit?`

- `Yes`: exit the application.
- `No`: close the message box and keep the application running.

### FR-03 Clear behavior

When the user selects `Clear`, remove the contents of all three input text
boxes.

### FR-04 Input format and range

When the user selects `Check`:

- Day must be an integer in the range 1–31.
- Month must be an integer in the range 1–12.
- Year must be an integer in the range 1000–3000.

If a value is not numeric, show an incorrect-format error. If a numeric value
is outside its allowed range, show an out-of-range error. The source document
shows the Day messages and states that equivalent validation applies to Month
and Year.

Expected message patterns from the source are:

- `Input data for Day is incorrect format!`
- `Input data for Day is out of range!`

For Month and Year, replace `Day` with the corresponding field name unless the
approved UI copy is changed.

### FR-05 Calendar validation

After the basic format and range checks pass, validate the actual date.

For a valid date, show a message in the form:

`dd/mm/yyyy is correct date time!`

For an invalid date, show a message in the form:

`dd/mm/yyyy is NOT correct date time!`

The actual entered values must replace `dd/mm/yyyy`.

## Required date algorithms

### `DaysInMonth(year, month)`

The function must return:

| Month | Number of days |
|---|---:|
| 1, 3, 5, 7, 8, 10, 12 | 31 |
| 4, 6, 9, 11 | 30 |
| 2 in a leap year | 29 |
| 2 in a non-leap year | 28 |
| Invalid month | 0 |

Leap year evaluation must follow this order:

1. If the year is divisible by 400, it is a leap year.
2. Otherwise, if it is divisible by 100, it is not a leap year.
3. Otherwise, if it is divisible by 4, it is a leap year.
4. Otherwise, it is not a leap year.

### `IsValidDate(year, month, day)`

The function must return `true` only when:

- Month is at least 1 and at most 12.
- Day is at least 1.
- Day is no greater than `DaysInMonth(year, month)`.

The source examples are:

- `IsValidDate(2006, 11, 30) = true`
- `IsValidDate(2006, 11, 31) = false`

## Non-functional requirements

### NFR-01 Reliability

- The application must run without crash failures during normal use.
- Invalid user input must be handled safely.
- Results must be compatible with the Gregorian calendar.

### NFR-02 Performance

The checking result must appear within one second after the user selects
`Check`.

### NFR-03 Usability

The user interface must be friendly and easy to use, and should follow the
screen layout shown in the source document.

### NFR-04 Maintainability

- Source code must follow C# coding conventions.
- All functions must be tested.

## Technology and environment constraints

- Application language: C#.
- Documented development environments: Visual Studio 2005 or 2008.
- Supported runtime: Windows XP SP2 or later.
- Required runtime framework: .NET Framework 2.0 or later.
- Minimum documented hardware: Pentium IV CPU and 512 MB RAM.

## Project constraint

The documented project duration is 14 days.

## Release deliverables

The release product must include:

1. Source code.
2. Installation software.
3. Test cases.
4. Test report.

## Recommended acceptance tests

| Category | Input or action | Expected result |
|---|---|---|
| Format | `abc`, `01`, `2024` | Day format error |
| Range | `0`, `01`, `2024` | Day range error |
| Range | `01`, `13`, `2024` | Month range error |
| Range | `01`, `01`, `999` | Year range error |
| Valid date | `31`, `12`, `3000` | Valid-date message |
| Invalid date | `31`, `04`, `2024` | Invalid-date message |
| Leap year | `29`, `02`, `2000` | Valid-date message |
| Century rule | `29`, `02`, `1900` | Invalid-date message |
| Divisible by 4 | `29`, `02`, `2004` | Valid-date message |
| Clear | Enter values, select `Clear` | All text boxes become empty |
| Close | Select window close, then `No` | Application remains open |
| Close | Select window close, then `Yes` | Application exits |

## Open questions and ambiguities

These items are not fully defined by the source requirement and should be
resolved before final acceptance testing:

- Whether blank fields are format errors or required-field errors.
- Whether leading/trailing spaces should be trimmed.
- Whether one-digit input is accepted and displayed with zero padding.
- Exact Month and Year error-message wording.
- Exact form dimensions and control positions.
- Whether keyboard shortcuts, tab order, and Enter/Escape behavior are
  required.
- How performance is measured and on which hardware.
- Required test coverage or pass-rate threshold.
- Whether the legacy Windows/.NET versions are strict deployment requirements
  or only historical project constraints.
