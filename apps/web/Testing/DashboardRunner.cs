using System.Diagnostics;
using System.Text.Json;
using System.Threading.Channels;

namespace SWT.Testing;

// Local developer tooling. All execution goes through the existing guarded test runner.
public sealed class DashboardRunner(IWebHostEnvironment host, IConfiguration configuration) : BackgroundService
{
    private readonly object gate = new();
    private readonly Channel<Job> queue = Channel.CreateUnbounded<Job>();
    private readonly List<Job> jobs = [];
    private static readonly HashSet<string> Suites = new(StringComparer.Ordinal)
    {
        "unit", "api", "newman", "web-e2e", "mobile", "performance-characterization",
        "performance-load", "performance-stress", "visual", "ai-assisted", "http-integration", "all"
    };
    public bool Enabled => configuration["SWT301_DASHBOARD"] == "1";
    public string Repository { get; } = FindRoot(host.ContentRootPath);

    private static string FindRoot(string start)
    {
        for (var directory = new DirectoryInfo(start); directory is not null; directory = directory.Parent)
            if (File.Exists(Path.Combine(directory.FullName, "ci", "test-menu.ps1"))) return directory.FullName;
        return start;
    }

    public (string? Id, string? Error) Start(string suite, bool showWindows)
    {
        if (!Enabled) return (null, "Open run-dashboard.cmd to enable the local test runner.");
        if (!Suites.Contains(suite)) return (null, "Unknown test suite.");
        lock (gate)
        {
            if (jobs.Any(job => job.Status is "QUEUED" or "RUNNING"))
                return (null, "Another run is active. Wait for it to finish.");
            var job = new Job { Id = "dashboard-" + Guid.NewGuid().ToString("N"), Suite = suite, ShowWindows = showWindows };
            jobs.Insert(0, job);
            if (jobs.Count > 12) jobs.RemoveAt(jobs.Count - 1);
            queue.Writer.TryWrite(job);
            return (job.Id, null);
        }
    }

    public object Snapshot()
    {
        lock (gate)
        {
            return new
            {
                application = "SWT301 Test Dashboard",
                runnerProtocol = 1,
                enabled = Enabled,
                active = jobs.Any(job => job.Status is "QUEUED" or "RUNNING"),
                jobs = jobs.Select(job => new { job.Id, job.Suite, job.Status, job.ShowWindows,
                    job.StartedAt, job.FinishedAt, job.ExitCode, job.Error,
                    log = string.Join('\n', job.Lines), logStart = job.LogCount - job.Lines.Count, logCount = job.LogCount,
                    results = ReadSession(job.Id), progress = ReadSession(job.Id, "progress.json") }).ToArray(),
                history = ReadHistory()
            };
        }
    }

    private JsonElement? ReadSession(string id, string filename = "session.json")
    {
        try
        {
            using var document = JsonDocument.Parse(File.ReadAllText(Path.Combine(Repository, "TestResults", "interactive", id, filename)));
            return document.RootElement.Clone();
        }
        catch (Exception error) when (error is IOException or JsonException or UnauthorizedAccessException) { return null; }
    }

    private object[] ReadHistory()
    {
        var directory = Path.Combine(Repository, "TestResults", "interactive");
        if (!Directory.Exists(directory)) return [];
        return new DirectoryInfo(directory).EnumerateDirectories().OrderByDescending(item => item.LastWriteTimeUtc)
            .Take(24).Select(item => ReadSession(item.Name)).Where(item => item.HasValue)
            .Select(item => (object)item!.Value).ToArray();
    }

    public string? Artifact(string relative)
    {
        if (Path.IsPathRooted(relative)) return null;
        var root = Path.GetFullPath(Path.Combine(Repository, "TestResults")) + Path.DirectorySeparatorChar;
        var file = Path.GetFullPath(Path.Combine(root, relative));
        if (!file.StartsWith(root, StringComparison.OrdinalIgnoreCase) || !File.Exists(file) ||
            !new[] { ".json", ".png", ".trx", ".log", ".txt" }.Contains(Path.GetExtension(file).ToLowerInvariant())) return null;
        for (FileSystemInfo? item = new FileInfo(file); item is not null && item.FullName.Length >= root.Length - 1;
             item = item is FileInfo info ? info.Directory : ((DirectoryInfo)item).Parent)
            if ((item.Attributes & FileAttributes.ReparsePoint) != 0) return null;
        return file;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await foreach (var job in queue.Reader.ReadAllAsync(stoppingToken))
        {
            using var process = new Process();
            try
            {
                lock (gate) { job.Status = "RUNNING"; job.StartedAt = DateTimeOffset.UtcNow; }
                var shell = configuration["SWT301_PWSH"] ?? "pwsh";
                process.StartInfo = new ProcessStartInfo(shell)
                {
                    WorkingDirectory = Repository, UseShellExecute = false, CreateNoWindow = true,
                    RedirectStandardOutput = true, RedirectStandardError = true
                };
                foreach (var arg in new[] { "-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File",
                    Path.Combine(Repository, "ci", "test-menu.ps1"), "-Run", job.Suite, "-SessionId", job.Id })
                    process.StartInfo.ArgumentList.Add(arg);
                process.StartInfo.Environment["SWT301_SHOW_WINDOWS"] = job.ShowWindows ? "1" : "0";
                // Test servers must never inherit execution privileges from this host.
                process.StartInfo.Environment.Remove("SWT301_DASHBOARD");
                if (!process.Start()) throw new InvalidOperationException("PowerShell could not start.");
                var stdout = ReadLines(process.StandardOutput, job, stoppingToken);
                var stderr = ReadLines(process.StandardError, job, stoppingToken);
                using var timeout = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);
                timeout.CancelAfter(TimeSpan.FromMinutes(45));
                await process.WaitForExitAsync(timeout.Token);
                await Task.WhenAll(stdout, stderr);
                lock (gate)
                {
                    job.ExitCode = process.ExitCode;
                    var session = ReadSession(job.Id);
                    // An exit code alone never constitutes test evidence.
                    var rows = session?.GetProperty("runs");
                    var statuses = rows?.EnumerateArray().Select(row => row.GetProperty("status").GetString()).ToArray() ?? [];
                    job.Status = process.ExitCode == 0 && statuses.Length > 0 && statuses.All(status => status == "PASSED") ? "PASSED"
                        : statuses.Contains("FAILED") ? "FAILED"
                        : statuses.Contains("ENVIRONMENT BLOCKED") ? "ENVIRONMENT BLOCKED"
                        : "NOT EXECUTED";
                }
            }
            catch (Exception error)
            {
                lock (gate) { job.Status = "NOT EXECUTED"; job.Error = error is OperationCanceledException ? "Run stopped or timed out; inspect evidence." : error.Message; }
            }
            finally
            {
                try { if (process.Id > 0 && !process.HasExited) { process.Kill(entireProcessTree: true); await process.WaitForExitAsync(CancellationToken.None); } }
                catch (InvalidOperationException) { }
                lock (gate) { job.FinishedAt = DateTimeOffset.UtcNow; }
            }
        }
    }

    private async Task ReadLines(StreamReader reader, Job job, CancellationToken token)
    {
        while (await reader.ReadLineAsync(token) is { } line)
            lock (gate)
            {
                job.Lines.Enqueue(line);
                job.LogCount++;
                while (job.Lines.Count > 1800) job.Lines.Dequeue();
            }
    }

    private sealed class Job
    {
        public required string Id { get; init; }
        public required string Suite { get; init; }
        public bool ShowWindows { get; init; }
        public string Status { get; set; } = "QUEUED";
        public DateTimeOffset? StartedAt { get; set; }
        public DateTimeOffset? FinishedAt { get; set; }
        public int? ExitCode { get; set; }
        public string? Error { get; set; }
        public Queue<string> Lines { get; } = new();
        public long LogCount { get; set; }
    }
}
