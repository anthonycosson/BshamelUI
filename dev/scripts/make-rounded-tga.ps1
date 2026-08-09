# =========================================================================
#  Bshamel UI — dev/scripts/make-rounded-tga.ps1
#  Genere media\rounded.tga : un carre blanc a coins arrondis, l'alpha cuit
#  dans la texture.
#
#  Pourquoi une texture a nous : le client n'a aucun rectangle a coins
#  arrondis — ses masques sont circulaires, et un masque pose a l'execution
#  peut ne pas prendre du tout (voir dev/docs/API_NOTES.md, « Un masque pose
#  sur une texture repetee est ignore en silence »). L'alpha cuit dans le
#  fichier ne depend de rien, comme le disque du logo.
#
#  Le rayon est cuit ici et declare dans UI/Theme.lua
#  (T.SIZE.ROUNDED_RECT_RADIUS) : les deux doivent bouger ensemble.
# =========================================================================
param(
    [int]$Size   = 32,
    [int]$Radius = 5,
    [string]$Out = (Join-Path $PSScriptRoot "..\..\media\rounded.tga")
)

# Sous-echantillonnage 4x4 par pixel : c'est lui qui lisse la courbe.
$sub = 4

$pixels = New-Object byte[] (18 + $Size * $Size * 4)

# En-tete TGA : type 2 (couleur, non compresse), 32 bits, 8 bits d'alpha.
$pixels[2]  = 2
$pixels[12] = $Size -band 0xFF; $pixels[13] = ($Size -shr 8) -band 0xFF
$pixels[14] = $Size -band 0xFF; $pixels[15] = ($Size -shr 8) -band 0xFF
$pixels[16] = 32
$pixels[17] = 8

$at = 18
for ($y = 0; $y -lt $Size; $y++) {
    for ($x = 0; $x -lt $Size; $x++) {
        $hit = 0
        for ($sy = 0; $sy -lt $sub; $sy++) {
            for ($sx = 0; $sx -lt $sub; $sx++) {
                $px = $x + ($sx + 0.5) / $sub
                $py = $y + ($sy + 0.5) / $sub
                # Un point est dans le rectangle arrondi si sa distance au
                # centre de coin le plus proche — les bords droits ramenant
                # cette distance a un seul axe — ne depasse pas le rayon.
                $cx = [Math]::Min([Math]::Max($px, $Radius), $Size - $Radius)
                $cy = [Math]::Min([Math]::Max($py, $Radius), $Size - $Radius)
                $dx = $px - $cx; $dy = $py - $cy
                if (($dx * $dx + $dy * $dy) -le ($Radius * $Radius)) { $hit++ }
            }
        }
        # Blanc partout, meme sous alpha nul : la teinte vient de
        # SetVertexColor, jamais du fichier. Ordre TGA : BGRA.
        $pixels[$at]     = 255
        $pixels[$at + 1] = 255
        $pixels[$at + 2] = 255
        $pixels[$at + 3] = [byte][Math]::Round(255 * $hit / ($sub * $sub))
        $at += 4
    }
}

$full = [System.IO.Path]::GetFullPath($Out)
[System.IO.File]::WriteAllBytes($full, $pixels)
Write-Host "Ecrit $full ($($pixels.Length) octets, $Size x $Size, rayon $Radius)"
