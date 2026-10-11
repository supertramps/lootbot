$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot '..\companion\Capture.cs') -ReferencedAssemblies System.Drawing
foreach($name in @('Wow','WowT','WowB','WowClassic','WowClassicT','WowClassicB','wowb')){
    if(-not [LootBotCapture]::IsSupportedProcessName($name)){throw "Supported game rejected: $name"}
}
foreach($name in @('WowVoiceProxyT','Battle.net','WowUpdater','OtherGame','', $null)){
    if([LootBotCapture]::IsSupportedProcessName($name)){throw "Non-game process accepted: $name"}
}
