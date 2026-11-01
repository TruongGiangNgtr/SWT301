# Console adapter for the same local queue used by the web dashboard.
$ErrorActionPreference = 'Stop'

function Get-DashboardOrigin {
    param([string]$Url)
    $uri = $null
    if (![uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'http' -or
        !$uri.IsLoopback -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or $uri.AbsolutePath -ne '/') {
        throw 'Dashboard URL must be a loopback HTTP origin, e.g. http://127.0.0.1:5090.'
    }
    return $uri.GetLeftPart([UriPartial]::Authority)
}

function Get-DashboardState {
    param([string]$Url)
    $origin = Get-DashboardOrigin $Url
    $state = Invoke-RestMethod "$origin/dashboard?handler=State" -TimeoutSec 10
    if ($state.application -cne 'SWT301 Test Dashboard' -or $state.runnerProtocol -ne 1 -or !$state.enabled) {
        throw 'This address is not a compatible, enabled SWT301 dashboard. Close the old server and reopen the workspace.'
    }
    return $state
}

function Invoke-DashboardSuite {
    param([string]$Url, [string]$Name, [bool]$ShowWindows = $true)
    $origin = Get-DashboardOrigin $Url
    $null = Get-DashboardState $origin
    $page = Invoke-WebRequest "$origin/dashboard" -SessionVariable dashboardSession -TimeoutSec 10
    $token = [regex]::Match($page.Content, 'name="__RequestVerificationToken" type="hidden" value="([^"]+)"').Groups[1].Value
    if (!$token) { throw 'The dashboard did not provide an antiforgery token.' }
    $response = Invoke-WebRequest "$origin/dashboard?handler=Run" -Method Post -WebSession $dashboardSession -TimeoutSec 10 `
        -Body @{ suite=$Name; showWindows=$ShowWindows.ToString().ToLowerInvariant(); __RequestVerificationToken=$token } -SkipHttpErrorCheck
    $created = $response.Content | ConvertFrom-Json
    if ($response.StatusCode -ge 400) { throw $created.error }
    $id = $created.id
    if (!$id) { throw 'The dashboard did not return a run identifier.' }
    Write-Host "`nShared run: $id`nLive dashboard: $origin/dashboard"
    $cursor = 0L
    $deadline = [DateTime]::UtcNow.AddMinutes(46)
    while ([DateTime]::UtcNow -lt $deadline) {
        $state = Get-DashboardState $origin
        $job = @($state.jobs | Where-Object id -eq $id)[0]
        if (!$job) { throw 'The dashboard lost this run. Check the saved reports; no pass is assumed.' }
        if ($job.logCount -gt $cursor) {
            if ($cursor -lt $job.logStart) { Write-Host '[Earlier log lines are available in the saved reports.]' }
            $skip = [Math]::Max(0L, $cursor - $job.logStart)
            ($job.log -split "`n" | Select-Object -Skip $skip) | ForEach-Object { Write-Host $_ }
            $cursor = [long]$job.logCount
        }
        if ($job.status -notin @('QUEUED','RUNNING')) {
            Write-Host "Shared run completed: $($job.status)"
            if ($job.error) { Write-Host $job.error }
            return [pscustomobject]@{ status=$job.status; id=$id }
        }
        Start-Sleep -Milliseconds 400
    }
    throw 'Stopped waiting for the dashboard. Check its status and reports; no pass is assumed.'
}

Export-ModuleMember -Function Get-DashboardState,Invoke-DashboardSuite
