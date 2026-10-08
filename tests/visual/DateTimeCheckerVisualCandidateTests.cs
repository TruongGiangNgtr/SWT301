using System.Runtime.InteropServices;
using System.Text.Json;
using Microsoft.Playwright;
using Microsoft.Playwright.MSTest;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace DateTimeChecker.PlaywrightTests;

/// <summary>Captures review candidates; this is not an approved-baseline regression gate.</summary>
[TestClass]
[TestCategory("VisualCandidate")]
[DoNotParallelize]
public sealed class DateTimeCheckerVisualCandidateTests : PageTest
{
    private static readonly WebApplicationFixture WebApplication = new();

    [ClassInitialize]
    public static Task StartWebApplication(TestContext _) => WebApplication.StartAsync();

    [ClassCleanup]
    public static Task StopWebApplication() => WebApplication.DisposeAsync().AsTask();

    public override BrowserNewContextOptions ContextOptions() => new()
    {
        ViewportSize = new() { Width = 1280, Height = 720 },
        DeviceScaleFactor = 1,
        Locale = "en-US",
        TimezoneId = "Asia/Bangkok",
        ColorScheme = ColorScheme.Light,
        ReducedMotion = ReducedMotion.Reduce
    };

    [TestMethod]
    public async Task Capture_DateTimeChecker_WindowsCandidate()
    {
        Assert.IsTrue(OperatingSystem.IsWindows(), "The reviewed candidate configuration is Windows only.");
        Assert.AreEqual("chromium", BrowserName, "The candidate requires Chromium, not another engine.");
        var root = FindRepositoryRoot();
        var output = Environment.GetEnvironmentVariable("SWT_VISUAL_OUTPUT")
            ?? Path.Combine(root, "TestResults", "visual-candidates", Guid.NewGuid().ToString("N"));
        output = Path.GetFullPath(output);
        Directory.CreateDirectory(output);

        await Page.GotoAsync(WebApplication.BaseUrl, new() { WaitUntil = WaitUntilState.Load });
        await Expect(Page.GetByRole(AriaRole.Heading, new() { Name = "Date Time Checker" })).ToBeVisibleAsync();
        await Expect(Page.GetByLabel("Day")).ToHaveValueAsync(string.Empty);
        await Expect(Page.GetByLabel("Month")).ToHaveValueAsync(string.Empty);
        await Expect(Page.GetByLabel("Year")).ToHaveValueAsync(string.Empty);
        var assetsReady = await Page.EvaluateAsync<bool>("""
            async () => {
                await document.fonts.ready;
                await Promise.all([...document.images].map(image => image.decode()));
                return document.fonts.check('16px Arial') &&
                    [...document.images].every(image => image.complete && image.naturalWidth > 0);
            }
            """);
        Assert.IsTrue(assetsReady, "Fonts and images must finish loading before capture.");
        await Page.ScreenshotAsync(new()
        {
            Path = Path.Combine(output, "candidate.png"),
            FullPage = false,
            Animations = ScreenshotAnimations.Disabled,
            Caret = ScreenshotCaret.Hide,
            Scale = ScreenshotScale.Css
        });
        // A second independent screenshot checks capture stability; neither is official.
        await Page.ScreenshotAsync(new()
        {
            Path = Path.Combine(output, "repeat.png"),
            FullPage = false,
            Animations = ScreenshotAnimations.Disabled,
            Caret = ScreenshotCaret.Hide,
            Scale = ScreenshotScale.Css
        });
        var metadata = new
        {
            status = "CANDIDATE_AWAITING_APPROVAL",
            os = RuntimeInformation.OSDescription,
            browser = BrowserName,
            browserVersion = Browser.Version,
            playwrightPackage = "1.55.0",
            viewport = new { width = 1280, height = 720 },
            deviceScaleFactor = 1,
            font = "Arial (Windows installed font)",
            locale = "en-US",
            timezone = "Asia/Bangkok",
            colorScheme = "Light",
            animations = "Disabled",
            reducedMotion = "Reduce",
            approval = "No official baseline has been approved or updated."
        };
        await File.WriteAllTextAsync(Path.Combine(output, "candidate.json"),
            JsonSerializer.Serialize(metadata, new JsonSerializerOptions { WriteIndented = true }));
        Console.WriteLine($"Visual candidate written to {output}; baseline approval pending.");
    }

    private static string FindRepositoryRoot()
    {
        for (var directory = new DirectoryInfo(AppContext.BaseDirectory);
             directory is not null; directory = directory.Parent)
        {
            if (File.Exists(Path.Combine(directory.FullName, "SWT.slnx"))) return directory.FullName;
        }
        throw new DirectoryNotFoundException("Cannot locate SWT.slnx above the test output.");
    }
}
