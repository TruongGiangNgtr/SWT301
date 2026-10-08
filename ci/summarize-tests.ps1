[CmdletBinding()]
param(
    [string]$ResultsDirectory = 'TestResults/ci',
    [ValidateSet('all', 'unit', 'web-e2e', 'ai-assisted', 'http-integration', 'api')][string]$Suite = 'all'
)

$ErrorActionPreference = 'Stop'
$definitions = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'test-suites.json') -Raw | ConvertFrom-Json
$resultsRoot = if ([IO.Path]::IsPathRooted($ResultsDirectory)) {
    [IO.Path]::GetFullPath($ResultsDirectory)
} else { [IO.Path]::GetFullPath((Join-Path (Get-Location) $ResultsDirectory)) }
New-Item -ItemType Directory -Path $resultsRoot -Force | Out-Null
$selected = @($definitions.suites | Where-Object { $Suite -eq 'all' -or $_.id -eq $Suite })
$rows = @()

foreach ($definition in $selected) {
    $expected = @($definition.tests)
    $row = [ordered]@{
        suite = $definition.id
        expected = $expected.Count
        discovered = 0
        total = 0
        executed = 0
        passed = 0
        failed = 0
        skipped = 0
        notExecuted = $expected.Count
        guardPassed = $false
        errors = @()
    }
    try {
        $directory = Join-Path $resultsRoot $definition.id
        $metadataFile = Join-Path $directory 'latest.json'
        if (-not (Test-Path -LiteralPath $metadataFile)) {
            throw 'Suite was not run: no current-run metadata.'
        }
        $metadata = Get-Content -LiteralPath $metadataFile -Raw | ConvertFrom-Json
        if ($metadata.suite -cne $definition.id -or $metadata.project -cne $definition.project -or
            $metadata.filter -cne $definition.filter -or $metadata.runId -notmatch '^[a-f0-9]{32}$' -or
            $metadata.trx -cne "$($metadata.runId)/tests.trx") {
            throw 'Run metadata does not match the configured suite.'
        }
        $discovered = @($metadata.discoveredTests)
        $row.discovered = $discovered.Count
        if ($metadata.discoveryExitCode -ne 0 -or
            (Compare-Object $expected $discovered -CaseSensitive)) {
            $row.errors += 'Discovery did not match all configured test names.'
        }
        if ($metadata.error) { $row.errors += $metadata.error }
        if ($metadata.state -cne 'Executed' -or $null -eq $metadata.testExitCode -or $metadata.testExitCode -ne 0) {
            $row.errors += "Execution did not complete successfully (state $($metadata.state), exit $($metadata.testExitCode))."
        }
        $trxPath = Join-Path $directory $metadata.trx
        if (-not (Test-Path -LiteralPath $trxPath)) { throw 'No fresh TRX file was produced by this run.' }

        $settings = [Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver = $null
        $reader = [Xml.XmlReader]::Create($trxPath, $settings)
        try {
            $document = [Xml.XmlDocument]::new()
            $document.XmlResolver = $null
            $document.Load($reader)
        }
        finally { $reader.Dispose() }
        $namespace = [Xml.XmlNamespaceManager]::new($document.NameTable)
        $namespace.AddNamespace('t', 'http://microsoft.com/schemas/VisualStudio/TeamTest/2010')
        $summary = $document.SelectSingleNode('/t:TestRun/t:ResultSummary', $namespace)
        $counters = $summary.SelectSingleNode('t:Counters', $namespace)
        if ($null -eq $counters) { throw 'TRX counters are missing.' }
        foreach ($counter in @('total', 'executed', 'passed', 'failed')) {
            $value = 0
            if (-not [int]::TryParse($counters.GetAttribute($counter), [ref]$value) -or $value -lt 0) {
                throw "Invalid TRX counter: $counter"
            }
            $row[$counter] = $value
        }
        $results = @($document.SelectNodes('/t:TestRun/t:Results/t:UnitTestResult', $namespace))
        $names = @($results | ForEach-Object { $_.GetAttribute('testName') })
        $row.skipped = @($results | Where-Object { $_.GetAttribute('outcome') -eq 'NotExecuted' }).Count
        $row.notExecuted = [Math]::Max(0, $expected.Count - $row.executed)
        if ($row.total -eq 0) { $row.errors += 'Zero tests: the suite did not execute.' }
        if ($row.total -ne $expected.Count -or $results.Count -ne $expected.Count -or
            (Compare-Object $expected $names -CaseSensitive)) {
            $row.errors += 'TRX test count/names differ from the approved suite manifest.'
        }
        if ($row.executed -ne $expected.Count -or $row.passed -ne $expected.Count -or
            $row.failed -ne 0 -or $row.skipped -ne 0 -or
            @($results | Where-Object { $_.GetAttribute('outcome') -cne 'Passed' }).Count -gt 0 -or
            $summary.GetAttribute('outcome') -notin @('Completed', 'Passed')) {
            $row.errors += 'Not every configured test executed and passed.'
        }
        $row.guardPassed = $row.errors.Count -eq 0
    }
    catch { $row.errors += $_.Exception.Message }
    $rows += [PSCustomObject]$row
}

$overallPassed = @($rows | Where-Object { -not $_.guardPassed }).Count -eq 0
$report = [ordered]@{
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    guardPassed = $overallPassed
    suites = $rows
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $resultsRoot "summary-$Suite.json") -Encoding utf8
$markdown = @(
    "## SWT301 test results ($Suite)", '',
    '| Suite | Expected | Discovered | Total | Executed | Passed | Failed | Skipped | Not executed | Guard |',
    '|---|---:|---:|---:|---:|---:|---:|---:|---:|---|'
)
foreach ($row in $rows) {
    $status = if ($row.guardPassed) { 'PASS' } else { 'FAIL' }
    $markdown += "| $($row.suite) | $($row.expected) | $($row.discovered) | $($row.total) | $($row.executed) | $($row.passed) | $($row.failed) | $($row.skipped) | $($row.notExecuted) | $status |"
    foreach ($message in $row.errors) { $markdown += "`n- $($row.suite): $message" }
}
$markdown | Set-Content -LiteralPath (Join-Path $resultsRoot "summary-$Suite.md") -Encoding utf8
$markdown | ForEach-Object { Write-Host $_ }
if ($Suite -eq 'all' -and $env:GITHUB_STEP_SUMMARY) {
    $markdown | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Encoding utf8
}
if (-not $overallPassed) { throw 'Test evidence guard failed; see JSON, Markdown, logs and TRX artifacts.' }
