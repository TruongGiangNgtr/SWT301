# Project Context

## Project identity

This project is a small C# desktop application named `DateTimeChecker`.
It was defined as course material for Software Quality Assurance and Testing
at FPT University.

## Business purpose

The application accepts a day, month, and year, then determines whether the
combination is a valid date in the Gregorian calendar.

Although the application name contains “DateTime”, the documented scope only
contains date fields. There are no requirements for hours, minutes, seconds,
time zones, persistence, networking, authentication, or database access.

## Expected application shape

- C# Windows desktop application.
- WinForms-style fixed-size form.
- Three text boxes: Day, Month, and Year.
- Two actions: Clear and Check.
- Close confirmation when the window close button is selected.
- Message boxes for validation and result feedback.

## Core domain logic

The application must validate input in two stages:

1. Parse each field as an integer and verify its allowed range:
   - Day: 1–31
   - Month: 1–12
   - Year: 1000–3000
2. Validate the actual calendar date using Gregorian month lengths and leap
   year rules.

The leap year rule is:

- Divisible by 400: leap year.
- Otherwise divisible by 100: not a leap year.
- Otherwise divisible by 4: leap year.
- Otherwise: not a leap year.

## Technical baseline

- Language: C#
- Documented development environment: Visual Studio 2005 or 2008
- Documented runtime: Windows XP SP2 or later with .NET Framework 2.0 or later
- Documented minimum hardware: Pentium IV CPU and 512 MB RAM
- Planned project duration: 14 days

## Required release contents

The release package is expected to contain:

- Source code
- Installation software
- Test cases
- Test report

## Important interpretation notes

- The original specification contains typographical errors. In particular, the
  year range is incorrectly described once as belonging to the Day textbox.
- The specification calls the calendar “current Gregorian calendar”; the
  implementation should use explicit Gregorian rules rather than locale-
  dependent parsing.
- Exact UI dimensions and several edge-case behaviors are not specified. Do
  not invent externally visible behavior when it would affect acceptance tests.

## Project documentation

- `AGENTS.md`: instructions for Codex and future project work.
- `PROJECT_CONTEXT.md`: stable project background and interpretation.
- `PROJECT_REQUIREMENTS.md`: normalized functional and non-functional
  requirements.
