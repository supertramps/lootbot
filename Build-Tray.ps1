$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:winexe /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Security.dll /reference:System.Web.Extensions.dll "/out:$PSScriptRoot\LootBot.exe" "$PSScriptRoot\companion\Tray.cs" "$PSScriptRoot\companion\ToolsWindow.cs" "$PSScriptRoot\companion\UiTheme.cs"
if ($LASTEXITCODE -ne 0) { throw 'Tray build failed.' }
