using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.Playwright;
using Microsoft.Playwright.MSTest;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace DateTimeChecker.PlaywrightTests;

[TestClass]
[TestCategory("VisualRegression")]
[DoNotParallelize]
public sealed class DateTimeCheckerVisualRegressionTests : PageTest
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
    public async Task DateTimeChecker_MatchesApprovedWindowsBaseline()
    {
        var root = FindRepositoryRoot();
        var environment = Environment.GetEnvironmentVariable("SWT_VISUAL_BASELINE") ?? "windows-10-chromium-140";
        Assert.IsTrue(environment is "windows-10-chromium-140" or "windows-2025-chromium-140", "Choose an explicitly reviewed baseline environment.");
        var baselineDirectory = Path.Combine(root, "tests", "visual", "baselines", environment);
        using var document = JsonDocument.Parse(await File.ReadAllTextAsync(Path.Combine(baselineDirectory, "approval.json")));
        var approval = document.RootElement;
        Assert.AreEqual("APPROVED", approval.GetProperty("status").GetString());
        Assert.AreEqual(approval.GetProperty("os").GetString(), RuntimeInformation.OSDescription,
            "Use the approved Windows environment; review a separate baseline for a different OS.");
        Assert.AreEqual("chromium", BrowserName);
        Assert.AreEqual(approval.GetProperty("browserVersion").GetString(), Browser.Version,
            "A browser version change requires baseline review.");
        var fontPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Fonts), "arial.ttf");
        Assert.AreEqual(approval.GetProperty("arialSha256").GetString(),
            Convert.ToHexString(SHA256.HashData(await File.ReadAllBytesAsync(fontPath))).ToLowerInvariant(),
            "The Arial font differs from the approved environment.");
        var baseline = Path.Combine(baselineDirectory, "date-time-checker.png");
        Assert.AreEqual(approval.GetProperty("imageSha256").GetString(),
            Convert.ToHexString(SHA256.HashData(await File.ReadAllBytesAsync(baseline))).ToLowerInvariant(),
            "The approved baseline was changed without an updated review record.");

        var output = Environment.GetEnvironmentVariable("SWT_VISUAL_OUTPUT")
            ?? Path.Combine(root, "TestResults", "visual-regression", Guid.NewGuid().ToString("N"));
        output = Path.GetFullPath(output);
        Directory.CreateDirectory(output);
        await Page.GotoAsync(WebApplication.BaseUrl, new() { WaitUntil = WaitUntilState.Load });
        await Page.EvaluateAsync("""
            async () => {
                await document.fonts.ready;
                await Promise.all([...document.images].map(image => image.decode()));
            }
            """);
        var actual = Path.Combine(output, "actual.png");
        await Page.ScreenshotAsync(new()
        {
            Path = actual, FullPage = false, Animations = ScreenshotAnimations.Disabled,
            Caret = ScreenshotCaret.Hide, Scale = ScreenshotScale.Css
        });
        var startInfo = new ProcessStartInfo
        {
            FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),
                "WindowsPowerShell", "v1.0", "powershell.exe"),
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        foreach (var argument in new[]
        {
            "-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File",
            Path.Combine(root, "tests", "visual", "compare-screenshots.ps1"),
            "-Baseline", baseline, "-Actual", actual, "-OutputDirectory", output
        }) startInfo.ArgumentList.Add(argument);
        using var process = Process.Start(startInfo)
            ?? throw new InvalidOperationException("Screenshot comparison process did not start.");
        var stdout = process.StandardOutput.ReadToEndAsync();
        var stderr = process.StandardError.ReadToEndAsync();
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(30));
        try { await process.WaitForExitAsync(timeout.Token); }
        catch
        {
            if (!process.HasExited) process.Kill(entireProcessTree: true);
            using var cleanup = new CancellationTokenSource(TimeSpan.FromSeconds(10));
            await process.WaitForExitAsync(cleanup.Token);
            throw;
        }
        Console.WriteLine($"Visual evidence: {output}\n{await stdout}");
        Assert.AreEqual(0, process.ExitCode,
            $"Screenshot differs from approved baseline. Review actual.png, diff.png and comparison.json in {output}.\n{await stderr}");
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
