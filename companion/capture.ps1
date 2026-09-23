param(
    [int]$X = 16, [int]$Y = 16, [int]$Cell = 1,
    [int]$PollMs = 100, [int]$TargetPid = 0,
    [string]$TestPacket
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'Capture.cs') -ReferencedAssemblies System.Drawing
if ($TestPacket) {
    [LootBotCapture]::SelfTest($TestPacket)
} else {
    [LootBotCapture]::Run($X, $Y, $Cell, $PollMs, $TargetPid)
}
