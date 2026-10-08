# DateTimeChecker Test Cases

## Automated validation tests

The `SWT.Tests` console test project covers:

- 31-day months.
- 30-day months.
- February in leap and non-leap years.
- Years divisible by 4, 100, and 400.
- Invalid months.
- Valid dates and dates beyond a month's length.
- Invalid day values.

Run the automated tests with:

```text
dotnet run --project SWT.Tests/SWT.Tests.csproj
```

## UI acceptance tests

| ID | Action/input | Expected result |
|---|---|---|
| UI-01 | Enter `abc`, `01`, `2024`, then select `Check` | `Input data for Day is incorrect format!` appears. |
| UI-02 | Enter `0`, `01`, `2024`, then select `Check` | `Input data for Day is out of range!` appears. |
| UI-03 | Enter `01`, `13`, `2024`, then select `Check` | Month out-of-range message appears. |
| UI-04 | Enter `01`, `01`, `999`, then select `Check` | Year out-of-range message appears. |
| UI-05 | Enter `31`, `12`, `3000`, then select `Check` | Valid-date message appears. |
| UI-06 | Enter `31`, `04`, `2024`, then select `Check` | Invalid-date message appears. |
| UI-07 | Enter `29`, `02`, `2000`, then select `Check` | Valid-date message appears. |
| UI-08 | Enter `29`, `02`, `1900`, then select `Check` | Invalid-date message appears. |
| UI-09 | Enter values, then select `Clear` | All three text boxes become empty. |
| UI-10 | Select the window close button, then `No` | The application remains open. |
| UI-11 | Select the window close button, then `Yes` | The application exits. |

Implementation choices for unspecified input details are:

- Blank input is treated as an incorrect-format error.
- Leading and trailing whitespace is ignored.
- One-digit values are accepted and displayed with the documented two-digit date format.
