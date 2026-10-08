using System.Text.Json;
using Microsoft.Playwright;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace DateTimeChecker.PlaywrightTests;

[TestClass]
[TestCategory("RestApi")]
[DoNotParallelize]
public sealed class DateTimeCheckerApiTests
{
    private static readonly WebApplicationFixture WebApplication = new();
    private static IPlaywright? playwright;
    private IAPIRequestContext request = null!;

    [ClassInitialize]
    public static async Task StartApplication(TestContext _)
    {
        try { await WebApplication.StartAsync(); playwright = await Microsoft.Playwright.Playwright.CreateAsync(); }
        catch { await WebApplication.DisposeAsync(); throw; }
    }
    [ClassCleanup]
    public static async Task StopApplication()
    {
        playwright?.Dispose();
        await WebApplication.DisposeAsync();
    }
    [TestInitialize]
    public async Task CreateContext() => request = await playwright!.APIRequest.NewContextAsync(new() { BaseURL = WebApplication.BaseUrl, Timeout = 10000 });
    [TestCleanup]
    public async Task DisposeContext() { if (request is not null) await request.DisposeAsync(); }

    [TestMethod]
    public Task Api_Leap2000() => AssertDateAsync(29, 2, 2000, true, 29);

    [TestMethod]
    public Task Api_Century1900() => AssertDateAsync(29, 2, 1900, false, 28);

    [TestMethod]
    public Task Api_April30() => AssertDateAsync(30, 4, 2024, true, 30);

    [TestMethod]
    public Task Api_April31() => AssertDateAsync(31, 4, 2024, false, 30);

    [TestMethod]
    public Task Api_MinimumYear() => AssertDateAsync(1, 1, 1000, true, 31);

    [TestMethod]
    public Task Api_MaximumYear() => AssertDateAsync(31, 12, 3000, true, 31);

    [TestMethod]
    public Task Api_DayBelowRange() => AssertProblemAsync("""{"day":0,"month":1,"year":2000}""", 400, "day");

    [TestMethod]
    public Task Api_DayAboveRange() => AssertProblemAsync("""{"day":32,"month":1,"year":2000}""", 400, "day");

    [TestMethod]
    public Task Api_MonthBelowRange() => AssertProblemAsync("""{"day":1,"month":0,"year":2000}""", 400, "month");

    [TestMethod]
    public Task Api_MonthAboveRange() => AssertProblemAsync("""{"day":1,"month":13,"year":2000}""", 400, "month");

    [TestMethod]
    public Task Api_YearBelowRange() => AssertProblemAsync("""{"day":1,"month":1,"year":999}""", 400, "year");

    [TestMethod]
    public Task Api_YearAboveRange() => AssertProblemAsync("""{"day":1,"month":1,"year":3001}""", 400, "year");

    [TestMethod]
    public Task Api_MissingFields() => AssertProblemAsync("""{}""", 400);

    [TestMethod]
    public Task Api_StringInput() => AssertProblemAsync("""{"day":"abc","month":2,"year":2000}""", 400);

    [TestMethod]
    public Task Api_MalformedJson() => AssertProblemAsync("""{broken""", 400);

    [TestMethod]
    public Task Api_NullBody() => AssertProblemAsync("""null""", 400);

    [TestMethod]
    public async Task Api_UnsupportedMediaType()
    {
        var response = await request.PostAsync("/api/dates/check", new() { Data = "text", Headers = new Dictionary<string,string> { ["Content-Type"] = "text/plain" } });
        Assert.AreEqual(415, response.Status);
        StringAssert.Contains(response.Headers["content-type"], "application/problem+json");
    }

    [TestMethod]
    public async Task Api_GetIsNotSupported()
    {
        Assert.AreEqual(405, (await request.GetAsync("/api/dates/check")).Status);
    }

    [TestMethod]
    public Task Api_NumericStringRejected() => AssertProblemAsync("""{"day":"29","month":2,"year":2000}""", 400);

    private async Task<IAPIResponse> PostAsync(string json) => await request.PostAsync("/api/dates/check",
        new() { Data = json, Headers = new Dictionary<string,string> { ["Content-Type"] = "application/json" } });
    private async Task AssertDateAsync(int day, int month, int year, bool expectedValid, int expectedDays)
    {
        var response = await PostAsync(JsonSerializer.Serialize(new { day, month, year }));
        Assert.AreEqual(200, response.Status);
        StringAssert.Contains(response.Headers["content-type"], "application/json");
        using var json = JsonDocument.Parse(await response.TextAsync());
        var value = json.RootElement;
        Assert.AreEqual(6, value.EnumerateObject().Count(), "Exact response contract.");
        Assert.AreEqual(day, value.GetProperty("day").GetInt32());
        Assert.AreEqual(month, value.GetProperty("month").GetInt32());
        Assert.AreEqual(year, value.GetProperty("year").GetInt32());
        Assert.AreEqual(expectedValid, value.GetProperty("isValid").GetBoolean());
        Assert.AreEqual(expectedDays, value.GetProperty("daysInMonth").GetInt32());
        var date = $"{day:D2}/{month:D2}/{year:D4}";
        Assert.AreEqual(expectedValid ? $"{date} is correct date time!" : $"{date} is NOT correct date time!",
            value.GetProperty("message").GetString());
    }
    private async Task AssertProblemAsync(string body, int status, string? field = null)
    {
        var response = await PostAsync(body);
        Assert.AreEqual(status, response.Status);
        StringAssert.Contains(response.Headers["content-type"], "application/problem+json");
        using var json = JsonDocument.Parse(await response.TextAsync());
        Assert.AreEqual(status, json.RootElement.GetProperty("status").GetInt32());
        Assert.IsFalse(string.IsNullOrEmpty(json.RootElement.GetProperty("title").GetString()));
        if (field is not null) Assert.IsTrue(json.RootElement.GetProperty("errors").GetProperty(field).GetArrayLength() > 0);
    }
}
