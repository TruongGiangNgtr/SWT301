using System.Net;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using System.Xml;
using System.Xml.Linq;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace SWT.Pages;

public sealed class TestDashboardModel : PageModel
{
    private readonly string resultsRoot;

    public TestDashboardModel(IWebHostEnvironment environment)
    {
        var root = new DirectoryInfo(environment.ContentRootPath);
        while (root is not null && !System.IO.File.Exists(Path.Combine(root.FullName, "SWT.slnx"))) root = root.Parent;
        resultsRoot = Path.Combine(root?.FullName ?? environment.ContentRootPath, "TestResults", "interactive");
    }

    private bool IsLocal => HttpContext.Connection.RemoteIpAddress is { } address && IPAddress.IsLoopback(address);

    public IActionResult OnGet() => IsLocal ? Page() : NotFound();

    public IActionResult OnGetData()
    {
        if (!IsLocal) return NotFound();
        Response.Headers.CacheControl = "no-store";
        var runs = new List<JsonObject>();
        var unreadable = 0;
        if (Directory.Exists(resultsRoot))
        {
            foreach (var session in new DirectoryInfo(resultsRoot).GetDirectories().OrderByDescending(x => x.Name).Take(50))
            foreach (var run in session.GetDirectories())
            {
                if (!ValidIds(session.Name, run.Name)) continue;
                try
                {
                    var path = Path.Combine(run.FullName, "result.json");
                    if (!System.IO.File.Exists(path)) continue;
                    var record = JsonNode.Parse(ReadShared(path))!.AsObject();
                    record["session"] = session.Name;
                    record["run"] = run.Name;
                    record.Remove("directory"); record.Remove("log"); record.Remove("reports");
                    if ((string?)record["status"] == "RUNNING" && record["runnerPid"] is { } owner)
                    {
                        try
                        {
                            using var process = System.Diagnostics.Process.GetProcessById(owner.GetValue<int>());
                            if (process.HasExited || process.StartTime.ToUniversalTime() > DateTimeOffset.Parse(record["startedAtUtc"]!.GetValue<string>()).UtcDateTime)
                                MarkInterrupted(record);
                        }
                        catch (ArgumentException) { MarkInterrupted(record); }
                    }
                    runs.Add(record);
                }
                catch (Exception error) when (error is IOException or System.Text.Json.JsonException or InvalidOperationException)
                { unreadable++; }
            }
        }
        return new JsonResult(new { updatedAtUtc = DateTimeOffset.UtcNow, unreadable, runs });
    }

    public IActionResult OnGetDetail(string session, string run)
    {
        if (!IsLocal || RunDirectory(session, run) is not { } directory) return NotFound();
        Response.Headers.CacheControl = "no-store";
        var files = new DirectoryInfo(directory).EnumerateFiles("*", new EnumerationOptions
        { RecurseSubdirectories = true, AttributesToSkip = FileAttributes.ReparsePoint }).Where(x => AllowedFile(x.Extension)).Take(150).ToArray();
        var cases = new List<object>();
        foreach (var trx in files.Where(x => x.Extension.Equals(".trx", StringComparison.OrdinalIgnoreCase)))
        {
            try
            {
                using var reader = XmlReader.Create(new StringReader(ReadShared(trx.FullName)), new XmlReaderSettings
                { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null });
                var document = XDocument.Load(reader);
                cases.AddRange(document.Descendants().Where(x => x.Name.LocalName == "UnitTestResult").Select(x => new
                {
                    name = (string?)x.Attribute("testName"), outcome = (string?)x.Attribute("outcome"),
                    duration = (string?)x.Attribute("duration"),
                    message = x.Descendants().FirstOrDefault(n => n.Name.LocalName == "Message")?.Value
                }));
            }
            catch (Exception error) when (error is IOException or XmlException) { /* A running TRX may still be incomplete. */ }
        }
        var logPath = Path.Combine(directory, "execution.log");
        var log = System.IO.File.Exists(logPath) ? ReadTail(logPath) : "Waiting for execution log…";
        return new JsonResult(new
        {
            log, cases,
            files = files.Select(x => new { name = Path.GetRelativePath(directory, x.FullName).Replace('\\', '/'), size = x.Length })
        });
    }

    public IActionResult OnGetArtifact(string session, string run, string file)
    {
        if (!IsLocal || RunDirectory(session, run) is not { } directory || string.IsNullOrWhiteSpace(file)) return NotFound();
        // Reject traversal, rooted paths, alternate data streams and symlinks.
        var segments = file.Split(new[] { '/', '\\' }, StringSplitOptions.RemoveEmptyEntries);
        if (Path.IsPathRooted(file) || file.Contains(':') || segments.Any(x => x is "." or "..")) return NotFound();
        var path = directory;
        foreach (var segment in segments)
        {
            path = Path.Combine(path, segment);
            if (!Path.Exists(path) || (System.IO.File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0) return NotFound();
        }
        if (!System.IO.File.Exists(path) || !AllowedFile(Path.GetExtension(path))) return NotFound();
        Response.Headers.CacheControl = "no-store";
        Response.Headers["X-Content-Type-Options"] = "nosniff";
        var contentType = Path.GetExtension(path).ToLowerInvariant() switch
        { ".png" => "image/png", ".json" => "application/json", _ => "text/plain; charset=utf-8" };
        return File(new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete), contentType);
    }

    private string? RunDirectory(string session, string run)
    {
        if (!ValidIds(session, run)) return null;
        var sessionPath = Path.Combine(resultsRoot, session);
        var directory = Path.Combine(sessionPath, run);
        if (!Directory.Exists(directory) || new[] { resultsRoot, sessionPath, directory }.Any(x =>
                (System.IO.File.GetAttributes(x) & FileAttributes.ReparsePoint) != 0)) return null;
        return directory;
    }

    private static bool ValidIds(string? session, string? run) =>
        Regex.IsMatch(session ?? "", @"^\d{8}-\d{6}-[a-f0-9]{32}$", RegexOptions.CultureInvariant) &&
        Regex.IsMatch(run ?? "", @"^[a-z0-9-]+-[a-f0-9]{32}$", RegexOptions.CultureInvariant);

    private static bool AllowedFile(string extension) => extension.ToLowerInvariant() is ".png" or ".json" or ".trx" or ".txt" or ".log";

    private static void MarkInterrupted(JsonObject record)
    {
        record["status"] = "INTERRUPTED";
        record["message"] = "Runner đã dừng trước khi ghi kết quả hoàn thành. Không có kết luận pass/fail cho lần chạy này.";
    }

    private static string ReadShared(string path)
    {
        using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    }

    private static string ReadTail(string path)
    {
        using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        if (stream.Length > 48_000) stream.Seek(-48_000, SeekOrigin.End);
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    }
}
