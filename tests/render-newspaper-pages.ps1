param([string]$OutputDirectory=(Join-Path $PSScriptRoot '..\..\..\outputs\newspaper-pages'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$repo=Split-Path $PSScriptRoot -Parent
& (Join-Path $repo 'runtime\node.exe') (Join-Path $PSScriptRoot 'export-newspaper-pages.js') $OutputDirectory
if($LASTEXITCODE -ne 0){throw 'Edition export failed'}
$data=Get-Content -LiteralPath (Join-Path $OutputDirectory 'pages.json') -Raw | ConvertFrom-Json
$fonts=@{}
foreach($entry in @(@('regular','CrimsonText-Regular.ttf'),@('strong','CrimsonText-SemiBold.ttf'),@('masthead','UnifrakturMaguntia.ttf'))){
    $collection=New-Object System.Drawing.Text.PrivateFontCollection
    $collection.AddFontFile((Join-Path $repo ('addon/LootBot/Fonts/'+$entry[1])))
    $fonts[$entry[0]]=$collection
}
$overflow=@();$index=0
foreach($page in $data.pages){
    $index++
    $source=[System.Drawing.Image]::FromFile((Join-Path $repo ('addon/LootBot/'+$page.texture)))
    $bitmap=New-Object System.Drawing.Bitmap(1086,1448)
    $graphics=[System.Drawing.Graphics]::FromImage($bitmap)
    # Game PNGs have transparent side padding, cropped identically to SetTexCoord.
    $graphics.DrawImage($source,(New-Object System.Drawing.Rectangle(0,0,1086,1448)),(New-Object System.Drawing.Rectangle(256,0,1536,2048)),[System.Drawing.GraphicsUnit]::Pixel)
    $graphics.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $brush=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(42,31,22))
    foreach($slot in $data.layouts.($page.layout)){
        $face=if($slot.role -eq 'masthead'){'masthead'}elseif($slot.strong){'strong'}else{'regular'}
        $font=New-Object System.Drawing.Font($fonts[$face].Families[0],[single]$slot.size,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
        $format=New-Object System.Drawing.StringFormat
        if($slot.center){$format.Alignment=[System.Drawing.StringAlignment]::Center}
        $text=[string]$page.fields.($slot.key)
        $measured=$graphics.MeasureString($text,$font,[int]$slot.w,$format)
        if($measured.Height -gt $slot.h){$overflow+=('Page '+$index+' '+$slot.key+': '+[math]::Round($measured.Height)+' > '+$slot.h)}
        $rectangle=New-Object System.Drawing.RectangleF([single]$slot.x,[single]$slot.y,[single]$slot.w,[single]$slot.h)
        $graphics.DrawString($text,$font,$brush,$rectangle,$format)
        $font.Dispose();$format.Dispose()
    }
    $bitmap.Save((Join-Path $OutputDirectory ('page-'+$index+'-sample.png')),[System.Drawing.Imaging.ImageFormat]::Png)
    $brush.Dispose();$graphics.Dispose();$bitmap.Dispose();$source.Dispose()
}
foreach($font in $fonts.Values){$font.Dispose()}
if($overflow.Count){throw ($overflow -join "`n")}
Write-Output 'All sample page text fits its allocated area. These are typography proofs, not game screenshots.'
