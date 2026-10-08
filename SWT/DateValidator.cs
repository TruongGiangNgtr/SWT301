namespace SWT;

/// <summary>
/// Contains the Gregorian calendar rules used by the application.
/// </summary>
public static class DateValidator
{
    /// <summary>
    /// Returns the number of days in a Gregorian calendar month.
    /// </summary>
    public static int DayInMonth(int year, int month)
    {
        if (year < 1000 || year > 3000)
        {
            return 0;
        }

        return month switch
        {
            1 or 3 or 5 or 7 or 8 or 10 or 12 => 31,
            4 or 6 or 9 or 11 => 30,
            2 => IsLeapYear(year) ? 29 : 28,
            _ => 0
        };
    }

    /// <summary>
    /// Determines whether the supplied day and month form a valid Gregorian date.
    /// </summary>
    public static bool IsValidDate(int year, int month, int day)
    {
        if (year < 1000 || year > 3000 || month < 1 || month > 12 || day < 1)
        {
            return false;
        }

        return day <= DayInMonth(year, month);
    }

    private static bool IsLeapYear(int year)
    {
        if (year % 400 == 0) return true;
        if (year % 100 == 0) return false;
        return year % 4 == 0;
    }
}
