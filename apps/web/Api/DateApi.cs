using System.Text.Json;
namespace SWT.Api;

// Phase 3 demo contract mirrors the current web range policy; canonical ambiguities remain open.
public static class DateApi
{
    public sealed record DateInput(int? Day, int? Month, int? Year);
    public sealed record DateResult(int Day, int Month, int Year, bool IsValid, int DaysInMonth, string Message);

    public static async Task<IResult> CheckAsync(HttpRequest request)
    {
        if (!request.HasJsonContentType())
            return Results.Problem(statusCode: 415, title: "Send application/json.");
        DateInput? input;
        try { input = await request.ReadFromJsonAsync<DateInput>(new JsonSerializerOptions(JsonSerializerDefaults.Web) { NumberHandling = System.Text.Json.Serialization.JsonNumberHandling.Strict }, request.HttpContext.RequestAborted); }
        catch (JsonException) { return Results.Problem(statusCode: 400, title: "Invalid JSON input."); }
        if (input is null) return Results.Problem(statusCode: 400, title: "A JSON object is required.");
        var errors = new Dictionary<string, string[]>();
        Validate(errors, "day", input.Day, 1, 31);
        Validate(errors, "month", input.Month, 1, 12);
        Validate(errors, "year", input.Year, 1000, 3000);
        if (errors.Count > 0) return Results.ValidationProblem(errors);
        var day = input.Day!.Value;
        var month = input.Month!.Value;
        var year = input.Year!.Value;
        var valid = DateValidator.IsValidDate(year, month, day);
        var date = $"{day:D2}/{month:D2}/{year:D4}";
        return Results.Json(new DateResult(day, month, year, valid,
            DateValidator.DayInMonth(year, month),
            valid ? $"{date} is correct date time!" : $"{date} is NOT correct date time!"));
    }

    private static void Validate(Dictionary<string, string[]> errors, string name, int? value, int min, int max)
    {
        if (value is null) errors[name] = [$"{name} is required."];
        else if (value < min || value > max) errors[name] = [$"{name} must be between {min} and {max}."];
    }
}
