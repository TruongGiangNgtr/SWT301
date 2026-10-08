using Microsoft.Playwright;
using Microsoft.Playwright.MSTest;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace DateTimeChecker.PlaywrightTests;

[TestClass]
[DoNotParallelize]
public sealed class DateTimeCheckerTests : PageTest
{
    private static readonly WebApplicationFixture WebApplication = new();
    private static string BaseUrl => WebApplication.BaseUrl;

    [ClassInitialize]
    public static Task StartWebApplication(TestContext _) => WebApplication.StartAsync();

    [ClassCleanup]
    public static Task StopWebApplication() => WebApplication.DisposeAsync().AsTask();

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

}
