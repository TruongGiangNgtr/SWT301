# Historical test records

`TEST_CASES.md` and `TEST_REPORT.md` preserve the earlier desktop test documents
unchanged. The report claims 8/8 console tests passed on 2026-09-22; that is a
historical claim, not a result verified in this migration. `SWT.Tests.csproj` is
absent from the current source and solution. Old desktop commands, behavior
statements and references must not be used as current execution instructions.

Use the [current plan](../TEST_CASES.md), [current report](../TEST_REPORT.md) and
[testing guide](../../testing-guide/README.md). Desktop close confirmation,
input trimming, output padding and performance claims in old records do not
establish the current web implementation's conformance.
