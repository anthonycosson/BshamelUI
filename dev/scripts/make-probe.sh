#!/usr/bin/env bash
# =========================================================================
#  Bshamel UI — générateur de sonde de compatibilité
#
#  Lit le dépôt et en extrait **tout ce que l'addon demande au client** : les
#  fonctions d'API, les globales, les cadres nommés, les événements, les CVars,
#  les templates XML et les atlas. Écrit la liste dans
#  `dev/probe/BshamelUI_Probe/Data.lua`.
#
#  L'addon de sonde, installé sur un client inconnu — la bêta de *World of
#  Warcraft: Forever*, par exemple —, teste cette liste demande par demande et
#  dit, fichier par fichier, ce qui manque. Le triage des modules portables
#  cesse alors d'être une opinion.
#
#  Ce script ne devine rien : si un nom n'est pas dans le dépôt, il n'est pas
#  dans la liste. Le relancer après chaque modification du code.
#
#  ---------------------------------------------------------------------
#  Deux passes, dans cet ordre
#  ---------------------------------------------------------------------
#
#    bash dev/scripts/make-probe.sh
#        Engendre la liste. Les cadres du client y sont repérés à la forme de
#        leur nom (`"BuffIconCooldownViewer"`), ce qui ramène aussi des noms de
#        méthodes et de scripts — `SetPoint`, `OnUpdate` — qui ne sont pas des
#        globales. Tant qu'ils sont là, les scores mentent.
#
#    bash dev/scripts/make-probe.sh --calibrer <SavedVariables/BshamelUI_Probe.lua>
#        Étalonne sur **retail**, le seul client dont on sait qu'il tient toutes
#        les promesses de l'addon. Ce qui manque là-bas ne peut pas renseigner
#        sur Forever : ou c'est un faux positif, ou c'est du code déjà mort.
#        Dans les deux cas on l'écarte, et on note le nom dans
#        `dev/probe/absent-du-retail.txt` pour que l'exclusion reste relisible.
#
#  Autrement dit : sonder retail d'abord, Forever ensuite. Le second rapport est
#  alors une différence avec une référence connue, et chaque absence est vraie.
# =========================================================================

set -uo pipefail
cd "$(dirname "$0")/../.."

export LC_ALL=C

OUT="dev/probe/BshamelUI_Probe/Data.lua"
DENY="dev/probe/absent-du-retail.txt"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

lua_files() {
    find Core UI Modules Locales -name '*.lua' 2>/dev/null | sort
}

# Extrait la dernière chaîne entre guillemets de chaque ligne.
last_string() { grep -oE '"[^"]+"$' | tr -d '"'; }

# -------------------------------------------------------------------------
# 0. Étalonnage, si on nous en donne l'occasion
# -------------------------------------------------------------------------
if [[ "${1:-}" == "--calibrer" ]]; then
    SV="${2:-}"
    if [[ ! -f "$SV" ]]; then
        echo "usage : bash dev/scripts/make-probe.sh --calibrer <chemin du BshamelUI_Probe.lua de WTF>" >&2
        exit 2
    fi
    # Le client écrit une entrée par ligne. On ne lit que le bloc `results`,
    # et on n'en retient que les refus.
    awk '/\["results"\] = \{/{f=1; next} f && /^\t\}/{exit}
         f && /= false,/ { if (match($0, /\["[^"]+"\]/)) print substr($0, RSTART+2, RLENGTH-4) }' "$SV" \
        | sort -u > "$TMP/deny.new"

    {
        echo "# Engendré par \`make-probe.sh --calibrer\`, le $(date -u '+%Y-%m-%d')."
        echo "#"
        echo "# Demandes que **retail** ne tient pas. Une demande absente du client de"
        echo "# référence ne dit rien de Forever : c'est soit un nom que le générateur a"
        echo "# pris pour une globale à tort (une méthode, un script, un libellé), soit"
        echo "# du code de l'addon qui vise une API disparue — à regarder, mais ailleurs."
        echo "#"
        echo "# Relire cette liste de temps en temps : ce qui s'y trouve est exclu du"
        echo "# rapport, donc invisible."
        cat "$TMP/deny.new"
    } > "$DENY"

    printf 'étalonné sur %s : %s demandes écartées, écrites dans %s.\n' \
        "$SV" "$(wc -l < "$TMP/deny.new")" "$DENY"
    echo
fi

# La liste d'exclusion, si elle existe. Sans elle, on engendre quand même — le
# rapport est simplement plus bruyant.
if [[ -f "$DENY" ]]; then
    grep -vE '^\s*(#|$)' "$DENY" | sort -u > "$TMP/deny"
else
    : > "$TMP/deny"
fi

# -------------------------------------------------------------------------
# 1. L'univers des symboles : ce que le code nomme, et rien d'autre
# -------------------------------------------------------------------------

# a) API à espace de noms, telle qu'elle est appelée : `C_Timer.After`.
lua_files | xargs grep -hoE '\bC_[A-Za-z0-9_]+\.[A-Za-z0-9_]+' 2>/dev/null \
    | sort -u > "$TMP/universe"

# b) Globales du client. `.luacheckrc` en tient déjà la liste exacte — c'est sa
#    règle d'entretien (« n'ajouter un nom qu'au moment où on l'utilise »), donc
#    la seule liste du dépôt qui soit à la fois complète et sans remplissage.
awk '/^read_globals = \{/{f=1} f{print} f&&/^\}/{exit}' .luacheckrc \
    | grep -oE '"[A-Za-z_][A-Za-z0-9_]*"' | tr -d '"' | sort -u > "$TMP/globals"

# Ce qui n'a aucun pouvoir discriminant : Lua de base et les extensions que tous
# les clients portent depuis toujours. Les garder gonflerait le score de chaque
# fichier d'autant de succès gratuits.
sort -u > "$TMP/trivial" <<'TRIVIAL'
date
format
select
strfind
strjoin
strlower
strsplit
strtrim
strupper
time
tinsert
tostringall
tremove
unpack
wipe
TRIVIAL

comm -23 "$TMP/globals" "$TMP/trivial" >> "$TMP/universe"
sort -u -o "$TMP/universe" "$TMP/universe"

# c) Les cadres que le code nomme par une chaîne, jamais par un identifiant :
#    `local VIEWER = "BuffIconCooldownViewer"`, puis `_G[VIEWER]`.
#
#    Ce sont les demandes les plus fragiles de tout l'addon — un cadre de
#    Blizzard n'existe que sur le client qui porte la fonctionnalité — et
#    `luacheck` ne les voit pas : ce ne sont pas des identifiants.
#
#    On les reconnaît à leur forme : capitale initiale, au moins huit lettres,
#    au moins deux capitales, pas de majuscules seules (ce serait un événement).
#    `Locales/` est écarté, ses chaînes sont des libellés. Le filet ramène
#    forcément des noms de méthodes ; c'est l'étalonnage sur retail qui les
#    retire, pas une liste écrite à la main.
find Core UI Modules -name '*.lua' | sort \
    | xargs grep -hoE '"[A-Z][A-Za-z0-9_]{7,}"' 2>/dev/null \
    | tr -d '"' \
    | grep -vE '^[A-Z0-9_]+$' \
    | awk '{ if (gsub(/[A-Z]/, "&") >= 2) print }' \
    | sort -u > "$TMP/frames"

# -------------------------------------------------------------------------
# 2. Les demandes qui ne sont pas des symboles
# -------------------------------------------------------------------------
# Un préfixe dit à la sonde comment tester. Un symbole nu se cherche dans `_G`,
# le reste a son propre chemin — on ne teste pas l'existence d'un événement
# comme celle d'une fonction.

# `T.TEMPLATES` : les templates XML de Blizzard, tous les replis compris.
awk '/^T\.TEMPLATES = \{/{f=1} f{print} f&&/^\}/{exit}' UI/Theme.lua \
    | grep -oE '"[A-Za-z0-9_]+"' | tr -d '"' | sed 's/^/tmpl:/' | sort -u > "$TMP/tmpl"

# `T.ATLAS` : les atlas du client. Un atlas absent ne casse rien (`T.TrySetAtlas`
# refuse poliment), mais il laisse un trou à l'écran.
awk '/^T\.ATLAS = \{/{f=1} f{print} f&&/^\}/{exit}' UI/Theme.lua \
    | grep -oE '"[A-Za-z0-9_-]+"' | tr -d '"' | sed 's/^/atlas:/' | sort -u > "$TMP/atlas"

# Ni les templates ni les atlas n'entrent dans l'univers : ce ne sont pas des
# identifiants, ils ne se retrouveront jamais dans les jetons d'un fichier. Ils
# rejoignent directement la table des demandes, plus bas.

# -------------------------------------------------------------------------
# 3. Qui demande quoi
# -------------------------------------------------------------------------
# Le verdict utile n'est pas « il manque trente demandes » mais « ce module-ci
# est portable, celui-là ne l'est pas ». Il faut donc rattacher chaque demande
# au fichier qui la formule.

: > "$TMP/pairs"
while IFS= read -r f; do
    # Symboles : on ne retient que ce qui est dans l'univers. L'alternative
    # dotée vient en premier — `grep` prend la plus longue à la même position,
    # donc `C_Timer.After` ne se découpe pas en `C_Timer` et `After`.
    grep -ohE '\bC_[A-Za-z0-9_]+\.[A-Za-z0-9_]+|\b[A-Za-z_][A-Za-z0-9_]*\b' "$f" \
        | sort -u > "$TMP/tok"
    comm -12 "$TMP/tok" "$TMP/universe" | sed "s#^#$f\t#" >> "$TMP/pairs"

    # Cadres nommés par une chaîne, dans ce fichier-ci.
    grep -ohE '"[A-Z][A-Za-z0-9_]{7,}"' "$f" 2>/dev/null | tr -d '"' | sort -u > "$TMP/tok"
    comm -12 "$TMP/tok" "$TMP/frames" | sed "s#^#$f\t#" >> "$TMP/pairs"

    # Événements. Un nom inconnu fait lever `RegisterEvent` : c'est le test.
    grep -ohE 'Register(Unit)?Event\("[A-Za-z0-9_]+"' "$f" 2>/dev/null \
        | last_string | sed "s#^#$f\tevent:#" >> "$TMP/pairs"

    # CVars, dans les deux formes que le dépôt emploie : le descripteur d'un
    # réglage (`cvar = "..."`) et l'appel direct.
    grep -ohE 'cvar[[:space:]]*=[[:space:]]*"[^"]+"|(Get|Set)CVar[A-Za-z]*\("[^"]+"' "$f" 2>/dev/null \
        | last_string | sed "s#^#$f\tcvar:#" >> "$TMP/pairs"
done < <(lua_files)

# Templates et atlas sont nommés dans `UI/Theme.lua` et employés partout : les
# rattacher au thème dit la vérité sur l'endroit où la réparation se ferait.
sed 's#^#UI/Theme.lua\t#' "$TMP/tmpl" "$TMP/atlas" >> "$TMP/pairs"

sort -u -o "$TMP/pairs" "$TMP/pairs"

# L'exclusion tombe ici, une fois pour toutes : sur la table des demandes, donc
# sur la liste à tester comme sur les scores par fichier.
if [[ -s "$TMP/deny" ]]; then
    awk -F'\t' 'NR==FNR { out[$0]=1; next } !($2 in out)' "$TMP/deny" "$TMP/pairs" > "$TMP/kept"
    mv "$TMP/kept" "$TMP/pairs"
fi

cut -f2 "$TMP/pairs" | sort -u > "$TMP/checks"

# -------------------------------------------------------------------------
# 4. Écriture
# -------------------------------------------------------------------------
{
    cat <<'HEADER'
-- =========================================================================
--  Ce fichier est ENGENDRÉ par `dev/scripts/make-probe.sh`.
--  Ne pas l'éditer : toute modification sera écrasée à la prochaine passe.
--
--  Il ne contient que des noms relevés dans le dépôt. C'est la liste des
--  promesses que Bshamel UI demande au client de tenir.
-- =========================================================================

local _, P = ...

HEADER
    echo "P.GENERATED  = \"$(date -u '+%Y-%m-%d %H:%MZ')\""
    echo "P.SOURCE     = \"$(git describe --tags --always --dirty 2>/dev/null || echo 'inconnu')\""
    if [[ -s "$TMP/deny" ]]; then
        echo "P.CALIBRATED = true   -- étalonné sur retail : toute absence est vraie"
    else
        echo "P.CALIBRATED = false  -- NON étalonné : des faux positifs traînent encore"
    fi
    echo

    echo "-- Tout ce qu'il faut tester, une fois chacun."
    echo "P.CHECKS = {"
    sed 's/^/    "/; s/$/",/' "$TMP/checks"
    echo "}"
    echo

    echo "-- Qui demande quoi. La clé est le fichier du dépôt."
    echo "P.USERS = {"
    awk -F'\t' '
        $1 != prev {
            if (prev != "") print "    },"
            printf "    [\"%s\"] = {\n", $1
            prev = $1
        }
        { printf "        \"%s\",\n", $2 }
        END { if (prev != "") print "    }," }
    ' "$TMP/pairs"
    echo "}"
} > "$OUT"

# -------------------------------------------------------------------------
# 5. Le compilateur du client
# -------------------------------------------------------------------------
# Même garde-fou que `check-design.sh` : le jeu embarque Lua 5.1, et une table
# trop grosse ne casse pas une ligne, elle empêche le fichier de se compiler.
LUAC=$(command -v luac5.1 || command -v luac-5.1 || command -v luac || true)
if [[ -n "$LUAC" ]]; then
    if ! "$LUAC" -p "$OUT" 2>&1; then
        echo "✗ $OUT ne compile pas — sonde inutilisable." >&2
        exit 1
    fi
    echo "· compilé sans erreur par $($LUAC -v 2>&1 | head -1)"
fi

printf '%s : %s demandes, %s fichiers rattachés.\n' \
    "$OUT" "$(wc -l < "$TMP/checks")" "$(cut -f1 "$TMP/pairs" | sort -u | wc -l)"

if [[ ! -s "$TMP/deny" ]]; then
    echo
    echo "⚠ Liste non étalonnée. Installer la sonde sur **retail**, faire /reload,"
    echo "  puis relancer avec --calibrer <chemin du BshamelUI_Probe.lua de WTF>."
    echo "  Sans cette passe, les scores comptent des absences qui n'en sont pas."
fi
