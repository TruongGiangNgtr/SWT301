using NUnit.Framework;
using SWT;

namespace SWT.NUnitTests;

/// <summary>AI-proposed cases reviewed and approved by the user on 2026-10-08.</summary>
[TestFixture]
[Category("AiReviewed")]
public sealed class AiReviewedCenturyTests
{
    [Test]
    public void AiReviewed_February1900_Has28Days()
    {
        // BR-001/BR-002: 1900 is divisible by 100, but not by 400.
        Assert.That(DateValidator.DayInMonth(1900, 2), Is.EqualTo(28));
    }

    [Test]
    public void AiReviewed_February28_1900_IsValid()
    {
        // BR-003: the last day in this month is valid.
        Assert.That(DateValidator.IsValidDate(1900, 2, 28), Is.True);
    }

    [Test]
    public void AiReviewed_February29_1900_IsInvalid()
    {
        // BR-003: the following day exceeds DaysInMonth.
        Assert.That(DateValidator.IsValidDate(1900, 2, 29), Is.False);
    }
}
