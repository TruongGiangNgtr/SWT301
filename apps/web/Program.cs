using Microsoft.AspNetCore.DataProtection;

var builder = WebApplication.CreateBuilder(args);

builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo(
        Path.Combine(builder.Environment.ContentRootPath, ".data-protection-keys")));
builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.MapRazorPages();
app.MapPost("/api/dates/check", SWT.Api.DateApi.CheckAsync);

app.Run();
