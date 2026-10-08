using System.Net;
using System.Text.RegularExpressions;
using Microsoft.Playwright;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace DateTimeChecker.PlaywrightTests;

/// <summary>HTTP integration against real Razor Pages, not a REST API contract.</summary>
[TestClass]
[TestCategory("HttpIntegration")]
[DoNotParallelize]
public sealed class DateTimeCheckerHttpTests
{
    private static readonly WebApplicationFixture WebApplication = new();
    private static IPlaywright? playwright;
    private IAPIRequestContext request = null!;

    [ClassInitialize]
    public static async Task StartApplication(TestContext _)
    {
        try
        {
            await WebApplication.StartAsync();
            playwright = await Microsoft.Playwright.Playwright.CreateAsync();
        }
        catch
        {
            await WebApplication.DisposeAsync();
            throw;
        }
    }

    [ClassCleanup]
    public static async Task StopApplication()
    {
        playwright?.Dispose();
        await WebApplication.DisposeAsync();
    }

    [TestInitialize]
    public async Task CreateRequestContext() => request = await playwright!.APIRequest.NewContextAsync(new()
    {
        BaseURL = WebApplication.BaseUrl,
        Timeout = 10_000
    });

    [TestCleanup]
    public async Task DisposeRequestContext()
    {
        if (request is not null) await request.DisposeAsync();
    }

    [TestMethod]
    public async Task Http_PageAndStaticAssets_Return200()
    {
        var page = await request.GetAsync("/");
        Assert.AreEqual(200, page.Status);
        StringAssert.Contains(await page.TextAsync(), "Date Time Checker");
        foreach (var asset in new[] { "/css/site.css", "/img/logo_fpt.png" })
        {
            var response = await request.GetAsync(asset);
            Assert.AreEqual(200, response.Status, asset);
            Assert.IsTrue((await response.BodyAsync()).Length > 0, asset);
        }
    }

    [TestMethod]
    public async Task Http_Check_WithAntiforgery_ReturnsExistingMessage()
    {
        var response = await PostWithTokenAsync("check", "29", "02", "2000");
        Assert.AreEqual(200, response.Status);
        StringAssert.Contains(await response.TextAsync(), "29/02/2000 is correct date time!");
    }

    [TestMethod]
    public async Task Http_Clear_WithAntiforgery_EmptiesFields()
    {
        var response = await PostWithTokenAsync("clear", "12", "10", "2000");
        Assert.AreEqual(200, response.Status);
        var html = await response.TextAsync();
        foreach (var field in new[] { "Day", "Month", "Year" })
        {
            var match = Regex.Match(html, $"<input\\b[^>]*name=\"{field}\"[^>]*value=\"([^\"]*)\"",
                RegexOptions.CultureInvariant, TimeSpan.FromSeconds(1));
            Assert.IsTrue(match.Success, $"Input field missing: {field}");
            Assert.AreEqual(string.Empty, WebUtility.HtmlDecode(match.Groups[1].Value), field);
        }
    }

    [TestMethod]
    public async Task Http_PostWithoutAntiforgery_IsRejected()
    {
        var form = request.CreateFormData();
        form.Set("Day", "29");
        form.Set("Month", "02");
        form.Set("Year", "2000");
        form.Set("action", "check");
        var response = await request.PostAsync("/", new() { Form = form });
        Assert.AreEqual(400, response.Status, "The existing Razor Pages antiforgery protection must remain enabled.");
    }

    private async Task<IAPIResponse> PostWithTokenAsync(string action, string day, string month, string year)
    {
        var page = await request.GetAsync("/");
        Assert.AreEqual(200, page.Status);
        var html = await page.TextAsync();
        var match = Regex.Match(html,
            "<input\\b[^>]*name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)\"",
            RegexOptions.CultureInvariant, TimeSpan.FromSeconds(1));
        Assert.IsTrue(match.Success, "The real form must supply an antiforgery token.");
        // This context retains the paired antiforgery cookie from GET.
        var form = request.CreateFormData();
        form.Set("Day", day);
        form.Set("Month", month);
        form.Set("Year", year);
        form.Set("action", action);
        form.Set("__RequestVerificationToken", WebUtility.HtmlDecode(match.Groups[1].Value));
        return await request.PostAsync("/", new() { Form = form });
    }
}
