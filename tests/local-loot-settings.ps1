$ErrorActionPreference='Stop'
$assembly=[Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\LootBot.exe')).Path)
$type=$assembly.GetType('LocalLootTesting')
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('LootBot-AllLoot-'+[Guid]::NewGuid())
$addon=Join-Path $testRoot 'game\Interface\AddOns\LootBot'
try {
    New-Item -ItemType Directory -Path $addon -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $addon 'LootBot.toc') -Value 'LocalTestSettings.lua'
    if($type::Enabled($testRoot)){throw 'Fresh install should be off'}
    $type::Apply($testRoot,$addon,$true)
    if(-not $type::Enabled($testRoot)){throw 'Enabled switch did not persist'}
    $config=Get-Content -LiteralPath (Join-Path $addon 'LocalTestSettings.lua') -Raw
    if($config -notmatch 'allLoot = true'){throw 'Addon configuration not enabled'}
    $type::Apply($testRoot,$addon,$false)
    if($type::Enabled($testRoot)){throw 'Disabled switch did not persist'}
    $rejected=$false
    try {$type::Apply($testRoot,(Join-Path $testRoot 'wrong-folder'),$true)} catch {$rejected=$true}
    if(-not $rejected){throw 'Unrelated folder was accepted'}
    if(Test-Path -LiteralPath (Join-Path $testRoot 'wrong-folder\LocalTestSettings.lua')){throw 'Wrote outside addon'}
} finally {
    $resolved=[IO.Path]::GetFullPath($testRoot)
    $temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if(-not $resolved.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected cleanup path'}
    if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
