using NUnit.Framework;
using SWT;

namespace SWT.NUnitTests;

[TestFixture]
public sealed class DateValidatorTests
{
    // Lab 2 Function B: the nine columns with complete input and expected-return data.
    [TestCase(2018, 1, 31, TestName = "UTCID01_DaysInMonth_January2018_Returns31")]
    [TestCase(2018, 4, 30, TestName = "UTCID02_DaysInMonth_April2018_Returns30")]
    [TestCase(2015, 13, 0, TestName = "UTCID03_DaysInMonth_Month13_Returns0")]
    [TestCase(2015, 0, 0, TestName = "UTCID04_DaysInMonth_Month0_Returns0")]
    [TestCase(2015, 12, 31, TestName = "UTCID05_DaysInMonth_December2015_Returns31")]
    [TestCase(2020, 1, 31, TestName = "UTCID06_DaysInMonth_January2020_Returns31")]
    [TestCase(2000, 2, 29, TestName = "UTCID07_DaysInMonth_February2000_Returns29")]
    [TestCase(2020, 2, 29, TestName = "UTCID08_DaysInMonth_February2020_Returns29")]
    [TestCase(2018, 2, 28, TestName = "UTCID09_DaysInMonth_February2018_Returns28")]
    public void DaysInMonth_ReturnsExpectedValue(int year, int month, int expectedDays)
    {
        var actualDays = DateValidator.DayInMonth(year, month);

        Assert.That(actualDays, Is.EqualTo(expectedDays));
    }

    // Lab 2 Function A calls this CheckDate; the implementation exposes it as IsValidDate.
    // UTCID08 has no Month value in Lab 2, and UTCID14-15 have no input or expected result.
    [TestCase(2009, 1, 1, true, TestName = "UTCID01_CheckDate_2009_01_01_IsTrue")]
    [TestCase(2009, 12, 31, true, TestName = "UTCID02_CheckDate_2009_12_31_IsTrue")]
    [TestCase(2009, 3, 30, true, TestName = "UTCID03_CheckDate_2009_03_30_IsTrue")]
    [TestCase(2000, 2, 29, true, TestName = "UTCID04_CheckDate_2000_02_29_IsTrue")]
    [TestCase(2009, 2, 28, true, TestName = "UTCID05_CheckDate_2009_02_28_IsTrue")]
    [TestCase(2009, 2, 29, false, TestName = "UTCID06_CheckDate_2009_02_29_IsFalse")]
    [TestCase(2009, 12, 0, false, TestName = "UTCID07_CheckDate_2009_12_00_IsFalse")]
    [TestCase(2000, 0, 1, false, TestName = "UTCID09_CheckDate_2000_00_01_IsFalse")]
    [TestCase(2009, 13, 1, false, TestName = "UTCID10_CheckDate_2009_13_01_IsFalse")]
    [TestCase(2009, 4, 31, false, TestName = "UTCID11_CheckDate_2009_04_31_IsFalse")]
    [TestCase(2020, 2, 30, false, TestName = "UTCID12_CheckDate_2020_02_30_IsFalse")]
    [TestCase(2009, 4, 30, true, TestName = "UTCID13_CheckDate_2009_04_30_IsTrue")]
    public void CheckDate_ReturnsExpectedValue(int year, int month, int day, bool expectedValidity)
    {
        var isValid = DateValidator.IsValidDate(year, month, day);

        Assert.That(isValid, Is.EqualTo(expectedValidity));
    }
}
