/*
using Microsoft.Playwright;
using Microsoft.Playwright.MSTest;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;

namespace DateTimeChecker.PlaywrightTests;

[TestClass]
public sealed class DateTimeCheckerTests : PageTest
{
    private static readonly int Port = GetAvailablePort();
    private static readonly string BaseUrl = $"http://127.0.0.1:{Port}";
    private static Process? webProcess;

    [ClassInitialize]
    public static async Task StartWebApplication(TestContext _)
    {
        var solutionRoot = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "..",
            "..",
            "..",
            ".."));
        var webAssembly = Path.Combine(
            solutionRoot,
            "SWT",
            "bin",
            "Release",
            "net10.0",
            "SWT.dll");

        webProcess = Process.Start(new ProcessStartInfo
        {
            FileName = "dotnet",
            Arguments = $"\"{webAssembly}\" --urls \"{BaseUrl}\"",
            WorkingDirectory = Path.GetDirectoryName(webAssembly)!,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        });

        var standardOutput = webProcess!.StandardOutput.ReadToEndAsync();
        var standardError = webProcess.StandardError.ReadToEndAsync();

        using var client = new HttpClient();
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(30));
        while (!timeout.IsCancellationRequested)
        {
            try
            {
                using var response = await client.GetAsync(BaseUrl, timeout.Token);
                if (response.IsSuccessStatusCode)
                {
                    return;
                }
            }
            catch (HttpRequestException)
            {
            }
            catch (TaskCanceledException)
            {
            }

            try
            {
                await Task.Delay(100, timeout.Token);
            }
            catch (TaskCanceledException)
            {
                break;
            }
        }

        if (webProcess is { HasExited: false })
        {
            webProcess.Kill(entireProcessTree: true);
            webProcess.WaitForExit();
        }

        var output = await standardOutput;
        var error = await standardError;
        throw new InvalidOperationException(
            $"The web application did not start within 30 seconds.\nOutput:\n{output}\nError:\n{error}");
    }

    [ClassCleanup]
    public static void StopWebApplication()
    {
        if (webProcess is { HasExited: false })
        {
            webProcess.Kill(entireProcessTree: true);
            webProcess.WaitForExit();
        }

        webProcess?.Dispose();
    }

    [TestMethod]
    public async Task RequiredFieldsAndButtonsArePresent()
    {
        await Page.GotoAsync(BaseUrl);

        await Expect(Page.GetByLabel("Day")).ToBeVisibleAsync();
        await Expect(Page.GetByLabel("Month")).ToBeVisibleAsync();
        await Expect(Page.GetByLabel("Year")).ToBeVisibleAsync();
        await Expect(Page.GetByRole(AriaRole.Button, new() { Name = "Clear" })).ToBeVisibleAsync();
        await Expect(Page.GetByRole(AriaRole.Button, new() { Name = "Check" })).ToBeVisibleAsync();
    }

    [TestMethod]
    public async Task Clear_ShouldClearAllInputFields()
    {
        await Page.GotoAsync(BaseUrl);

        await Page.GetByLabel("Day").FillAsync("12");
        await Page.GetByLabel("Month").FillAsync("10");
        await Page.GetByLabel("Year").FillAsync("2000");
        await Page.GetByRole(AriaRole.Button, new() { Name = "Clear" }).ClickAsync();

        await Expect(Page.GetByLabel("Day")).ToHaveValueAsync(string.Empty);
        await Expect(Page.GetByLabel("Month")).ToHaveValueAsync(string.Empty);
        await Expect(Page.GetByLabel("Year")).ToHaveValueAsync(string.Empty);
    }

    [TestMethod]
    public async Task Day_NonNumeric_ShouldShowIncorrectFormatMessage()
    {
        await Page.GotoAsync(BaseUrl);

        await Page.GetByLabel("Day").FillAsync("abc");
        await Page.GetByLabel("Month").FillAsync("01");
        await Page.GetByLabel("Year").FillAsync("2000");
        await Page.GetByRole(AriaRole.Button, new() { Name = "Check" }).ClickAsync();

        await Expect(Page.GetByText("Input data for Day is incorrect format!", new() { Exact = true }))
            .ToBeVisibleAsync();
    }

    [TestMethod]
    public async Task Day_BelowMinimum_ShouldShowOutOfRangeMessage()
    {
        await Page.GotoAsync(BaseUrl);

        await Page.GetByLabel("Day").FillAsync("0");
        await Page.GetByLabel("Month").FillAsync("01");
        await Page.GetByLabel("Year").FillAsync("2000");
        await Page.GetByRole(AriaRole.Button, new() { Name = "Check" }).ClickAsync();

        await Expect(Page.GetByText("Input data for Day is out of range!", new() { Exact = true }))
            .ToBeVisibleAsync();
    }

    [TestMethod]
    public async Task Day_AboveMaximum_ShouldShowOutOfRangeMessage()
    {
        await Page.GotoAsync(BaseUrl);

        await Page.GetByLabel("Day").FillAsync("32");
        await Page.GetByLabel("Month").FillAsync("01");
        await Page.GetByLabel("Year").FillAsync("2000");
        await Page.GetByRole(AriaRole.Button, new() { Name = "Check" }).ClickAsync();

        await Expect(Page.GetByText("Input data for Day is out of range!", new() { Exact = true }))
            .ToBeVisibleAsync();
    }

    [TestMethod]
    public async Task Day_Boundaries_ShouldPassDayRangeValidation()
    {
        await Page.GotoAsync(BaseUrl);

        await Page.GetByLabel("Day").FillAsync("1");
        await Page.GetByLabel("Month").FillAsync("1");
        await Page.GetByLabel("Year").FillAsync("2000");
        await Page.GetByRole(AriaRole.Button, new() { Name = "Check" }).ClickAsync();
        await Expect(Page.GetByText("1/1/2000 is correct date time!", new() { Exact = true }))
            .ToBeVisibleAsync();

        await Page.GotoAsync(BaseUrl);
        await Page.GetByLabel("Day").FillAsync("31");
        await Page.GetByLabel("Month").FillAsync("12");
        await Page.GetByLabel("Year").FillAsync("2000");
        await Page.GetByRole(AriaRole.Button, new() { Name = "Check" }).ClickAsync();
        await Expect(Page.GetByText("31/12/2000 is correct date time!", new() { Exact = true }))
            .ToBeVisibleAsync();
    }

    [TestMethod]
    public async Task April31_ShouldBeInvalidDate()
    {
        await Page.GotoAsync(BaseUrl);

        await Page.GetByLabel("Day").FillAsync("31");
        await Page.GetByLabel("Month").FillAsync("04");
        await Page.GetByLabel("Year").FillAsync("2024");
        await Page.GetByRole(AriaRole.Button, new() { Name = "Check" }).ClickAsync();

        await Expect(Page.GetByText("31/04/2024 is NOT correct date time!", new() { Exact = true }))
            .ToBeVisibleAsync();
    }

    [TestMethod]
    public async Task LeapYear_February29_ShouldBeValid()
    {
        await Page.GotoAsync(BaseUrl);

        await Page.GetByLabel("Day").FillAsync("29");
        await Page.GetByLabel("Month").FillAsync("02");
        await Page.GetByLabel("Year").FillAsync("2000");
        await Page.GetByRole(AriaRole.Button, new() { Name = "Check" }).ClickAsync();

        await Expect(Page.GetByText("29/02/2000 is correct date time!", new() { Exact = true }))
            .ToBeVisibleAsync();
    }

    [TestMethod]
    public async Task NonLeapYear_February29_ShouldBeInvalid()
    {
        await Page.GotoAsync(BaseUrl);

        await Page.GetByLabel("Day").FillAsync("29");
        await Page.GetByLabel("Month").FillAsync("02");
        await Page.GetByLabel("Year").FillAsync("1900");
        await Page.GetByRole(AriaRole.Button, new() { Name = "Check" }).ClickAsync();

        await Expect(Page.GetByText("29/02/1900 is NOT correct date time!", new() { Exact = true }))
            .ToBeVisibleAsync();
    }

    private static int GetAvailablePort()
    {
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        return ((IPEndPoint)listener.LocalEndpoint).Port;
    }
}
*/
