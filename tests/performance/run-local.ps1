[CmdletBinding()]
param(
    [string]$K6Path = 'k6',
    [string]$WorkloadFile = (Join-Path $PSScriptRoot 'local-characterization.json'),
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Release',
    [string]$ResultsDirectory = 'TestResults/performance'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$workload = Get-Content -LiteralPath $WorkloadFile -Raw | ConvertFrom-Json
if ($workload.virtualUsers -lt 1 -or -not $workload.duration -or -not $workload.approval) {
    throw 'Use an explicitly reviewed workload file; do not invent acceptance thresholds.'
}
$executable = (Get-Command $K6Path -ErrorAction Stop).Source
$resultsRoot = if ([IO.Path]::IsPathRooted($ResultsDirectory)) {
    [IO.Path]::GetFullPath($ResultsDirectory)
} else { [IO.Path]::GetFullPath((Join-Path (Get-Location) $ResultsDirectory)) }
$runDirectory = Join-Path $resultsRoot ([Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
Copy-Item -LiteralPath $WorkloadFile -Destination (Join-Path $runDirectory 'workload.json')
$project = Join-Path $repo 'apps/web/SWT.csproj'
$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = 'dotnet'
$startInfo.WorkingDirectory = Split-Path $project -Parent
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
foreach ($argument in @('run', '--project', $project, '--configuration', $Configuration,
    '--no-build', '--no-restore', '--no-launch-profile', '--', '--urls', 'http://127.0.0.1:0')) {
    $startInfo.ArgumentList.Add($argument)
}
$startInfo.Environment['DOTNET_ENVIRONMENT'] = 'Development'
$startInfo.Environment['ASPNETCORE_ENVIRONMENT'] = 'Development'
$startInfo.Environment['Logging__LogLevel__Default'] = 'Warning'
$startInfo.Environment['Logging__LogLevel__Microsoft.Hosting.Lifetime'] = 'Information'
foreach ($variable in @('ASPNETCORE_URLS', 'ASPNETCORE_HTTP_PORTS', 'ASPNETCORE_HTTPS_PORTS',
    'DOTNET_URLS', 'DOTNET_HTTP_PORTS', 'DOTNET_HTTPS_PORTS')) {
    $startInfo.Environment.Remove($variable) | Out-Null
}
$server = [Diagnostics.Process]::new()
$server.StartInfo = $startInfo
$metadata = [ordered]@{
    configuration = $Configuration
    status = 'NotExecuted'
    thresholdVerdict = if ($workload.thresholds.PSObject.Properties.Count -gt 0) { 'DEMO_THRESHOLDS: k6 exit code and exported thresholdResults apply; not NFR-003' } else { 'NOT_EVALUATED: characterization only' }
    runDirectory = $runDirectory
    logging = 'Default Warning; Microsoft.Hosting.Lifetime Information'
    serverStopped = $false
}
$startupLines = [Collections.Generic.List[string]]::new()
$stderrTask = $null
$stdoutTask = $null
$ownedServerStarted = $false
$savedEnvironment = @{}
try {
    $ownedServerStarted = $server.Start()
    if (-not $ownedServerStarted) { throw 'Local server process did not start.' }
    $metadata.serverPid = $server.Id
    $stderrTask = $server.StandardError.ReadToEndAsync()
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(45)
    $lineTask = $server.StandardOutput.ReadLineAsync()
    $baseUrl = $null
    while ([DateTimeOffset]::UtcNow -lt $deadline) {
        if ($server.HasExited) { throw "Local server exited with code $($server.ExitCode)." }
        if ($lineTask.IsCompleted) {
            $line = $lineTask.GetAwaiter().GetResult()
            if ($null -eq $line) { throw 'Server console output ended before readiness.' }
            $startupLines.Add($line)
            if ($line -match 'Now listening on:\s+(http://127\.0\.0\.1:\d+)') {
                $baseUrl = $Matches[1]
                break
            }
            $lineTask = $server.StandardOutput.ReadLineAsync()
        }
        Start-Sleep -Milliseconds 50
    }
    if (-not $baseUrl) { throw 'No listening address within 45 seconds.' }
    $stdoutTask = $server.StandardOutput.ReadToEndAsync()
    $metadata.baseUrl = $baseUrl
    $client = [Net.Http.HttpClient]::new()
    $client.Timeout = [TimeSpan]::FromSeconds(2)
    try {
        $ready = $false
        while ([DateTimeOffset]::UtcNow -lt $deadline) {
            if ($server.HasExited) { throw 'Server exited while waiting for HTTP readiness.' }
            try {
                $response = $client.GetAsync($baseUrl).GetAwaiter().GetResult()
                try { $ready = $response.IsSuccessStatusCode } finally { $response.Dispose() }
            } catch [Net.Http.HttpRequestException] { } catch [Threading.Tasks.TaskCanceledException] { }
            if ($ready) { break }
            Start-Sleep -Milliseconds 100
        }
        if (-not $ready) { throw 'Local page did not become ready within startup budget.' }
    } finally { $client.Dispose() }

    $values = @{
        PROFILE = if ($workload.profile) { [string]$workload.profile } else { 'characterization' }
        STAGES_JSON = if ($workload.stages) { ConvertTo-Json -InputObject @($workload.stages) -Compress } else { '[]' }
        BASE_URL = $baseUrl
        VUS = [string]$workload.virtualUsers
        DURATION = [string]$workload.duration
        THRESHOLDS_JSON = ($workload.thresholds | ConvertTo-Json -Compress)
    }
    foreach ($name in $values.Keys) {
        $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable($name, $values[$name], 'Process')
    }
    $metadata.status = 'Running'
    $metadata.startedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    Push-Location $runDirectory
    try {
        & $executable version | Set-Content -LiteralPath 'k6-version.txt'
        & $executable run --no-usage-report --quiet --no-color --out json=metrics.json `
            (Join-Path $PSScriptRoot 'date-time-checker.js') 2>&1 | Tee-Object -FilePath 'execution.txt'
        $metadata.exitCode = $LASTEXITCODE
    } finally { Pop-Location }
    $metadata.finishedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    if ($metadata.exitCode -ne 0) { throw "k6 failed with exit code $($metadata.exitCode)." }
    $measurements = Get-Content -LiteralPath (Join-Path $runDirectory 'measurements.json') -Raw | ConvertFrom-Json
    if ($measurements.httpRequests.count -le 0 -or $measurements.workflowErrors.rate -ne 0 -or
        $measurements.checks.fails -gt 0) {
        throw 'The HTTP workflow checks did not all succeed; do not treat this run as valid performance evidence.'
    }
    $metadata.status = 'Executed'
    Write-Host "Local k6 evidence: $runDirectory (HTTP measurements; no NFR acceptance conclusion)."
}
catch {
    $metadata.status = 'Failed'
    $metadata.error = $_.Exception.Message
    throw
}
finally {
    foreach ($name in $savedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
    }
    if ($ownedServerStarted) {
        if (-not $server.HasExited) { $server.Kill($true) }
        if (-not $server.WaitForExit(10000)) { throw 'Owned local server did not stop within 10 seconds.' }
        $metadata.serverStopped = $server.HasExited
        $startupLines | Set-Content -LiteralPath (Join-Path $runDirectory 'server-startup.txt')
        if ($stdoutTask) { $stdoutTask.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $runDirectory 'server-stdout.txt') }
        if ($stderrTask) { $stderrTask.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $runDirectory 'server-stderr.txt') }
    }
    $server.Dispose()
    $metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runDirectory 'run.json')
}
