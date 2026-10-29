[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('unit', 'web-e2e', 'ai-assisted', 'http-integration', 'api', 'visual')][string]$Suite,
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Release',
    [string]$ResultsDirectory = 'TestResults/ci',
    [switch]$ShowUi,
    [ValidateRange(0, 2000)][int]$SlowMo = 500
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = Split-Path $PSScriptRoot -Parent
$definitions = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'test-suites.json') -Raw | ConvertFrom-Json
$definition = $definitions.suites | Where-Object { $_.id -eq $Suite }
if (@($definition).Count -ne 1) { throw "Unknown or duplicate suite: $Suite" }
$project = Join-Path $repo $definition.project
if (-not (Test-Path -LiteralPath $project)) { throw "Missing project: $project" }
$resultsRoot = if ([IO.Path]::IsPathRooted($ResultsDirectory)) {
    [IO.Path]::GetFullPath($ResultsDirectory)
} else { [IO.Path]::GetFullPath((Join-Path (Get-Location) $ResultsDirectory)) }
$suiteDirectory = Join-Path $resultsRoot $Suite
$runId = [Guid]::NewGuid().ToString('N')
$runDirectory = Join-Path $suiteDirectory $runId
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
$metadataFile = Join-Path $suiteDirectory 'latest.json'
$metadata = [ordered]@{
    suite = $Suite
    runId = $runId
    startedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    configuration = $Configuration
    showUi = [bool]$ShowUi
    project = $definition.project
    filter = $definition.filter
    expectedTests = @($definition.tests).Count
    discoveryExitCode = $null
    discoveredTests = @()
    testExitCode = $null
    state = 'NotExecuted'
    trx = "$runId/tests.trx"
    error = $null
}

function Save-Metadata {
    $metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $metadataFile -Encoding utf8
}

Save-Metadata
$previousVisualOutput = $env:SWT_VISUAL_OUTPUT
if ($Suite -eq 'visual') { $env:SWT_VISUAL_OUTPUT = Join-Path $runDirectory 'visual' }
try {
    $arguments = @('test', $project, '--configuration', $Configuration,
        '--no-build', '--no-restore', '--filter', $definition.filter)
    $discovery = @(& dotnet @arguments --list-tests 2>&1 | ForEach-Object { $line = $_.ToString(); Write-Host $line; $line })
    $metadata.discoveryExitCode = $LASTEXITCODE
    $discovery | Set-Content -LiteralPath (Join-Path $runDirectory 'discovery.txt') -Encoding utf8
    $lines = @($discovery | ForEach-Object { $_.Trim() })
    $metadata.discoveredTests = @($definition.tests | Where-Object { $lines -ccontains $_ })
    if ($metadata.discoveryExitCode -ne 0 -or
        $metadata.discoveredTests.Count -ne @($definition.tests).Count) {
        throw "Discovery guard failed for $Suite`: expected $(@($definition.tests).Count) named cases, found $($metadata.discoveredTests.Count); exit $($metadata.discoveryExitCode)."
    }

    $metadata.state = 'Running'
    Save-Metadata
    $runSettings = @()
    if ($ShowUi) {
        if ($Suite -ne 'web-e2e') { throw '-ShowUi applies to web-e2e. Visual gates retain their reviewed headless rendering environment.' }
        $runSettings = @('--', 'Playwright.BrowserName=chromium', 'Playwright.LaunchOptions.Headless=false',
            "Playwright.LaunchOptions.SlowMo=$SlowMo")
        Write-Host "Live browser: Chromium, $SlowMo ms between operations. Watch the test browser window."
    }
    $execution = @(& dotnet @arguments --logger 'trx;LogFileName=tests.trx' `
        --logger 'console;verbosity=normal' --results-directory $runDirectory `
        --blame-hang --blame-hang-timeout 2m @runSettings 2>&1 | ForEach-Object { $line = $_.ToString(); Write-Host $line; $line })
    $metadata.testExitCode = $LASTEXITCODE
    $metadata.state = 'Executed'
    $execution | Set-Content -LiteralPath (Join-Path $runDirectory 'execution.txt') -Encoding utf8
}
catch {
    $metadata.error = $_.Exception.Message
    Write-Warning $metadata.error
}
finally {
    if ($Suite -eq 'visual') { $env:SWT_VISUAL_OUTPUT = $previousVisualOutput }
    $metadata.finishedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    Save-Metadata
}

# A zero exit code is insufficient: validate fresh TRX counts, outcomes and names.
& (Join-Path $PSScriptRoot 'summarize-tests.ps1') -ResultsDirectory $resultsRoot -Suite $Suite
