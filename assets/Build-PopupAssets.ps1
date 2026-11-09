param([Parameter(Mandatory=$true)][string]$PaperSource,[Parameter(Mandatory=$true)][string]$SealSource)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$target=Join-Path $PSScriptRoot '..\addon\LootBot'
# Format conversion only: 32-bit uncompressed TGA with alpha, power-of-two dimensions.
function Export-Texture($sourcePath,$name,$width,$height) {
    $source=[Drawing.Image]::FromFile($sourcePath)
    $bitmap=New-Object Drawing.Bitmap($width,$height,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g=[Drawing.Graphics]::FromImage($bitmap)
    try {
        $g.Clear([Drawing.Color]::Transparent)
        $g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($source,(New-Object Drawing.Rectangle(0,0,$width,$height)))
        $writer=New-Object IO.BinaryWriter([IO.File]::Create((Join-Path $target $name)))
        try {
            $header=New-Object byte[] 18; $header[2]=2
            $header[12]=$width -band 255; $header[13]=$width -shr 8
            $header[14]=$height -band 255; $header[15]=$height -shr 8
            $header[16]=32; $header[17]=40; $writer.Write($header)
            for($y=0;$y -lt $height;$y++) { for($x=0;$x -lt $width;$x++) {
                $c=$bitmap.GetPixel($x,$y); $writer.Write([byte[]]@($c.B,$c.G,$c.R,$c.A))
            }}
        } finally { $writer.Dispose() }
    } finally { $g.Dispose(); $bitmap.Dispose(); $source.Dispose() }
}
Export-Texture $PaperSource 'PeonToast.tga' 1024 512
Export-Texture $SealSource 'DingSeal.tga' 128 128
