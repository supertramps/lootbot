$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$sourcePath = Join-Path $PSScriptRoot 'newspaper-front-page-template.png'
$targetPath = Join-Path $PSScriptRoot '..\..\addon\LootBot\NewsletterPage.png'
$source = [System.Drawing.Image]::FromFile($sourcePath)
$bitmap = New-Object System.Drawing.Bitmap(2048, 2048, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
try {
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    # The paper keeps its 3:4 aspect ratio. Transparent side padding gives WoW
    # a power-of-two texture; the addon crops the padding with SetTexCoord.
    $graphics.DrawImage($source, (New-Object System.Drawing.Rectangle(256, 0, 1536, 2048)))
    $bitmap.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $graphics.Dispose()
    $bitmap.Dispose()
    $source.Dispose()
}
Write-Output $targetPath
