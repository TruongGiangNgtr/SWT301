#Requires -Version 7.0
[CmdletBinding()]
param([ValidateRange(1024,65535)][int]$Port = 5090, [switch]$NoBrowser, [switch]$DashboardOnly)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$previous = Get-Location
$server = $null
try {
    Set-Location -LiteralPath $repo
    $environmentFile = $env:SWT301_ENV_FILE
    if (!$environmentFile) { $environmentFile = Join-Path (Split-Path $repo -Parent) 'tools-swt301/env.ps1' }
    if (Test-Path -LiteralPath $environmentFile) { . $environmentFile }
    elseif ($env:SWT301_ENV_FILE) { throw "Environment file missing: $environmentFile" }
    Import-Module (Join-Path $PSScriptRoot 'dashboard-client.psm1') -Force
    $url = "http://127.0.0.1:$Port"
    $reuse = $false
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
    try { $listener.Start() }
    catch {
        try { $null = Get-DashboardState $url; $reuse = $true }
        catch { throw "Port $Port is occupied by an incompatible server. Close it yourself or select another -Port. No process was stopped." }
    }
    finally { $listener.Stop() }
    if (!$reuse) {
        dotnet build SWT.slnx -c Release --nologo
        if ($LASTEXITCODE -ne 0) { throw 'Build failed; dashboard was not started.' }
        # Run an isolated copy, so a dashboard-triggered build can replace the normal outputs on Windows.
        $runtime = Join-Path $repo ('TestResults/dashboard-host/' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $runtime -Force | Out-Null
        Copy-Item -Path (Join-Path $repo 'apps/web/bin/Release/net10.0/*') -Destination $runtime -Recurse
        $env:SWT301_DASHBOARD = '1'
        $env:SWT301_PWSH = Join-Path $PSHOME 'pwsh.exe'
        $info = [Diagnostics.ProcessStartInfo]::new((Get-Command dotnet -CommandType Application).Source)
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        foreach ($argument in @((Join-Path $runtime 'SWT.dll'), '--contentRoot', (Join-Path $repo 'apps/web'),
        '--urls', $url, '--Logging:LogLevel:Default', 'Warning', '--Logging:LogLevel:Microsoft.Hosting.Lifetime', 'Information')) {
            $info.ArgumentList.Add($argument)
        }
        $server = [Diagnostics.Process]::Start($info)
        $ready = $false
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        while (!$server.HasExited -and [DateTime]::UtcNow -lt $deadline) {
            try {
                $response = Invoke-WebRequest "$url/dashboard" -TimeoutSec 2
                if ($response.StatusCode -eq 200) { $ready = $true; break }
            } catch { Start-Sleep -Milliseconds 200 }
        }
        if (!$ready) { throw 'Dashboard did not start within 30 seconds.' }
    }
    else { Write-Host 'Using the existing SWT301 dashboard. This window does not own that server.' }
    Write-Host "Dashboard: $url/dashboard"
    if (!$NoBrowser) { Start-Process "$url/dashboard" | Out-Null }
    if (!$DashboardOnly) {
        Write-Host 'Console and dashboard share one queue. Select 1-8 below; 0 closes this workspace window.'
        $env:SWT301_SHOW_WINDOWS = '1'
        & (Join-Path $PSHOME 'pwsh.exe') -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $PSScriptRoot 'test-menu.ps1') -DashboardUrl $url
        if ($LASTEXITCODE -ne 0) { throw "Console menu exited with code $LASTEXITCODE." }
    }
    elseif ($server) {
        Write-Host 'Dashboard-only mode. Ctrl+C stops the owned server.'
        while (!$server.WaitForExit(500)) { }
        if ($server.ExitCode -ne 0) { throw "Dashboard exited with code $($server.ExitCode)." }
    }
}
finally {
    if ($server) {
        if (!$server.HasExited) { $server.Kill($true); $null = $server.WaitForExit(10000) }
        $server.Dispose()
    }
    Set-Location -LiteralPath $previous
}
