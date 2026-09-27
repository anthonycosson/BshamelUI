# =========================================================================
#  Bshamel UI — pose et relève de la sonde
#
#  La sonde n'est pas montée par la jonction NTFS du dépôt : elle doit vivre
#  dans le client qu'on veut mesurer, qui n'est pas forcément celui où l'on
#  développe. Ce script la copie, ajuste son `## Interface` au besoin, puis sait
#  retrouver le fichier de résultat dans WTF.
#
#  Poser :
#    powershell -File dev/scripts/install-probe.ps1 `
#        -Client "C:\Program Files (x86)\World of Warcraft\_retail_"
#
#    Sur un client dont on ignore le numéro d'interface — une bêta —, soit on
#    coche « Charger les AddOns périmés » à l'écran des personnages, soit on
#    passe `-Interface 11507` et la ligne est réécrite à la copie.
#
#  Relever, après un /reload :
#    powershell -File dev/scripts/install-probe.ps1 -Client "...\_retail_" -Collecter
#
#    Affiche le chemin du résultat et la commande d'étalonnage à lancer.
# =========================================================================

[CmdletBinding()]
param(
    # Dossier du client : celui qui contient `Interface` et `WTF`.
    [Parameter(Mandatory = $true)]
    [string] $Client,

    # Numéro à écrire dans `## Interface`. Omis, la valeur du dépôt est gardée.
    [int] $Interface = 0,

    # Ne rien poser : retrouver le résultat de la dernière passe.
    [switch] $Collecter
)

$ErrorActionPreference = 'Stop'

$repo  = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$name  = 'BshamelUI_Probe'
$src   = Join-Path $repo "dev\probe\$name"

if (-not (Test-Path $Client)) {
    throw "Client introuvable : $Client"
}

# -------------------------------------------------------------------------
#  Relève
# -------------------------------------------------------------------------
if ($Collecter) {
    $wtf = Join-Path $Client 'WTF\Account'
    if (-not (Test-Path $wtf)) { throw "Pas de WTF sous $Client — le client s'est-il lancé ?" }

    $found = Get-ChildItem -Path $wtf -Recurse -Filter "$name.lua" -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending

    if (-not $found) {
        Write-Host "Aucun résultat. La sonde écrit dans WTF à la déconnexion :" -ForegroundColor Yellow
        Write-Host "  se connecter, faire /reload, puis relancer cette commande."
        return
    }

    $sv = $found[0]
    Write-Host "Résultat : $($sv.FullName)"
    Write-Host "           écrit le $($sv.LastWriteTime), $([math]::Round($sv.Length / 1KB)) Ko"
    Write-Host ""
    Write-Host "Étalonner le dépôt sur ce relevé (à ne faire que depuis RETAIL) :" -ForegroundColor Cyan
    Write-Host "  bash dev/scripts/make-probe.sh --calibrer `"$($sv.FullName)`""
    return
}

# -------------------------------------------------------------------------
#  Pose
# -------------------------------------------------------------------------
$addons = Join-Path $Client 'Interface\AddOns'
if (-not (Test-Path $addons)) { New-Item -ItemType Directory -Force -Path $addons | Out-Null }

$dest = Join-Path $addons $name

# On copie, on ne monte pas de jonction : la sonde d'un client donné peut avoir
# un `## Interface` différent de celui du dépôt, et le dépôt doit rester propre.
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
Copy-Item -Recurse -Path $src -Destination $dest

if ($Interface -gt 0) {
    $toc   = Join-Path $dest "$name.toc"
    $lines = Get-Content $toc
    $lines = $lines -replace '^## Interface:.*', "## Interface: $Interface"
    Set-Content -Path $toc -Value $lines -Encoding utf8
    Write-Host "## Interface réécrit à $Interface."
}

$data = Join-Path $dest 'Data.lua'
$n = (Select-String -Path $data -Pattern '^\s+"' | Measure-Object).Count

Write-Host "Sonde posée dans $dest ($n lignes de demandes)." -ForegroundColor Green
Write-Host ""
Write-Host "Ensuite, en jeu :"
Write-Host "  1. activer BshamelUI_Probe (cocher « Charger les AddOns périmés » si besoin)"
Write-Host "  2. se connecter — la sonde travaille sans rien dire ; /buiprobe donne le rapport"
Write-Host "  3. /reload, pour que le résultat parte dans WTF"
Write-Host "  4. install-probe.ps1 -Client `"$Client`" -Collecter"
