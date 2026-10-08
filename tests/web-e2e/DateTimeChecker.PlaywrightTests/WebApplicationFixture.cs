using System.Collections.Concurrent;
using System.Diagnostics;
using System.Reflection;
using System.Text.RegularExpressions;

namespace DateTimeChecker.PlaywrightTests;

/// <summary>Owns only the local server started for this E2E class.</summary>
internal sealed class WebApplicationFixture : IAsyncDisposable
{
    private readonly ConcurrentQueue<string> logs = new();
    private readonly TaskCompletionSource<string> listeningAddress =
        new(TaskCreationOptions.RunContinuationsAsynchronously);
    private Process? process;

    public string BaseUrl { get; private set; } = string.Empty;

    public async Task StartAsync()
    {
        var root = FindRepositoryRoot();
        var project = Path.Combine(root, "apps", "web", "SWT.csproj");
        var configuration = typeof(WebApplicationFixture).Assembly
            .GetCustomAttribute<AssemblyConfigurationAttribute>()?.Configuration
            ?? throw new InvalidOperationException("The test build configuration is missing.");

        var startInfo = new ProcessStartInfo
        {
            FileName = "dotnet",
            WorkingDirectory = Path.GetDirectoryName(project)!,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        foreach (var argument in new[]
        {
            "run", "--project", project, "--configuration", configuration,
            "--no-build", "--no-restore", "--no-launch-profile",
            "--", "--urls", "http://127.0.0.1:0"
        })
        {
            startInfo.ArgumentList.Add(argument);
        }

        startInfo.Environment["DOTNET_ENVIRONMENT"] = "Development";
        startInfo.Environment["ASPNETCORE_ENVIRONMENT"] = "Development";
        // Avoid inheriting unrelated local port bindings; Kestrel allocates the port.
        foreach (var variable in new[]
        {
            "ASPNETCORE_URLS", "ASPNETCORE_HTTP_PORTS", "ASPNETCORE_HTTPS_PORTS",
            "DOTNET_URLS", "DOTNET_HTTP_PORTS", "DOTNET_HTTPS_PORTS"
        })
        {
            startInfo.Environment.Remove(variable);
        }

        process = new Process { StartInfo = startInfo };
        process.OutputDataReceived += (_, args) => RecordLine(args.Data, standardError: false);
        process.ErrorDataReceived += (_, args) => RecordLine(args.Data, standardError: true);

        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(45));
        try
        {
            if (!process.Start())
            {
                throw new InvalidOperationException("The dotnet server process could not start.");
            }

            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            while (!listeningAddress.Task.IsCompleted)
            {
                ThrowIfExited();
                await Task.Delay(100, timeout.Token);
            }

            BaseUrl = await listeningAddress.Task;
            using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
            while (true)
            {
                ThrowIfExited();
                try
                {
                    using var response = await client.GetAsync(BaseUrl, timeout.Token);
                    if (response.IsSuccessStatusCode)
                    {
                        Console.WriteLine($"E2E server ready: {BaseUrl} ({configuration}, PID {process.Id})");
                        return;
                    }
                }
                catch (HttpRequestException)
                {
                    // The listener may be up before the first request can complete.
                }
                catch (OperationCanceledException) when (!timeout.IsCancellationRequested)
                {
                    // Retry a single HTTP request timeout within the startup budget.
                }

                await Task.Delay(100, timeout.Token);
            }
        }
        catch (Exception exception)
        {
            try
            {
                await DisposeAsync();
            }
            catch (Exception cleanupException)
            {
                throw new AggregateException("E2E startup and cleanup failed.",
                    exception, cleanupException);
            }

            throw new InvalidOperationException(
                $"E2E server failed to become ready within 45 seconds.\n{string.Join(Environment.NewLine, logs)}",
                exception);
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (process is null)
        {
            return;
        }

        var ownedProcess = process;
        process = null;
        try
        {
            // Id is unavailable if Process.Start failed; that instance owns no server.
            try { _ = ownedProcess.Id; }
            catch (InvalidOperationException) { return; }

            if (!ownedProcess.HasExited)
            {
                try { ownedProcess.Kill(entireProcessTree: true); }
                catch (InvalidOperationException) when (ownedProcess.HasExited) { }
            }

            using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
            await ownedProcess.WaitForExitAsync(timeout.Token);
            Console.WriteLine($"E2E server stopped: PID {ownedProcess.Id}");
        }
        finally
        {
            ownedProcess.Dispose();
        }
    }

    private void ThrowIfExited()
    {
        if (process!.HasExited)
        {
            throw new InvalidOperationException($"E2E server exited with code {process.ExitCode}.");
        }
    }

    private void RecordLine(string? line, bool standardError)
    {
        if (line is null) return;
        logs.Enqueue($"{(standardError ? "stderr" : "stdout")}: {line}");
        while (logs.Count > 200) logs.TryDequeue(out _);

        if (!standardError)
        {
            var match = Regex.Match(line, @"Now listening on:\s+(http://127\.0\.0\.1:\d+)");
            if (match.Success) listeningAddress.TrySetResult(match.Groups[1].Value);
        }
    }

    private static string FindRepositoryRoot()
    {
        for (var directory = new DirectoryInfo(AppContext.BaseDirectory);
             directory is not null; directory = directory.Parent)
        {
            if (File.Exists(Path.Combine(directory.FullName, "SWT.slnx")) &&
                File.Exists(Path.Combine(directory.FullName, "apps", "web", "SWT.csproj")))
            {
                return directory.FullName;
            }
        }

        throw new DirectoryNotFoundException(
            "Cannot locate SWT.slnx and apps/web/SWT.csproj above the test output directory.");
    }
}
