# Project Context

## 1. Project Overview

The Project Introduction describes the `DateTimeChecker` application, also
abbreviated as `DTC`. It is a C# application intended to check whether a date
time input is valid. The document identifies the work as course material for
Software Quality Assurance and Testing at FPT University.

The Introduction does not describe a broader business domain, data storage,
external service, or organizational process.

## 2. Project Objectives

The objectives and expected product characteristics explicitly stated in the
Introduction are:

- Provide the `DateTimeChecker` application for checking date time input.
- Write the program in C#.
- Provide a user interface that is friendly and easy to use.
- Follow C# coding conventions in the source code.
- Test all functions.
- Include source code, installation software, test cases, and a test report in
  the release product.
- Complete the project within 14 days.

## 3. Users and Actors

### User

The Introduction refers to a user who enters values, selects `Check`, selects
`Clear`, and selects the window close button. No other application actor, role,
administrator, staff member, or permission model is identified.

## 4. System Scope

### In Scope

The Introduction explicitly includes:

- A date time checking application.
- A user interface with a FU logo, title, Day/Month/Year labels and textboxes,
  `Clear` and `Check` buttons, and no Maximize or Minimize box.
- Close confirmation behavior.
- Clearing the three input textboxes.
- Input format and range checks.
- Date validation using the documented `DaysInMonth` and `IsValidDate`
  algorithms.
- Reliability, performance, usability, coding-convention, and test
  expectations stated by the Introduction.
- The documented technology, environment, hardware, project-duration, and
  release-content constraints.

### Out of Scope

The Introduction does not explicitly define an out-of-scope list. Any feature
not described by it is therefore not a documented requirement.

## 5. Core Functional Areas

The Introduction supports these functional areas:

1. User interface layout.
2. Close confirmation.
3. Clearing input fields.
4. Checking input format and ranges.
5. Checking the validity of a date time value.

No additional functional area is specified.

## 6. Core Business Flow

The documented high-level flow is:

1. The user enters Day, Month, and Year values.
2. The user selects `Check`.
3. The application validates the input format and ranges.
4. If the input is in the correct format and range, the application checks the
   date using the documented date algorithms.
5. The application displays a message for a valid or invalid date time value.

Separately, the user may select `Clear` to clear the three textboxes or select
the window close button to receive the documented confirmation prompt.

## 7. Business Rules

- Day input is described as an integer in the range 1-31.
- Month input is described as an integer in the range 1-12.
- The Introduction contains a sentence that names the Day textbox for the
  range 1000-3000, but the surrounding text and examples refer to Year. The
  field associated with this range is therefore unresolved; see Section 9.
- `DaysInMonth` returns 31 for months 1, 3, 5, 7, 8, 10, and 12.
- `DaysInMonth` returns 30 for months 4, 6, 9, and 11.
- February has 29 days in a leap year and 28 days otherwise.
- An invalid month returns 0 from `DaysInMonth`.
- A year divisible by 400 is a leap year.
- A year divisible by 100, but not 400, is not a leap year.
- A year divisible by 4, but not 100, is a leap year.
- `IsValidDate` requires a month from 1 through 12, a day of at least 1, and a
  day no greater than `DaysInMonth`.

## 8. Important Constraints

- The application language is C#.
- The Introduction states that the program runs on all Windows platforms with
  .NET Framework 2.0 or higher.
- The stated running environment is Windows XP SP2 or higher.
- The stated development environment is Visual Studio 2005 or Visual Studio
  2008.
- The stated hardware is a Pentium IV or higher and 512 MB RAM or higher.
- The release product must include source code, installation software, test
  cases, and a test report.
- The documented project duration is 14 days.

## 9. Known Unknowns and TBD

- The sentence assigning the 1000-3000 range to the Day textbox conflicts with
  the surrounding reference to Year. The Introduction does not unambiguously
  resolve the field association.
- The reliability section says “Georgian calendar,” while the algorithm
  descriptions and flowcharts say “Gregorian calendar.” The required calendar
  terminology should be confirmed against the source owner's intent.
- Exact control dimensions and positions are shown in a figure, but no numeric
  dimensions are specified in text.
- The Introduction does not specify behavior for blank input, whitespace,
  signs, decimal values, leading zeroes, or other unshown input forms.
- The exact Month and Year error-message text is not written out; the source
  explicitly shows the Day examples and says similar validation applies to
  Month and Year.
- The Introduction does not specify keyboard shortcuts, tab order, focus
  behavior, or other keyboard interaction.
- The Introduction does not specify a measurement procedure for the one-second
  performance target.
- The Introduction does not define a test coverage threshold or pass-rate
  criterion beyond stating that all functions must be tested.
- The Introduction does not define actors other than the user, permissions,
  authentication, authorization, persistence, database behavior, APIs,
  notifications, background jobs, or other external systems.
