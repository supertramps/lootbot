param(
    [ValidateSet('Preview','Live','Setup','ReadWebhook','InstallAddon','Test')]
    [string]$Mode = 'Preview',
    [string]$WoWPath,
    [int]$InterfaceVersion = 0,
    [switch]$AllLoot
)
$ErrorActionPreference = 'Stop'
$secretPath = Join-Path $PSScriptRoot 'webhook.dpapi'
switch ($Mode) {
    'Setup' {
        Write-Host 'Create a webhook in your Discord test channel: Edit Channel > Integrations > Webhooks.'
        Write-Host 'Paste its URL below. It will be encrypted for this Windows account.'
        $secret = Read-Host 'Discord webhook URL' -AsSecureString
        ConvertFrom-SecureString -SecureString $secret | Set-Content -LiteralPath $secretPath -Encoding ASCII
        Write-Host 'Saved. Nothing has been sent. Use -Mode Live when ready to post.'
        return
    }
    'ReadWebhook' {
        $encrypted = (Get-Content -LiteralPath $secretPath -Raw).Trim()
        $secret = ConvertTo-SecureString -String $encrypted
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
        try { [Console]::Write([Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
        return
    }
    'InstallAddon' {
        if (-not $WoWPath) { $WoWPath = Read-Host 'Full path to your Classic client folder (the folder containing WowClassic.exe)' }
        $clientRoot = (Resolve-Path -LiteralPath $WoWPath).Path
        if (-not ((Test-Path -LiteralPath (Join-Path $clientRoot 'WowClassic.exe')) -or
                  (Test-Path -LiteralPath (Join-Path $clientRoot 'WowClassicT.exe')))) {
            throw 'Choose the actual Classic client folder containing WowClassic.exe or WowClassicT.exe.'
        }
        $target = Join-Path $clientRoot 'Interface\AddOns\LootBot'
        if (Test-Path -LiteralPath $target) { throw 'LootBot already exists there. Review/back up that addon before replacing it.' }
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'addon\LootBot') -File | Copy-Item -Destination $target
        if ($InterfaceVersion -gt 0) {
            $toc = Join-Path $target 'LootBot.toc'
            $content = (Get-Content -LiteralPath $toc -Raw) -replace '## Interface: \d+', "## Interface: $InterfaceVersion"
            [IO.File]::WriteAllText($toc, $content, (New-Object Text.UTF8Encoding($false)))
        }
        Write-Host "Installed in $target"
        Write-Host 'Restart WoW if it was open. Enable LootBot and Load out of date AddOns at character selection.'
        Write-Host 'For an exact interface tag, use /dump select(4, GetBuildInfo()) in the client.'
        return
    }
}
$bundledNode = Join-Path $PSScriptRoot 'runtime\node.exe'
$nodeCommand = if (Test-Path -LiteralPath $bundledNode) { Get-Command $bundledNode } else { Get-Command node.exe -ErrorAction SilentlyContinue }
if (-not $nodeCommand) { throw 'Node.js is required. Install a supported Node.js LTS release, then reopen this terminal.' }
Push-Location $PSScriptRoot
try {
    if ($Mode -eq 'Test') {
        & $nodeCommand.Source 'tests\run.js'
    } else {
        $helperArgs = @('companion\main.js')
        if ($Mode -eq 'Live') { $helperArgs += '--send' }
        if ($AllLoot) { $helperArgs += '--all' }
        & $nodeCommand.Source @helperArgs
    }
    if ($LASTEXITCODE -ne 0) { throw "LootBot exited with code $LASTEXITCODE" }
} finally { Pop-Location }
