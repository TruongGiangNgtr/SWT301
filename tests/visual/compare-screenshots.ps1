[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Baseline,
    [Parameter(Mandatory)][string]$Actual,
    [Parameter(Mandatory)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'Use Windows PowerShell (powershell.exe), which supplies System.Drawing; no new NuGet dependency is required.'
}
$baselinePath = (Resolve-Path -LiteralPath $Baseline).Path
$actualPath = (Resolve-Path -LiteralPath $Actual).Path
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$outputPath = (Resolve-Path -LiteralPath $OutputDirectory).Path
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
public static class ScreenshotDifference {
    public static long Compare(string expectedFile, string actualFile, string diffFile) {
        using (var expected = new Bitmap(expectedFile))
        using (var actual = new Bitmap(actualFile)) {
            int width = Math.Max(expected.Width, actual.Width);
            int height = Math.Max(expected.Height, actual.Height);
            using (var diff = new Bitmap(width, height, PixelFormat.Format32bppArgb)) {
                long changed = 0;
                for (int y = 0; y < height; y++) {
                    for (int x = 0; x < width; x++) {
                        bool exists = x < expected.Width && y < expected.Height && x < actual.Width && y < actual.Height;
                        var a = x < actual.Width && y < actual.Height ? actual.GetPixel(x, y) : Color.Transparent;
                        var e = x < expected.Width && y < expected.Height ? expected.GetPixel(x, y) : Color.Transparent;
                        if (!exists || a.ToArgb() != e.ToArgb()) {
                            changed++;
                            diff.SetPixel(x, y, Color.Magenta);
                        } else {
                            int gray = (a.R + a.G + a.B) / 3;
                            diff.SetPixel(x, y, Color.FromArgb(255, 200 + gray / 5, 200 + gray / 5, 200 + gray / 5));
                        }
                    }
                }
                diff.Save(diffFile, ImageFormat.Png);
                return changed;
            }
        }
    }
}
'@
$diffPath = Join-Path $outputPath 'diff.png'
$changedPixels = [ScreenshotDifference]::Compare($baselinePath, $actualPath, $diffPath)
$comparison = [ordered]@{
    changedPixels = $changedPixels
    exactMatch = $changedPixels -eq 0
    baseline = $baselinePath
    actual = $actualPath
    diff = $diffPath
    policy = 'Exact pixel comparison; this utility does not approve or update baselines.'
}
$comparison | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputPath 'comparison.json') -Encoding UTF8
$comparison | ConvertTo-Json | Write-Output
if ($changedPixels -gt 0) { exit 1 }
