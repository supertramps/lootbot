$ErrorActionPreference = 'Stop'
$output = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\outputs'))
$stage = Join-Path $output ('package-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$relay = Join-Path $stage 'LootBot'
New-Item -ItemType Directory -Path $relay -Force | Out-Null
foreach ($name in @('LootBot.exe','Start-LootBot.ps1','cloud-config.json','GETTING-STARTED.md','README.md','Install-Addon.cmd','settings.example.json','companion','runtime','addon')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $relay -Recurse
}
Compress-Archive -LiteralPath $relay -DestinationPath (Join-Path $output 'LootBot-Relay-Windows.zip') -Force
Compress-Archive -LiteralPath (Join-Path $PSScriptRoot 'addon\LootBot') -DestinationPath (Join-Path $output 'LootBot-Addon.zip') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'GETTING-STARTED.md') -Destination (Join-Path $output 'LootBot-Guide.md')
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Join-Path $output 'LootBot-Relay-Windows.zip'))
try {
    $bad = $zip.Entries | Where-Object FullName -Match '(webhook\.dpapi|relay-identity|relay-registration|bootstrap\.sql|[\\/]state[\\/]|node_modules)'
    if ($bad) { throw 'Private files found in distribution.' }
    Write-Output ('Clean relay package: ' + $zip.Entries.Count + ' files')
} finally { $zip.Dispose() }
Get-ChildItem -LiteralPath $output -File | Select-Object Name,Length
