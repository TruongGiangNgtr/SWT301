using Microsoft.AspNetCore.DataProtection;

if (SWT.Testing.WorkspaceLauncher.TryStart(args)) return;
args = args.Where(argument => argument != "--web-only").ToArray();

var builder = WebApplication.CreateBuilder(args);

builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo(
        Path.Combine(builder.Environment.ContentRootPath, ".data-protection-keys")));
builder.Services.AddRazorPages();
builder.Services.AddSingleton<SWT.Testing.DashboardRunner>();
builder.Services.AddHostedService(provider => provider.GetRequiredService<SWT.Testing.DashboardRunner>());

var app = builder.Build();

app.UseStaticFiles();
app.MapRazorPages();
app.MapPost("/api/dates/check", SWT.Api.DateApi.CheckAsync);

app.Run();
