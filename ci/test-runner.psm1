# Execution/report adapters for the existing suites. No test expectations live here.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

function Initialize-TestRunner {
    param([Parameter(Mandatory)][string]$Repository, [switch]$ShowUi,
        [ValidateRange(0, 2000)][int]$SlowMo = 500)
    $script:Repo = [IO.Path]::GetFullPath($Repository)
    $script:SessionId = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N')
    $script:ResultsRoot = Join-Path $script:Repo "TestResults/interactive/$script:SessionId"
    $script:History = [Collections.Generic.List[object]]::new()
    $script:BuildStamp = $null
    $script:ShowUi = [bool]$ShowUi
    $script:SlowMo = $SlowMo
    $script:Dashboard = $null
    $script:Definitions = (Read-Json (Join-Path $script:Repo 'ci/test-suites.json')).suites
}

function Read-RunnerInput {
    param([string]$Prompt)
    if ([Console]::IsInputRedirected) {
        Write-Host "$Prompt`: " -NoNewline
        $value = [Console]::In.ReadLine()
        Write-Host $value
        return $value
    }
    return Read-Host $Prompt
}

function Read-Json {
    param([string]$Path)
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Stop-Runner {
    param([string]$Message, [string]$Status = 'ENVIRONMENT BLOCKED')
    $exception = [InvalidOperationException]::new($Message)
    $exception.Data['RunnerStatus'] = $Status
    throw $exception
}

function Require-Tool {
    param([string]$Name, [string]$Hint)
    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (!$command -or ($Name -eq 'python' -and $command.Source -like '*WindowsApps*')) {
        Stop-Runner "Missing dependency: $Name. $Hint"
    }
    return $command.Source
}

function Invoke-RunnerProcess {
    param(
        [string]$File, [string[]]$Arguments, [string]$Log,
        [hashtable]$Environment = @{}, [int]$TimeoutSeconds = 900, [switch]$Quiet
    )
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $File
    $info.WorkingDirectory = $script:Repo
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    foreach ($key in $Environment.Keys) { $info.Environment[$key] = [string]$Environment[$key] }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $writer = $null
    $started = $false
    $lines = [Collections.Generic.Queue[string]]::new()
    if ($Log) {
        New-Item -ItemType Directory -Path (Split-Path $Log -Parent) -Force | Out-Null
        $writer = [IO.StreamWriter]::new($Log, $true, [Text.UTF8Encoding]::new($false))
        $writer.AutoFlush = $true
        $writer.WriteLine('> ' + $File + ' ' + ($Arguments -join ' '))
    }
    try {
        $started = $process.Start()
        if (!$started) { throw "Could not start $File" }
        $stdout = $process.StandardOutput.ReadLineAsync()
        $stderr = $process.StandardError.ReadLineAsync()
        $clock = [Diagnostics.Stopwatch]::StartNew()
        while ($null -ne $stdout -or $null -ne $stderr) {
            if ($clock.Elapsed.TotalSeconds -gt $TimeoutSeconds) { throw "Process exceeded $TimeoutSeconds seconds: $File. See $Log" }
            foreach ($stream in @('stdout','stderr')) {
                $task = if ($stream -eq 'stdout') { $stdout } else { $stderr }
                if ($null -ne $task -and $task.IsCompleted) {
                    $line = $task.GetAwaiter().GetResult()
                    if ($null -ne $line) {
                        if (!$Quiet) { Write-Host $line }
                        if ($writer) { $writer.WriteLine($line) }
                        $lines.Enqueue($line)
                        while ($lines.Count -gt 250) { $null = $lines.Dequeue() }
                    }
                    if ($stream -eq 'stdout') { $stdout = if ($null -eq $line) { $null } else { $process.StandardOutput.ReadLineAsync() } }
                    else { $stderr = if ($null -eq $line) { $null } else { $process.StandardError.ReadLineAsync() } }
                }
            }
            Start-Sleep -Milliseconds 20
        }
        if (!$process.WaitForExit(10000)) { throw "Process did not exit after closing output streams: $File" }
        return [pscustomobject]@{ ExitCode = $process.ExitCode; Lines = @($lines.ToArray()) }
    }
    finally {
        if ($started -and !$process.HasExited) {
            $process.Kill($true)
            $null = $process.WaitForExit(10000)
        }
        if ($writer) { $writer.Dispose() }
        $process.Dispose()
    }
}

function Get-SourceStamp {
    $files = foreach ($relative in @('apps/web','tests/unit','tests/web-e2e','tests/api','tests/integration','tests/visual')) {
        $stack = [Collections.Generic.Stack[string]]::new()
        $stack.Push((Join-Path $script:Repo $relative))
        while ($stack.Count) {
            foreach ($item in Get-ChildItem -LiteralPath $stack.Pop() -Force) {
                if ($item.PSIsContainer) {
                    if ($item.Name -notin @('bin','obj','node_modules','TestResults','.git')) { $stack.Push($item.FullName) }
                }
                elseif ($item.Extension -in @('.cs','.csproj','.cshtml','.props','.targets','.json')) {
                    "$($item.FullName)|$($item.Length)|$($item.LastWriteTimeUtc.Ticks)"
                }
            }
        }
    }
    $files += (Get-Item -LiteralPath (Join-Path $script:Repo 'SWT.slnx')).LastWriteTimeUtc.Ticks.ToString()
    return ($files | Sort-Object) -join "`n"
}

function Ensure-DotnetBuild {
    param($Result)
    $dotnet = Require-Tool 'dotnet' 'Install a .NET 10 SDK; restart the terminal afterward.'
    $sdk = Invoke-RunnerProcess $dotnet @('--list-sdks') -Quiet -TimeoutSeconds 20
    if ($sdk.ExitCode -ne 0 -or !@($sdk.Lines | Where-Object { $_ -match '^10\.' }).Count) {
        Stop-Runner '.NET 10 SDK not found. A runtime alone cannot build this solution.'
    }
    $stamp = Get-SourceStamp
    $outputs = @('apps/web/bin/Release/net10.0/SWT.dll',
        'tests/unit/SWT.NUnitTests/bin/Release/net10.0/SWT.NUnitTests.dll',
        'tests/web-e2e/DateTimeChecker.PlaywrightTests/bin/Release/net10.0/DateTimeChecker.PlaywrightTests.dll')
    $missing = @($outputs | Where-Object { !(Test-Path -LiteralPath (Join-Path $script:Repo $_)) })
    if ($script:BuildStamp -ceq $stamp -and !$missing.Count) {
        Write-Host 'Reusing the successful Release build from this menu session.'
        return
    }
    Write-Host 'Preparing Release build (includes NuGet restore when required)...'
    $build = Invoke-RunnerProcess $dotnet @('build','SWT.slnx','-c','Release','--nologo') $Result.log
    if ($build.ExitCode -ne 0) { Stop-Runner "Build failed (exit $($build.ExitCode)); tests were not executed. See $($Result.log)" 'NOT EXECUTED' }
    $script:BuildStamp = Get-SourceStamp
}

function Get-BrowserInstallation {
    $output = Join-Path $script:Repo 'tests/web-e2e/DateTimeChecker.PlaywrightTests/bin/Release/net10.0'
    $metadata = Join-Path $output '.playwright/package/browsers.json'
    if (!(Test-Path -LiteralPath $metadata)) { Stop-Runner 'Playwright browser metadata is missing after build. Rebuild the existing Playwright project.' }
    $entries = (Read-Json $metadata).browsers
    $browser = $entries | Where-Object name -eq 'chromium'
    $headless = $entries | Where-Object name -eq 'chromium-headless-shell'
    $cache = $env:PLAYWRIGHT_BROWSERS_PATH
    if ($cache -eq '0') { $cache = Join-Path $output '.playwright/package/.local-browsers' }
    elseif (!$cache) { $cache = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'ms-playwright' }
    elseif (![IO.Path]::IsPathRooted($cache)) { $cache = Join-Path $script:Repo $cache }
    $executables = @(
        (Join-Path $cache "chromium-$($browser.revision)/chrome-win/chrome.exe"),
        (Join-Path $cache "chromium_headless_shell-$($headless.revision)/chrome-win/headless_shell.exe")
    )
    if (@($executables | Where-Object { !(Test-Path -LiteralPath $_) }).Count) {
        Stop-Runner "Matching Playwright Chromium is missing in $cache. Install explicitly: pwsh tests/web-e2e/DateTimeChecker.PlaywrightTests/bin/Release/net10.0/playwright.ps1 install chromium"
    }
    return $browser
}

function Get-VisualEnvironment {
    param($Browser)
    if (!$IsWindows) { Stop-Runner 'Visual baselines and System.Drawing comparer require a reviewed Windows environment.' }
    $os = [Runtime.InteropServices.RuntimeInformation]::OSDescription
    $font = Join-Path ([Environment]::GetFolderPath('Fonts')) 'arial.ttf'
    if (!(Test-Path -LiteralPath $font)) { Stop-Runner 'Arial font not found; the visual environment cannot match an approved baseline.' }
    $fontHash = (Get-FileHash -LiteralPath $font).Hash.ToLowerInvariant()
    $base = Join-Path $script:Repo 'tests/visual/baselines'
    $selected = $env:SWT_VISUAL_BASELINE
    if (!$selected) {
        $matches = @(Get-ChildItem -LiteralPath $base -Directory | Where-Object {
            $file = Join-Path $_.FullName 'approval.json'
            if (Test-Path -LiteralPath $file) {
                $approval = Read-Json $file
                $approval.status -ceq 'APPROVED' -and $approval.os -ceq $os -and $approval.arialSha256 -ceq $fontHash
            }
        })
        if ($matches.Count -ne 1) { Stop-Runner "No unique approved baseline matches OS/font: $os. Set SWT_VISUAL_BASELINE to a reviewed environment. Baselines will not be modified." }
        $selected = $matches[0].Name
    }
    if ($selected -notmatch '^[a-zA-Z0-9_-]+$') { Stop-Runner 'Invalid SWT_VISUAL_BASELINE name.' }
    $directory = Join-Path $base $selected
    $approvalFile = Join-Path $directory 'approval.json'
    if (!(Test-Path -LiteralPath $approvalFile)) { Stop-Runner "Approved visual environment not found: $selected" }
    $approval = Read-Json $approvalFile
    if ($approval.status -cne 'APPROVED' -or $approval.os -cne $os -or
        $approval.arialSha256 -cne $fontHash -or $approval.browserVersion -cne $Browser.browserVersion) {
        Stop-Runner "Visual OS/font/browser mismatch for $selected. Actual OS: $os. Select a reviewed environment; no baseline update is performed."
    }
    $image = Join-Path $directory 'date-time-checker.png'
    if (!(Test-Path -LiteralPath $image) -or (Get-FileHash -LiteralPath $image).Hash.ToLowerInvariant() -cne $approval.imageSha256) {
        Stop-Runner "Approved baseline image missing or hash mismatch: $image"
    }
    Write-Host "Reviewed visual environment: $selected (exact pixel policy retained)."
    return $selected
}

function Assert-FreePort {
    param([int]$Port)
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
    try { $listener.Start() }
    catch { Stop-Runner "Local port $Port is occupied. Stop your existing demo server first; the runner will not kill it." }
    finally { $listener.Stop() }
}

function Require-PythonNode {
    $null = Require-Tool 'python' 'Install Python 3.10+ or load your local environment file. The Windows Store alias is not Python.'
    $null = Require-Tool 'node' 'Install Node.js (the repository uses Node 22).'
    $python = Invoke-RunnerProcess 'python' @('-c','import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)') -Quiet -TimeoutSeconds 10
    if ($python.ExitCode -ne 0) { Stop-Runner 'Python 3.10 or later is required.' }
    $node = Invoke-RunnerProcess 'node' @('--version') -Quiet -TimeoutSeconds 10
    if ($node.ExitCode -ne 0) { Stop-Runner 'Node.js could not start.' }
}

function Read-TrxFailure {
    param([string]$Path)
    $settings = [Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $reader = [Xml.XmlReader]::Create($Path, $settings)
    try {
        $document = [Xml.XmlDocument]::new()
        $document.XmlResolver = $null
        $document.Load($reader)
        $errorNode = $document.SelectSingleNode("//*[local-name()='UnitTestResult' and @outcome!='Passed']//*[local-name()='Message']")
        if ($errorNode) { return $errorNode.InnerText }
    }
    finally { $reader.Dispose() }
    return ''
}

function Invoke-DotnetSuite {
    param($Result)
    Ensure-DotnetBuild $Result
    $environment = @{}
    if ($Result.name -in @('web-e2e','visual')) {
        $browser = Get-BrowserInstallation
        if ($Result.name -eq 'visual') { $environment.SWT_VISUAL_BASELINE = Get-VisualEnvironment $browser }
    }
    $evidence = Join-Path $Result.directory 'evidence'
    $arguments = @('-NoProfile','-ExecutionPolicy','RemoteSigned',
        '-File',(Join-Path $script:Repo 'ci/run-tests.ps1'),'-Suite',$Result.name,
        '-Configuration','Release','-ResultsDirectory',$evidence)
    if ($script:ShowUi -and $Result.name -eq 'web-e2e') {
        $arguments += @('-ShowUi','-SlowMo',[string]$script:SlowMo)
    }
    $run = Invoke-RunnerProcess (Join-Path $PSHOME 'pwsh.exe') $arguments $Result.log $environment
    $Result.exitCode = $run.ExitCode
    $summaryFile = Join-Path $evidence "summary-$($Result.name).json"
    if (!(Test-Path -LiteralPath $summaryFile)) { Stop-Runner 'No fresh suite summary was produced. Inspect execution.log; this run is not a pass.' 'NOT EXECUTED' }
    $summary = Read-Json $summaryFile
    $row = @($summary.suites | Where-Object suite -eq $Result.name)
    if ($row.Count -ne 1) { throw 'Suite summary does not identify exactly one requested suite.' }
    $row = $row[0]
    $Result.total = $row.total; $Result.passed = $row.passed
    $Result.failed = $row.failed; $Result.skipped = $row.skipped
    $Result.reports += $summaryFile
    $Result.status = if ($run.ExitCode -eq 0 -and $summary.guardPassed -and $row.guardPassed) { 'PASSED' }
        elseif ($row.failed -gt 0) { 'FAILED' }
        elseif ($row.skipped -gt 0) { 'SKIPPED' } else { 'NOT EXECUTED' }
    $Result.message = @($row.errors) -join ' '
    $metaFile = Join-Path $evidence "$($Result.name)/latest.json"
    if (Test-Path -LiteralPath $metaFile) {
        $meta = Read-Json $metaFile
        $trx = Join-Path (Split-Path $metaFile -Parent) $meta.trx
        if (Test-Path -LiteralPath $trx) {
            $Result.reports += $trx
            $failure = Read-TrxFailure $trx
            if ($failure) { $Result.message += "`n$failure" }
        }
    }
}

function Invoke-NewmanSuite {
    param($Result)
    Require-PythonNode
    $null = Require-Tool 'npm.cmd' 'Install npm with Node.js.'
    if (!(Test-Path -LiteralPath (Join-Path $script:Repo 'tests/api/node_modules/newman/bin/newman.js'))) {
        Stop-Runner 'Newman package missing. Confirm and run: npm ci --prefix tests/api. Nothing was installed automatically.'
    }
    Assert-FreePort 5081
    Ensure-DotnetBuild $Result
    $evidence = Join-Path $Result.directory 'evidence'
    $run = Invoke-RunnerProcess 'python' @((Join-Path $script:Repo 'ci/run-postman.py')) $Result.log @{POSTMAN_RESULTS=$evidence}
    $Result.exitCode = $run.ExitCode
    $metaPath = Join-Path $evidence 'run.json'
    $reportPath = Join-Path $evidence 'newman.json'
    if (!(Test-Path -LiteralPath $metaPath) -or !(Test-Path -LiteralPath $reportPath)) {
        Stop-Runner 'Newman did not produce fresh results. Inspect execution.log and server.log.' 'NOT EXECUTED'
    }
    $meta = Read-Json $metaPath
    $report = Read-Json $reportPath
    $Result.metrics = [ordered]@{requests=$report.run.stats.requests; assertions=$report.run.stats.assertions}
    $Result.status = if ($run.ExitCode -eq 0 -and $meta.status -ceq 'Passed' -and $meta.serverStopped -and
        $report.run.stats.requests.total -gt 0 -and @($report.run.failures).Count -eq 0) { 'PASSED' } else { 'FAILED' }
    $Result.message = 'Newman reports requests/assertions, not additional NUnit/MSTest test cases.'
    if ($meta.error) { $Result.message += " $($meta.error)" }
    $Result.reports += @($metaPath,$reportPath)
}

function Invoke-PerformanceSuite {
    param($Result)
    $k6 = Require-Tool 'k6' 'Install the repository-pinned k6 2.3.0 or load your local environment file.'
    Ensure-DotnetBuild $Result
    $workload = switch ($Result.name) {
        'performance-characterization' { 'local-characterization.json' }
        'performance-load' { 'demo-load.json' }
        'performance-stress' { 'demo-stress.json' }
    }
    $evidence = Join-Path $Result.directory 'evidence'
    $run = Invoke-RunnerProcess (Join-Path $PSHOME 'pwsh.exe') @('-NoProfile','-ExecutionPolicy','RemoteSigned',
        '-File',(Join-Path $script:Repo 'tests/performance/run-local.ps1'),'-K6Path',$k6,
        '-WorkloadFile',(Join-Path $script:Repo "tests/performance/$workload"),'-ResultsDirectory',$evidence) $Result.log
    $Result.exitCode = $run.ExitCode
    $folders = @(Get-ChildItem -LiteralPath $evidence -Directory -ErrorAction SilentlyContinue)
    if ($folders.Count -ne 1) { Stop-Runner 'No unique fresh k6 evidence folder was produced.' 'NOT EXECUTED' }
    $metaPath = Join-Path $folders[0].FullName 'run.json'
    $metricsPath = Join-Path $folders[0].FullName 'measurements.json'
    if (!(Test-Path -LiteralPath $metaPath) -or !(Test-Path -LiteralPath $metricsPath)) {
        Stop-Runner 'k6 did not produce completed HTTP measurements. Inspect execution.log.' 'NOT EXECUTED'
    }
    $meta = Read-Json $metaPath
    $metrics = Read-Json $metricsPath
    $Result.metrics = $metrics
    $Result.status = if ($run.ExitCode -eq 0 -and $meta.status -ceq 'Executed' -and $meta.exitCode -eq 0 -and $meta.serverStopped) { 'PASSED' } else { 'FAILED' }
    $Result.message = if ($Result.name -eq 'performance-characterization') {
        'Execution/checks only; characterization has no acceptance thresholds. Browser NFR-003 is not evaluated.'
    } else { 'Configured HTTP demo thresholds only; browser NFR-003 is not evaluated.' }
    if ($meta.error) { $Result.message += " $($meta.error)" }
    $Result.reports += @($metaPath,$metricsPath)
}

function Invoke-MobileSuite {
    param($Result, [switch]$Unattended)
    Require-PythonNode
    $java = Require-Tool 'java' 'Install JDK 17 and set JAVA_HOME.'
    $null = Require-Tool 'npm.cmd' 'Install npm with Node.js.'
    $adb = Require-Tool 'adb' 'Install Android SDK platform-tools and add it to PATH.'
    $sdk = $env:ANDROID_HOME
    if (!$sdk) { $sdk = $env:ANDROID_SDK_ROOT }
    if (!$sdk -or !(Test-Path -LiteralPath (Join-Path $sdk 'platforms/android-35/android.jar'))) { Stop-Runner 'Android SDK platform 35 missing. Set ANDROID_HOME to an SDK containing platforms/android-35.' }
    if (!$env:JAVA_HOME -or !(Test-Path -LiteralPath (Join-Path $env:JAVA_HOME 'bin/java.exe'))) { Stop-Runner 'JAVA_HOME must point to JDK 17, not a JRE.' }
    $version = Invoke-RunnerProcess $java @('-version') -Quiet -TimeoutSeconds 15
    if ($version.ExitCode -ne 0 -or !($version.Lines -match 'version "17\.')) { Stop-Runner 'This Android demo uses JDK 17; select it through JAVA_HOME and PATH.' }
    $appium = Join-Path $script:Repo 'tests/mobile-e2e/node_modules/appium/index.js'
    $driver = Join-Path $script:Repo '.appium/node_modules/appium-uiautomator2-driver'
    if (!(Test-Path -LiteralPath $appium)) { Stop-Runner 'Appium package missing. Confirm and run: npm ci --prefix tests/mobile-e2e.' }
    if (!(Test-Path -LiteralPath (Join-Path $driver 'package.json')) -or (Read-Json (Join-Path $driver 'package.json')).version -cne '4.2.9') {
        Stop-Runner "UiAutomator2 4.2.9 missing in the repository .appium. Set APPIUM_HOME to '$script:Repo/.appium', then confirm driver installation: node tests/mobile-e2e/node_modules/appium/index.js driver install uiautomator2@4.2.9"
    }
    Assert-FreePort 5080
    Assert-FreePort 4723
    $devices = Invoke-RunnerProcess $adb @('devices') -Quiet -TimeoutSeconds 15
    $connected = @($devices.Lines | Where-Object { $_ -match '^emulator-\d+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] })
    $serial = $env:ANDROID_SERIAL
    if ($serial -and $serial -notmatch '^emulator-\d+$') { Stop-Runner 'This runner prepares the documented emulator demo only; select an emulator serial in ANDROID_SERIAL.' }
    if ($serial -and $serial -notin $connected) { Stop-Runner "Selected device $serial is not connected and ready. Check adb devices or unset ANDROID_SERIAL for AVD startup." }
    if (!$serial -and $connected.Count -eq 1) { $serial = $connected[0] }
    if (!$serial -and $connected.Count -gt 1) { Stop-Runner 'Multiple emulators connected. Set ANDROID_SERIAL to the intended emulator.' }
    $owned = $null
    $ownedOutput = $null; $ownedError = $null
    $previousIme = $null
    try {
        if ($serial -and $script:ShowUi -and $IsWindows) {
            $port = $serial -replace '^emulator-', ''
            $hidden = @(Get-CimInstance Win32_Process -Filter "Name = 'qemu-system-x86_64.exe'" -ErrorAction SilentlyContinue | Where-Object {
                $_.CommandLine -match '-no-window' -and
                ($_.CommandLine -match "-port\s+$port\b" -or ($port -eq '5554' -and $_.CommandLine -notmatch '-port\s+\d+'))
            })
            if ($hidden.Count) { Stop-Runner "Emulator $serial is already running with -no-window. Stop that emulator and restart it visibly in Android Studio, or unset ANDROID_SERIAL and let this runner start a visible AVD." }
        }
        if (!$serial) {
            $emulator = Join-Path $sdk 'emulator/emulator.exe'
            if (!(Test-Path -LiteralPath $emulator)) { Stop-Runner 'Android Emulator missing; install it with Android SDK Manager.' }
            $avds = Invoke-RunnerProcess $emulator @('-list-avds') -Quiet -TimeoutSeconds 20
            $names = @($avds.Lines | Where-Object { $_ -match '^[a-zA-Z0-9_.-]+$' })
            $avd = $env:SWT301_AVD
            if (!$avd -and $names.Count -eq 1) { $avd = $names[0] }
            if (!$avd -or $avd -notin $names) { Stop-Runner 'No unique selected AVD. Create an API 35 Google APIs x86_64 AVD and set SWT301_AVD to its name.' }
            Assert-FreePort 5554
            Assert-FreePort 5555
            $acceleration = Invoke-RunnerProcess $emulator @('-accel-check') -Quiet -TimeoutSeconds 20
            if ($acceleration.ExitCode -ne 0) { Stop-Runner ('Android VM acceleration unavailable: ' + ($acceleration.Lines -join ' ')) }
            Write-Host "Starting existing AVD $avd; only this owned emulator will be stopped afterward."
            $info = [Diagnostics.ProcessStartInfo]::new()
            $info.FileName=$emulator; $info.UseShellExecute=$false; $info.CreateNoWindow=$true
            $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
            $emulatorArguments = @('-avd',$avd,'-noaudio','-no-boot-anim','-no-snapshot','-gpu','swiftshader','-memory','2048','-cores','2','-port','5554')
            if (!$script:ShowUi) { $emulatorArguments += '-no-window' }
            foreach ($arg in $emulatorArguments) { $info.ArgumentList.Add($arg) }
            $owned = [Diagnostics.Process]::Start($info)
            if (!$owned) { Stop-Runner 'Android emulator could not start.' }
            $ownedOutput=$owned.StandardOutput.ReadToEndAsync(); $ownedError=$owned.StandardError.ReadToEndAsync()
            $serial='emulator-5554'
        }
        $ready=$false; $deadline=[DateTime]::UtcNow.AddMinutes(4)
        while ([DateTime]::UtcNow -lt $deadline) {
            if ($owned -and $owned.HasExited) { Stop-Runner 'Owned emulator exited during startup; inspect emulator logs.' }
            $boot=Invoke-RunnerProcess $adb @('-s',$serial,'shell','getprop','sys.boot_completed') -Quiet -TimeoutSeconds 10
            if ($boot.ExitCode -eq 0 -and '1' -in $boot.Lines) { $ready=$true; break }
            Start-Sleep -Seconds 2
        }
        if (!$ready) { Stop-Runner 'Android emulator did not finish booting within four minutes.' }
        if ($script:ShowUi) { Write-Host "Watch Android emulator $serial. If it was already started headless, restart that emulator without -no-window before this demo." }
        $api=Invoke-RunnerProcess $adb @('-s',$serial,'shell','getprop','ro.build.version.sdk') -Quiet
        if ('35' -notin $api.Lines) { Stop-Runner 'Select the documented Android API 35 emulator for this demo.' }
        Ensure-DotnetBuild $Result
        Write-Host 'Preparing APK using the existing Gradle wrapper (incremental build)...'
        $build=Invoke-RunnerProcess $env:ComSpec @('/d','/c','apps\mobile\gradlew.bat -p apps/mobile --no-daemon assembleDebug') $Result.log @{ANDROID_HOME=$sdk}
        if ($build.ExitCode -ne 0) { Stop-Runner 'APK build failed; native tests were not executed. Inspect execution.log.' 'NOT EXECUTED' }
        $apk=Join-Path $script:Repo 'apps/mobile/app/build/outputs/apk/debug/app-debug.apk'
        if (!(Test-Path -LiteralPath $apk)) { Stop-Runner "APK not found after build: $apk" }
        $settings=Join-Path $driver 'node_modules/io.appium.settings/apks/settings_apk-debug.apk'
        if (!(Test-Path -LiteralPath $settings)) { Stop-Runner 'Appium Settings helper APK missing from the installed UiAutomator2 package.' }
        $ime=Invoke-RunnerProcess $adb @('-s',$serial,'shell','settings','get','secure','default_input_method') -Quiet
        if ($ime.ExitCode -eq 0) { $previousIme=($ime.Lines -join '').Trim() }
        foreach ($adbArguments in @(
            @('-s',$serial,'install','-r',$settings),
            @('-s',$serial,'shell','ime','enable','io.appium.settings/.AppiumIME'),
            @('-s',$serial,'shell','ime','set','io.appium.settings/.AppiumIME'),
            @('-s',$serial,'shell','input','keyevent','82')
        )) {
            $preparation=Invoke-RunnerProcess $adb $adbArguments $Result.log -TimeoutSeconds 120
            if ($preparation.ExitCode -ne 0) { Stop-Runner 'Appium emulator preparation failed; inspect execution.log.' }
        }
        if ($owned) {
            foreach ($setting in @('window_animation_scale','transition_animation_scale','animator_duration_scale')) {
                $null=Invoke-RunnerProcess $adb @('-s',$serial,'shell','settings','put','global',$setting,'0') -Quiet
            }
        }
        $evidence=Join-Path $Result.directory 'evidence'
        $delay = if ($script:ShowUi) { [string]$script:SlowMo } else { '0' }
        $run=Invoke-RunnerProcess 'python' @('-u',(Join-Path $script:Repo 'ci/run-mobile.py')) $Result.log @{MOBILE_RESULTS=$evidence;ANDROID_SERIAL=$serial;ANDROID_HOME=$sdk;SWT_DEMO_DELAY_MS=$delay;PYTHONUNBUFFERED='1'}
        $Result.exitCode=$run.ExitCode
        $path=Join-Path $evidence 'results.json'
        if (!(Test-Path -LiteralPath $path)) { Stop-Runner 'Mobile runner produced no fresh case results. Inspect execution.log.' }
        $cases=Read-Json $path
        $Result.total=$cases.discovered; $Result.passed=$cases.passed
        $Result.failed=$cases.failed; $Result.errors=$cases.errors; $Result.skipped=$cases.skipped
        $Result.status=if ($run.ExitCode -eq 0 -and $cases.status -ceq 'Passed' -and $cases.executed -gt 0) {'PASSED'}
            elseif ($cases.executed -eq 0) {'ENVIRONMENT BLOCKED'} elseif ($Result.failed -gt 0 -or $Result.errors -gt 0) {'FAILED'}
            elseif ($cases.skipped -gt 0) {'SKIPPED'} else {'NOT EXECUTED'}
        $Result.message="Device: $serial. Native errors: $($cases.errors)."
        if (@($cases.failures).Count) { $Result.message += "`n$($cases.failures[0].trace)" }
        $Result.reports += @($path,(Join-Path $evidence 'run.json'))
    }
    finally {
        if (!$owned -and $previousIme -and $previousIme -ne 'null') {
            $null=Invoke-RunnerProcess $adb @('-s',$serial,'shell','ime','set',$previousIme) $Result.log -TimeoutSeconds 15 -Quiet
        }
        if ($owned) {
            if (!$owned.HasExited) { $owned.Kill($true); $null=$owned.WaitForExit(10000) }
            if ($ownedOutput) { $ownedOutput.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $Result.directory 'emulator-stdout.log') }
            if ($ownedError) { $ownedError.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $Result.directory 'emulator-stderr.log') }
            $owned.Dispose()
        }
    }
}

function Start-RunnerDashboard {
    if ($script:Dashboard -and !$script:Dashboard.Process.HasExited) {
        Write-Host "Live dashboard: $($script:Dashboard.Url)"
        Start-Process $script:Dashboard.Url | Out-Null
        return
    }
    if ($script:Dashboard) { Stop-RunnerDashboard }
    New-Item -ItemType Directory -Path $script:ResultsRoot -Force | Out-Null
    $log = Join-Path $script:ResultsRoot 'dashboard.log'
    Ensure-DotnetBuild @{log=$log}
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = Require-Tool 'dotnet' 'Install .NET 10 SDK.'
    $info.WorkingDirectory = Join-Path $script:Repo 'apps/web'
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    foreach ($argument in @((Join-Path $script:Repo 'apps/web/bin/Release/net10.0/SWT.dll'), '--urls', 'http://127.0.0.1:0')) {
        $info.ArgumentList.Add($argument)
    }
    foreach ($variable in @('ASPNETCORE_URLS','ASPNETCORE_HTTP_PORTS','ASPNETCORE_HTTPS_PORTS','DOTNET_URLS')) {
        $info.Environment.Remove($variable) | Out-Null
    }
    $info.Environment['ASPNETCORE_ENVIRONMENT'] = 'Development'
    $process = [Diagnostics.Process]::Start($info)
    $errorOutput = $process.StandardError.ReadToEndAsync()
    $pending = $process.StandardOutput.ReadLineAsync()
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    $url = $null
    try {
        while ([DateTime]::UtcNow -lt $deadline -and !$url) {
            if ($pending.IsCompleted) {
                $line = $pending.GetAwaiter().GetResult()
                if ($null -eq $line) { throw 'Dashboard server closed its output before startup.' }
                Add-Content -LiteralPath $log -Value $line -Encoding utf8
                if ($line -match 'Now listening on: (http://127\.0\.0\.1:\d+)') { $url = $Matches[1] + '/TestDashboard' }
                else { $pending = $process.StandardOutput.ReadLineAsync() }
            }
            elseif ($process.HasExited) { throw "Dashboard server exited $($process.ExitCode). See $log" }
            Start-Sleep -Milliseconds 40
        }
        if (!$url) { throw 'Dashboard server did not start within 45 seconds.' }
        $script:Dashboard = @{Process=$process;Url=$url;Output=$process.StandardOutput.ReadToEndAsync();Errors=$errorOutput;Log=$log}
        Write-Host "Live dashboard: $url"
        Start-Process $url | Out-Null
    }
    catch {
        if (!$script:Dashboard) {
            if (!$process.HasExited) { $process.Kill($true); $null = $process.WaitForExit(10000) }
            $process.Dispose()
        }
        throw
    }
}

function Stop-RunnerDashboard {
    if (!$script:Dashboard) { return }
    $server = $script:Dashboard
    try {
        if (!$server.Process.HasExited) { $server.Process.Kill($true); $null = $server.Process.WaitForExit(10000) }
        foreach ($task in @($server.Output,$server.Errors)) {
            $task.GetAwaiter().GetResult() | Add-Content -LiteralPath $server.Log -Encoding utf8
        }
    }
    finally { $server.Process.Dispose(); $script:Dashboard = $null }
}

function Save-RunSnapshot {
    param($Result)
    $path = Join-Path $Result.directory 'result.json'
    $temporary = $path + '.tmp'
    $Result | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $temporary -Encoding utf8
    Move-Item -LiteralPath $temporary -Destination $path -Force
}

function Save-RunResult {
    param($Result)
    $Result.finishedAtUtc=[DateTimeOffset]::UtcNow.ToString('o')
    Save-RunSnapshot $Result
    $script:History.Add($Result)
    $session=[ordered]@{sessionId=$script:SessionId;repository=$script:Repo;runs=@($script:History.ToArray())}
    $session | ConvertTo-Json -Depth 22 | Set-Content -LiteralPath (Join-Path $script:ResultsRoot 'session.json') -Encoding utf8
}

function Show-RunResult {
    param($Result)
    Write-Host "`nTest Execution Completed!"
    Write-Host "Suite       : $($Result.name)"
    if ($null -ne $Result.total) {
        Write-Host "Total Tests : $($Result.total)"
        Write-Host "Passed      : $($Result.passed)"
        Write-Host "Failed      : $($Result.failed)"
        Write-Host "Skipped     : $($Result.skipped)"
        if ($null -ne $Result.errors) { Write-Host "Errors      : $($Result.errors)" }
    }
    else { Write-Host 'Test counts : n/a - see status and any request/metric counters below' }
    Write-Host "Status      : $($Result.status)" -ForegroundColor $(if ($Result.status -eq 'PASSED') {'Green'} else {'Yellow'})
    if ($Result.message) { Write-Host $Result.message }
    if ($Result.name -eq 'newman' -and $Result.metrics) {
        Write-Host "Requests    : $($Result.metrics.requests.total) (failed: $($Result.metrics.requests.failed))"
        Write-Host "Assertions  : $($Result.metrics.assertions.total) (failed: $($Result.metrics.assertions.failed))"
    }
    elseif ($Result.metrics) {
        Write-Host "HTTP requests   : $($Result.metrics.httpRequests.count)"
        Write-Host "HTTP error rate : $($Result.metrics.httpErrors.rate)"
        Write-Host "Workflow errors : $($Result.metrics.workflowErrors.rate)"
        Write-Host "Check p95 / p99 : $($Result.metrics.checkLatencyMs.'p(95)') / $($Result.metrics.checkLatencyMs.'p(99)') ms"
        $thresholds = foreach ($metric in $Result.metrics.thresholdResults.PSObject.Properties) {
            foreach ($threshold in $metric.Value.PSObject.Properties) {
                [pscustomobject]@{Metric=$metric.Name;Threshold=$threshold.Name;Passed=$threshold.Value.ok}
            }
        }
        if (@($thresholds).Count) { $thresholds | Format-Table -AutoSize | Out-Host }
        else { Write-Host 'Thresholds      : none (characterization)' }
    }
    Write-Host "Reports/log : $($Result.directory)"
}

function Invoke-LocalSuite {
    param([string]$Name, [switch]$Unattended)
    $directory=Join-Path $script:ResultsRoot ($Name+'-'+[Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $result=[ordered]@{
        name=$Name;status='NOT EXECUTED';startedAtUtc=[DateTimeOffset]::UtcNow.ToString('o');finishedAtUtc=$null
        runnerPid=$PID;showUi=$script:ShowUi
        total=$null;passed=$null;failed=$null;skipped=$null;errors=$null;exitCode=$null;message='';metrics=$null
        directory=$directory;log=(Join-Path $directory 'execution.log');reports=@()
    }
    Write-Host "`n==================================================`n$($Name.ToUpperInvariant())`n=================================================="
    Write-Host 'Checking dependencies and prerequisites...'
    $result.status = 'RUNNING'
    Save-RunSnapshot $result
    try {
        if ($Name -in @($script:Definitions.id)) { Invoke-DotnetSuite $result }
        elseif ($Name -eq 'newman') { Invoke-NewmanSuite $result }
        elseif ($Name -like 'performance-*') { Invoke-PerformanceSuite $result }
        elseif ($Name -eq 'mobile') { Invoke-MobileSuite $result -Unattended:$Unattended }
        else { throw "Unsupported suite: $Name" }
    }
    catch {
        $result.status=if ($_.Exception.Data['RunnerStatus']) { $_.Exception.Data['RunnerStatus'] } else { 'FAILED' }
        $result.message=$_.Exception.Message
        $result.message | Add-Content -LiteralPath $result.log -Encoding utf8
    }
    finally { Save-RunResult $result }
    Show-RunResult $result
    return [pscustomobject]$result
}

function Invoke-AllLocalTests {
    param([switch]$Unattended)
    $results=foreach ($suite in @('unit','api','newman','http-integration','web-e2e','visual','ai-assisted',
        'performance-characterization','performance-load','performance-stress','mobile')) {
        Invoke-LocalSuite $suite -Unattended:$Unattended
    }
    Write-Host "`nALL LOCAL RESULTS (Newman assertions and k6 samples are not test-case totals)"
    $results | Select-Object name,status,total,passed,failed,skipped | Format-Table -AutoSize | Out-Host
    Write-Host "Session report: $(Join-Path $script:ResultsRoot 'session.json')"
    return @($results | Where-Object status -ne 'PASSED').Count -eq 0
}

function Show-RunnerResults {
    param([switch]$Interactive)
    $root=Join-Path $script:Repo 'TestResults/interactive'
    $sessions=@(Get-ChildItem -LiteralPath $root -Filter session.json -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 5)
    if (!$sessions.Count) { Write-Host 'NOT EXECUTED - no interactive-runner reports yet. Existing suite reports may be under TestResults/ci.' }
    foreach ($file in $sessions) {
        Write-Host "`nSession: $($file.FullName)"
        (Read-Json $file.FullName).runs | Select-Object name,status,total,passed,failed,skipped,directory | Format-Table -AutoSize | Out-Host
    }
    if ($Interactive -and (Read-RunnerInput 'Open TestResults in Explorer? [y/N]') -match '^(y|yes)$') {
        $folder=Join-Path $script:Repo 'TestResults'
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Start-Process explorer.exe -ArgumentList ('"'+$folder+'"') | Out-Null
    }
}

function Show-CiMenu {
    param([switch]$Unattended)
    $repository='TruongGiangNgtr/SWT301'
    $url="https://github.com/$repository/actions"
    Write-Host "CI/CD runs on GitHub, not as a local test suite.`n$url"
    Write-Host 'GitHub: Actions -> select workflow -> Run workflow -> select a remote ref.'
    if ($Unattended) { Write-Host 'NOT EXECUTED - no remote workflow dispatched.'; return }
    Write-Host '[1] Open Actions page   [2] Dispatch with authenticated GitHub CLI   [0] Back'
    $choice=Read-RunnerInput 'CI/CD action'
    if ($choice -eq '1') { Start-Process $url | Out-Null; return }
    if ($choice -ne '2') { Write-Host 'NOT EXECUTED - no workflow dispatched.'; return }
    $gh=Get-Command gh -CommandType Application -ErrorAction SilentlyContinue
    if (!$gh) { Write-Host "ENVIRONMENT BLOCKED - GitHub CLI not found. Open $url and use Run workflow."; return }
    $auth=Invoke-RunnerProcess $gh.Source @('auth','status','--hostname','github.com') -Quiet -TimeoutSeconds 20
    if ($auth.ExitCode -ne 0) { Write-Host "ENVIRONMENT BLOCKED - gh is not authenticated. Run gh auth login yourself, or open $url."; return }
    $workflows=@(Get-ChildItem -LiteralPath (Join-Path $script:Repo '.github/workflows') -File | Where-Object Extension -in @('.yml','.yaml') | Sort-Object Name)
    for ($index=0;$index -lt $workflows.Count;$index++) { Write-Host "[$($index+1)] $($workflows[$index].Name)" }
    $number=0
    if (![int]::TryParse((Read-RunnerInput 'Workflow number (0 cancels)'),[ref]$number) -or $number -lt 1 -or $number -gt $workflows.Count) { return }
    $workflow=$workflows[$number-1].Name
    $ref=Read-RunnerInput 'Remote branch/tag [main] (local changes are not pushed)'
    if ([string]::IsNullOrWhiteSpace($ref)) { $ref='main' }
    if ((Read-RunnerInput "Type YES to dispatch $workflow on $repository@$ref (uses GitHub runner resources)") -cne 'YES') {
        Write-Host 'SKIPPED - dispatch cancelled. No request sent.'; return
    }
    New-Item -ItemType Directory -Path $script:ResultsRoot -Force | Out-Null
    $dispatch=Invoke-RunnerProcess $gh.Source @('workflow','run',$workflow,'--repo',$repository,'--ref',$ref) (Join-Path $script:ResultsRoot 'github-dispatch.log') -TimeoutSeconds 60
    if ($dispatch.ExitCode -ne 0) { Write-Host 'FAILED - dispatch request was not accepted.'; return }
    Write-Host "Dispatch requested. This is NOT a passed test result. Check status/logs at $url. No code was pushed."
}

Export-ModuleMember -Function Initialize-TestRunner,Read-RunnerInput,Invoke-LocalSuite,Invoke-AllLocalTests,Show-RunnerResults,Show-CiMenu,Start-RunnerDashboard,Stop-RunnerDashboard
