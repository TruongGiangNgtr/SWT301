using System.Globalization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace SWT.Pages;

public sealed class IndexModel : PageModel
{
    [BindProperty]
    public string Day { get; set; } = string.Empty;

    [BindProperty]
    public string Month { get; set; } = string.Empty;

    [BindProperty]
    public string Year { get; set; } = string.Empty;

    public string? DialogMessage { get; private set; }

    public IActionResult OnPost(string? action)
    {
        if (string.Equals(action, "clear", StringComparison.Ordinal))
        {
            Day = string.Empty;
            Month = string.Empty;
            Year = string.Empty;
            return Page();
        }

        return CheckDate();
    }

    private IActionResult CheckDate()
    {
        if (!TryReadInput(Day, "Day", 1, 31, out var day) ||
            !TryReadInput(Month, "Month", 1, 12, out var month) ||
            !TryReadInput(Year, "Year", 1000, 3000, out var year))
        {
            return Page();
        }

        var enteredDate = $"{Day}/{Month}/{Year}";
        DialogMessage = DateValidator.IsValidDate(year, month, day)
            ? $"{enteredDate} is correct date time!"
            : $"{enteredDate} is NOT correct date time!";

        return Page();
    }

    private bool TryReadInput(
        string input,
        string fieldName,
        int minimum,
        int maximum,
        out int value)
    {
        if (!int.TryParse(
                input,
                NumberStyles.AllowLeadingSign,
                CultureInfo.InvariantCulture,
                out value))
        {
            DialogMessage = $"Input data for {fieldName} is incorrect format!";
            return false;
        }

        if (value < minimum || value > maximum)
        {
            DialogMessage = $"Input data for {fieldName} is out of range!";
            return false;
        }

        return true;
    }
}
