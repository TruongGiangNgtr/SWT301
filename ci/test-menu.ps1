#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('unit','api','newman','web-e2e','mobile','performance-characterization',
        'performance-load','performance-stress','visual','ai-assisted','http-integration','all','results','ci')]
    [string]$Run,
    [switch]$NoLocalEnvironment
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = Split-Path $PSScriptRoot -Parent
$previousLocation = Get-Location
try {
    Set-Location -LiteralPath $repo
    # Optional sidecar created by local setup; the repository never needs a personal path.
    if (!$NoLocalEnvironment) {
        $environmentFile = $env:SWT301_ENV_FILE
        if (!$environmentFile) { $environmentFile = Join-Path (Split-Path $repo -Parent) 'tools-swt301/env.ps1' }
        if (Test-Path -LiteralPath $environmentFile -PathType Leaf) {
            Write-Host "Using optional local environment: $environmentFile"
            . $environmentFile
        }
        elseif ($env:SWT301_ENV_FILE) { throw "Configured SWT301_ENV_FILE not found: $environmentFile" }
    }
    Import-Module (Join-Path $PSScriptRoot 'test-runner.psm1') -Force
    Initialize-TestRunner -Repository $repo

    if ($Run) {
        switch ($Run) {
            'all' { $ok = Invoke-AllLocalTests -Unattended; if (!$ok) { exit 1 } }
            'results' { Show-RunnerResults }
            'ci' { Show-CiMenu -Unattended }
            default {
                $result = Invoke-LocalSuite -Name $Run -Unattended
                if ($result.status -ne 'PASSED') { exit 1 }
            }
        }
        exit 0
    }

    :MainMenu while ($true) {
        Write-Host @'

==================================================
             SWT301 - TEST RUNNER
==================================================

  [1] Unit Testing           - NUnit
  [2] API Testing            - Playwright / Newman
  [3] Web E2E Testing        - Playwright
  [4] Mobile Testing         - Appium
  [5] Performance Testing    - k6
  [6] Visual Regression      - Playwright
  [7] AI-assisted Testing    - NUnit
  [8] CI/CD                  - GitHub Actions

  [9] HTTP Integration Testing

  [A] Run All Available Local Tests
  [S] View Test Results
  [0] Exit

==================================================
'@
        $choice = Read-RunnerInput 'Enter your choice'
        if ($null -eq $choice -or $choice -eq '0') { break }
        $selection = $null
        try {
            switch ($choice.Trim().ToUpperInvariant()) {
                '1' { $selection = 'unit' }
                '2' {
                    Write-Host '[1] Playwright API   [2] Newman   [0] Back'
                    switch (Read-RunnerInput 'API runner') {
                        '1' { $selection = 'api' }
                        '2' { $selection = 'newman' }
                        '0' { continue MainMenu }
                        default { Write-Host 'No API runner selected.'; continue MainMenu }
                    }
                }
                '3' { $selection = 'web-e2e' }
                '4' { $selection = 'mobile' }
                '5' {
                    Write-Host '[1] Characterization   [2] Load   [3] Stress   [0] Back'
                    switch (Read-RunnerInput 'Existing workload') {
                        '1' { $selection = 'performance-characterization' }
                        '2' { $selection = 'performance-load' }
                        '3' { $selection = 'performance-stress' }
                        '0' { continue MainMenu }
                        default { Write-Host 'No workload selected.'; continue MainMenu }
                    }
                }
                '6' { $selection = 'visual' }
                '7' { $selection = 'ai-assisted' }
                '8' { Show-CiMenu }
                '9' { $selection = 'http-integration' }
                'A' {
                    Write-Host 'Sequential local run: six .NET suites, Newman, three k6 workloads and mobile.'
                    Write-Host 'Missing prerequisites are reported as ENVIRONMENT BLOCKED. GitHub is not dispatched.'
                    if ((Read-RunnerInput 'Run these local suites? [y/N]') -match '^(y|yes)$') {
                        $null = Invoke-AllLocalTests -Unattended
                    }
                    else { Write-Host 'NOT EXECUTED - local run cancelled.' }
                }
                'S' { Show-RunnerResults -Interactive }
                default { Write-Host 'Invalid choice. Enter 1-9, A, S or 0.'; continue MainMenu }
            }
            if ($selection) { $null = Invoke-LocalSuite -Name $selection }
        }
        catch { Write-Host "Runner error: $($_.Exception.Message)" -ForegroundColor Red }
        if ($null -eq (Read-RunnerInput 'Press Enter to return to menu')) { break }
    }
    Write-Host 'Exiting SWT301 Test Runner.'
}
catch {
    Write-Host "Runner could not start: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally { Set-Location -LiteralPath $previousLocation }
