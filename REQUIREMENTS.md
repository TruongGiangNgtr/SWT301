# Project Requirements

## 1. Requirement Source

The Project Introduction document at
`C:\Users\nttgi\OneDrive\Desktop\Labs\Labs\ProjectIntroduction.docx` is the
authoritative source for the requirements in this file. Existing Markdown and
source code are not authoritative when they conflict with that document.

The Introduction is a User Requirement Document for the `DateTimeChecker`
application, abbreviated as `DTC`, and identifies the work as course material
for Software Quality Assurance and Testing at FPT University.

## 2. Actors

### ACT-001 — User

**Description:** The person interacting with the application.

**Responsibilities supported by the Introduction:**

- Enter Day, Month, and Year values.
- Select `Check`.
- Select `Clear`.
- Select the window close button and choose `Yes` or `No` in the confirmation
  message box.

No other application actor or role is identified in the Introduction.

## 3. Functional Requirements

### FR-001 — User Interface Layout

**Actor:** User

**Description:** The application must use the layout shown in the Introduction's
screen-layout figure.

**Required elements:**

- A picture box with the FU logo at the top-left corner.
- The text `Date Time Checker` with blue foreground color, Arial font, and size
  26.
- Left-aligned `Day`, `Month`, and `Year` text labels.
- Three textboxes for entering day, month, and year.
- Two buttons: `Clear` and `Check`.
- A form without Maximize and Minimize boxes.

**Source:** Functionality > User Interface and the screen-layout figure.

### FR-002 — Close Confirmation

**Actor:** User

**Description:** When the user clicks the `X` close button, the application must
ask for confirmation in a message box.

**Expected result:**

- Selecting `Yes` exits the application.
- Selecting `No` closes the message box and the application continues to exist.

**Source:** Functionality > `Close` function and the confirmation-message
figure.

### FR-003 — Clear Input Fields

**Actor:** User

**Description:** When the user clicks `Clear`, the text in all three textboxes
must be cleared.

**Source:** Functionality > `Clear` function.

### FR-004 — Input Values and Range Checks

**Actor:** User

**Description:** The Introduction requires integer input and gives these ranges:

- Day: 1-31.
- Month: 1-12.
- A range of 1000-3000 is stated in a sentence that names the Day textbox,
  although the surrounding requirement refers to Year. The intended field
  association is unresolved.

**Main behavior:** When the user clicks `Check`, the application validates the
input. If Day data is not a number, it shows an incorrect-format message. If
Day data is numeric but outside its range, it shows an out-of-range message.
The Introduction states that similar validation applies to Month and Year.

**Explicit source message examples:**

- `Input data for Day is incorrect format!`
- `Input data for Day is out of range!`

**Exceptions and missing details:** Exact Month and Year message text is not
shown in the written text; the Introduction only states that similar
validation applies.

**Source:** Functionality > Check Date Time function and the format and
out-of-range message figures.

### FR-005 — Valid Date Result

**Actor:** User

**Description:** After the date input passes the required format and range
checks, the application must determine whether it is a valid date time.

**Expected result:** For a valid date time, a message box is shown with text in
this form, replacing `dd/mm/yyyy` with the actual value:

`dd/mm/yyyy is correct date time!`

**Source:** Functionality > Check Date Time function and the correct-date
message figure.

### FR-006 — Invalid Date Result

**Actor:** User

**Description:** After the date input passes the required format and range
checks, if the date time is invalid, the application must show an invalid-date
message.

**Expected result:** A message box is shown with text in this form, replacing
`dd/mm/yyyy` with the actual value:

`dd/mm/yyyy is NOT correct date time!`

**Source:** Functionality > Check Date Time function and the invalid-date
message figure.

## 4. Non-Functional Requirements

### NFR-001 — Reliability

The application must run smoothly without any crash failure.

**Source:** Reliability.

### NFR-002 — Calendar Compatibility

The checking result must be compatible with the calendar terminology stated by
the Introduction. The document says “Georgian calendar” in Reliability but
uses “Gregorian calendar” in the date-algorithm descriptions and flowcharts.
This terminology conflict is unresolved.

**Source:** Reliability and Functionality > Check Date Time function.

### NFR-003 — Performance

The checking result must appear within one second after the user clicks
`Check`.

**Source:** Performance.

### NFR-004 — Usability

The user interface must be friendly and easy to use.

**Source:** Scope and the Overview's usability category.

### NFR-005 — Coding Convention

The source code must follow the C# coding convention.

**Source:** Scope.

### NFR-006 — Function Testing

All functions must be tested.

**Source:** Scope.

## 5. Date Algorithms and Business Rules

### BR-001 — `DaysInMonth`

The Introduction's flowchart defines a public `DaysInMonth` function receiving
Year and Month and returning the number of days in the given month using the
current Gregorian calendar. It gives `DaysInMonth(2000, 2) = 29` as an example.

The function behavior shown is:

- Months 1, 3, 5, 7, 8, 10, and 12 return 31.
- Months 4, 6, 9, and 11 return 30.
- February checks the leap-year rules.
- An invalid month returns 0.

The diagram labels its example parameter types as Year `UShort`, Month `Byte`,
and return type `Byte`. The Introduction does not specify a C# signature.

**Source:** Functionality > Check Date Time function > `DaysInMonth` flowchart.

### BR-002 — Leap-Year Rule

The `DaysInMonth` flowchart shows this order for February:

1. If Year is divisible by 400, return 29.
2. Otherwise, if Year is divisible by 100, return 28.
3. Otherwise, if Year is divisible by 4, return 29.
4. Otherwise, return 28.

**Source:** `DaysInMonth` flowchart.

### BR-003 — `IsValidDate`

The Introduction's flowchart defines an `IsValidDate` function receiving Year,
Month, and Day and returning Boolean. It gives these examples:

- `IsValidDate(2006, 11, 30) = True`
- `IsValidDate(2006, 11, 31) = False`

The function behavior shown is:

- Month must be at least 1 and at most 12.
- Day must be at least 1.
- Day must not exceed `DaysInMonth(Year, Month)`.

The diagram labels its example parameter types as Year `Short`, Month `Byte`,
Day `Byte`, and return type `Boolean`. The Introduction does not specify a C#
signature.

**Source:** Functionality > Check Date Time function > `IsValidDate` flowchart.

## 6. Constraints and Release Requirements

### CON-001 — Application Language

The program must be written in C#.

**Source:** Scope.

### CON-002 — Running Environment

The Introduction states that the application runs on all Windows platforms
with .NET Framework 2.0 or higher and separately states Windows XP SP2 or
higher.

**Source:** Scope and Technology Rules and Limitations > Running Environment.

### CON-003 — Development Environment

The documented development environments are Visual Studio 2005 or Visual
Studio 2008.

**Source:** Technology Rules and Limitations > Development Environment.

### CON-004 — Hardware

The documented machine requirements are a Pentium IV or higher CPU and 512 MB
or higher RAM.

**Source:** Technology Rules and Limitations > Hardware.

### CON-005 — Project Duration

The documented project duration is 14 days.

**Source:** Scope.

### CON-006 — Release Contents

The release product must include source code, installation software, test cases,
and a test report.

**Source:** Scope.

## 7. Data and Business Entities

The Introduction explicitly mentions only these business concepts:

- User.
- Day input.
- Month input.
- Year input.
- Date time value.
- `DaysInMonth` and `IsValidDate` functions.

No database entities, fields, identifiers, storage model, or external systems
are specified.

## 8. Business Flows

### FLOW-001 — Check Date Time

1. The user enters Day, Month, and Year values.
2. The user clicks `Check`.
3. The application checks the input format and range.
4. If the input is correct, the application checks whether the date time is
   valid using the documented algorithms.
5. The application shows the valid-date or invalid-date message.

The Introduction does not define the exact handling of every unspecified input
form.

### FLOW-002 — Clear

1. The user clicks `Clear`.
2. The application clears the text in the three textboxes.

### FLOW-003 — Close

1. The user clicks the window `X` button.
2. The application shows the confirmation message box.
3. `Yes` exits the application.
4. `No` closes the message box and keeps the application running.

## 9. Requirement Traceability

| Requirement ID | Requirement | Introduction source |
|---|---|---|
| FR-001 | User interface layout and controls | Functionality > User Interface and screen-layout figure |
| FR-002 | Close confirmation | Functionality > `Close` function and confirmation figure |
| FR-003 | Clear three textboxes | Functionality > `Clear` function |
| FR-004 | Input format and range checks | Functionality > Check Date Time function and error figures |
| FR-005 | Valid date message | Functionality > Check Date Time function and correct-date figure |
| FR-006 | Invalid date message | Functionality > Check Date Time function and invalid-date figure |
| NFR-001 | Reliability | Reliability |
| NFR-002 | Calendar compatibility | Reliability and Check Date Time function |
| NFR-003 | One-second result | Performance |
| NFR-004 | Friendly and easy-to-use UI | Scope and Overview |
| NFR-005 | C# coding convention | Scope |
| NFR-006 | All functions tested | Scope |
| BR-001 | `DaysInMonth` month-length behavior | Check Date Time function and `DaysInMonth` flowchart |
| BR-002 | Leap-year evaluation | `DaysInMonth` flowchart |
| BR-003 | `IsValidDate` behavior | Check Date Time function and `IsValidDate` flowchart |
| CON-001 | C# language | Scope |
| CON-002 | Windows and .NET Framework environment | Scope and Running Environment |
| CON-003 | Visual Studio version | Development Environment |
| CON-004 | Hardware | Hardware |
| CON-005 | 14-day duration | Scope |
| CON-006 | Release contents | Scope |

## 10. Open Questions and Missing Information

- Does the 1000-3000 range apply to Year, or does the source literally intend
  it for Day? The written requirement is inconsistent.
- Should “Georgian calendar” in Reliability be read as “Gregorian calendar,” or
  is a different calendar intended? The source is inconsistent.
- What exact message text should be used for invalid Month and Year format and
  range values?
- What happens for blank input, whitespace, signs, decimal input, or other
  values not shown in the Introduction?
- What exact numeric control dimensions and positions should be used beyond the
  screen-layout figure?
- Are keyboard shortcuts, tab order, Enter, or Escape behavior required?
- How must the one-second performance requirement be measured?
- What test coverage or pass-rate threshold qualifies as “all functions must be
  tested”?
- What installation software format is required?
- Are the historical Windows XP, .NET Framework, and Visual Studio versions
  strict deployment requirements or documentation of the original project
  environment? The Introduction does not clarify this.
