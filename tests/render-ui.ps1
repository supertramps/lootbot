param([string]$OutputDirectory = (Join-Path $PSScriptRoot '..\..\..\outputs'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$assembly=[Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\LootBot.exe')).Path)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
function Save-Window($window,$name) {
    $bitmap=New-Object System.Drawing.Bitmap($window.Width,$window.Height)
    try {
        [System.Windows.Forms.Application]::DoEvents()
        $window.DrawToBitmap($bitmap,(New-Object System.Drawing.Rectangle(0,0,$window.Width,$window.Height)))
        $bitmap.Save((Join-Path $OutputDirectory $name),[System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $bitmap.Dispose()
    }
}
$main=[Activator]::CreateInstance($assembly.GetType('LootBotWindow'))
try {$main.Show();Save-Window $main 'LootBot-main.png'} finally {$main.Hide();$main.Dispose()}
$tools=[Activator]::CreateInstance($assembly.GetType('ToolsWindow'),@($true))
try {
    $tools.Show()
    $tabs=$tools.Controls | Where-Object { $_ -is [System.Windows.Forms.TabControl] } | Select-Object -First 1
    foreach ($entry in @(@{Index=0;Name='LootBot-tools-tests.png'},@{Index=1;Name='LootBot-tools-settings.png'},@{Index=2;Name='LootBot-tools-relays.png'})) {
        $tabs.SelectedIndex=$entry.Index
        Save-Window $tools $entry.Name
    }
} finally {$tools.Hide();$tools.Dispose()}
