using System.Net;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.RazorPages;
using SWT.Testing;

namespace SWT.Pages;

public sealed class DashboardModel(DashboardRunner runner) : PageModel
{
    public override void OnPageHandlerExecuting(PageHandlerExecutingContext context)
    {
        var address = HttpContext.Connection.RemoteIpAddress;
        if (address is null || !IPAddress.IsLoopback(address) ||
            !(Request.Host.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase) ||
              IPAddress.TryParse(Request.Host.Host, out var host) && IPAddress.IsLoopback(host)))
            context.Result = new StatusCodeResult(403);
    }

    public IActionResult OnGetState() => new JsonResult(runner.Snapshot());

    public IActionResult OnPostRun(string suite, bool showWindows)
    {
        var (id, error) = runner.Start(suite ?? "", showWindows);
        return error is null ? new JsonResult(new { id }) : new JsonResult(new { error }) { StatusCode = 409 };
    }

    public IActionResult OnGetArtifact(string path)
    {
        try
        {
            var file = runner.Artifact(path ?? "");
            if (file is null) return NotFound();
            Response.Headers["X-Content-Type-Options"] = "nosniff";
            return PhysicalFile(file, Path.GetExtension(file) == ".png" ? "image/png" : "text/plain; charset=utf-8");
        }
        catch (Exception error) when (error is ArgumentException or IOException or UnauthorizedAccessException) { return NotFound(); }
    }
}
