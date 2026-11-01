using System.Diagnostics;

namespace SWT.Testing;

internal static class WorkspaceLauncher
{
    public static bool TryStart(string[] args)
    {
        // Explicit server arguments are used by every existing test fixture and CI runner.
        if (args.Length != 0 || !OperatingSystem.IsWindows() || !Environment.UserInteractive ||
            Environment.GetEnvironmentVariable("CI") is "true" or "1" ||
            Environment.GetEnvironmentVariable("SWT301_DASHBOARD") == "1") return false;

        for (var directory = new DirectoryInfo(AppContext.BaseDirectory); directory is not null; directory = directory.Parent)
        {
            var launcher = Path.Combine(directory.FullName, "run-dashboard.cmd");
            if (!File.Exists(launcher) || !File.Exists(Path.Combine(directory.FullName, "SWT.slnx"))) continue;
            try
            {
                Process.Start(new ProcessStartInfo(launcher)
                {
                    WorkingDirectory = directory.FullName,
                    UseShellExecute = true
                })?.Dispose();
                Console.WriteLine("SWT301 console menu and web dashboard are opening in the workspace window.");
            }
            catch (Exception error) when (error is System.ComponentModel.Win32Exception or InvalidOperationException)
            {
                Console.Error.WriteLine($"Cannot open the workspace: {error.Message}\nRun {launcher} manually.");
                Environment.ExitCode = 1;
            }
            // Release this assembly before the workspace builds/tests the application on Windows.
            return true;
        }
        return false;
    }
}
