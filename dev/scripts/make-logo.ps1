# =========================================================================
#  Fabrique media/logo.tga a partir du visuel source.
#
#  World of Warcraft ne lit ni PNG ni JPEG : il lui faut un TGA non compresse
#  (ou un BLP), et des cotes en puissance de deux. Aucun outil d'image n'etant
#  installe, on decode le PNG avec System.Drawing et on ecrit l'en-tete TGA a la
#  main -- le format tient en dix-huit octets suivis des pixels bruts.
#
#  Le disque alpha est cuit dans la texture plutot que pose en jeu : le trou de
#  la bordure de minicarte est rond, et un masque applique a l'execution est une
#  dependance de plus qui peut ne pas prendre (voir dev/docs/API_NOTES.md).
# =========================================================================

param(
    [string]$Source,
    [string]$Target,
    [int]$CropX, [int]$CropY, [int]$CropSize,
    [int]$Size = 128
)

Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Image]::FromFile($Source)
Write-Output ("source : {0} x {1}" -f $src.Width, $src.Height)

$dst = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g   = [System.Drawing.Graphics]::FromImage($dst)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$to   = New-Object System.Drawing.Rectangle 0, 0, $Size, $Size
$from = New-Object System.Drawing.Rectangle $CropX, $CropY, $CropSize, $CropSize
$g.DrawImage($src, $to, $from, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()

# --- pixels : BGRA, avec le disque alpha ---------------------------------
$center = $Size / 2.0
$solid  = $center - 2.0   # rayon plein
$edge   = $center - 0.5   # rayon ou l'alpha atteint zero

$bytes = New-Object byte[] ($Size * $Size * 4)
$i = 0
for ($y = 0; $y -lt $Size; $y++) {
    for ($x = 0; $x -lt $Size; $x++) {
        $p = $dst.GetPixel($x, $y)

        $dx = $x + 0.5 - $center
        $dy = $y + 0.5 - $center
        $d  = [Math]::Sqrt($dx * $dx + $dy * $dy)

        $a = 1.0
        if ($d -ge $edge) { $a = 0.0 }
        elseif ($d -gt $solid) { $a = ($edge - $d) / ($edge - $solid) }

        $alpha = [byte][Math]::Round($p.A * $a)

        $bytes[$i]     = $p.B
        $bytes[$i + 1] = $p.G
        $bytes[$i + 2] = $p.R
        $bytes[$i + 3] = $alpha
        $i += 4

        $dst.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($alpha, $p.R, $p.G, $p.B))
    }
}

# Apercu lisible par un humain : le TGA ne s'ouvre nulle part facilement.
$preview = [System.IO.Path]::ChangeExtension($Target, $null) + "preview.png"
$dst.Save($preview, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output ("apercu : {0}" -f $preview)

$dst.Dispose()
$src.Dispose()

# --- en-tete TGA ----------------------------------------------------------
# 0 : longueur du champ identifiant      0 : pas de palette
# 2 : image couleurs vraies non compressee
# puis origine, cotes, profondeur, et le descripteur : 8 bits d'alpha (0x08)
# plus l'origine en haut a gauche (0x20), sans quoi l'image sort a l'envers.
$header = [byte[]](
    0, 0, 2, 0, 0, 0, 0, 0,
    0, 0, 0, 0,
    ($Size -band 0xFF), (($Size -shr 8) -band 0xFF),
    ($Size -band 0xFF), (($Size -shr 8) -band 0xFF),
    32, 0x28
)

$out = New-Object System.IO.MemoryStream
$out.Write($header, 0, $header.Length)
$out.Write($bytes, 0, $bytes.Length)
[System.IO.File]::WriteAllBytes($Target, $out.ToArray())
$out.Dispose()

Write-Output ("ecrit  : {0} ({1} octets, {2}x{2}, 32 bits non compresse)" -f `
    $Target, (Get-Item $Target).Length, $Size)
