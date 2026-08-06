#!/usr/bin/env bash
# =========================================================================
#  Bshamel UI — garde-fous de design
#
#  Vérifie mécaniquement les règles de CLAUDE.md qui décident de la cohérence
#  visuelle. Elles sont faciles à respecter et faciles à oublier : la CI est le
#  seul endroit où l'oubli se voit encore dans six mois.
#
#  Usage : bash dev/scripts/check-design.sh
#  Sortie : 0 si tout va bien, 1 sinon (avec le détail des infractions).
# =========================================================================

set -uo pipefail
cd "$(dirname "$0")/../.."

FAILED=0

report() {
    local rule="$1"; shift
    local hits="$1"; shift
    if [[ -n "$hits" ]]; then
        echo "✗ $rule"
        echo "$hits" | sed 's/^/    /'
        echo
        FAILED=1
    else
        echo "✓ $rule"
    fi
}

# Fichiers Lua du jeu, hors bibliothèques éventuelles.
lua_files() {
    find Core UI Modules Locales -name '*.lua' 2>/dev/null | sort
}

# -------------------------------------------------------------------------
# 1. CreateFrame hors de la fabrique de widgets
# -------------------------------------------------------------------------
hits=$(lua_files \
    | grep -v '^UI/Widgets/' \
    | grep -v '^Core/Init\.lua$' \
    | xargs grep -n 'CreateFrame(' 2>/dev/null || true)
report "CreateFrame confiné à UI/Widgets/ et Core/Init.lua" "$hits"

# -------------------------------------------------------------------------
# 2. Polices en dur hors du thème
# -------------------------------------------------------------------------
hits=$(lua_files \
    | grep -v '^UI/Theme\.lua$' \
    | xargs grep -nE '"(GameFont|SystemFont|Number(Font)?)[A-Za-z_]*"|Fonts\\\\|SetFont\(' 2>/dev/null || true)
report "Polices déclarées uniquement dans UI/Theme.lua" "$hits"

# -------------------------------------------------------------------------
# 3. Couleurs et chemins de texture en dur hors du thème
# -------------------------------------------------------------------------
hits=$(lua_files \
    | grep -v '^UI/Theme\.lua$' \
    | xargs grep -nE 'SetColorTexture\([0-9]|SetTextColor\([0-9]|SetVertexColor\([0-9]|"Interface\\\\' 2>/dev/null || true)
report "Couleurs et textures littérales absentes hors UI/Theme.lua" "$hits"

# -------------------------------------------------------------------------
# 4. Noms de templates XML hors du thème
# -------------------------------------------------------------------------
hits=$(lua_files \
    | grep -v '^UI/Theme\.lua$' \
    | xargs grep -nE '"[A-Za-z0-9_]+Template"' 2>/dev/null || true)
report "Templates du client déclarés uniquement dans T.TEMPLATES" "$hits"

# -------------------------------------------------------------------------
# 5. Branches par numéro de version de patch
# -------------------------------------------------------------------------
hits=$(lua_files \
    | xargs grep -nE 'GetBuildInfo\(\)|WOW_PROJECT_ID' 2>/dev/null || true)
report "Aucun test de version de patch (utiliser un test de capacité)" "$hits"

# -------------------------------------------------------------------------
# 6. Globals non préfixés
# -------------------------------------------------------------------------
# Une affectation en début de ligne sans `local` crée un global. On tolère
# uniquement les noms préfixés BshamelUI / SLASH_BSHAMELUI.
hits=$(lua_files \
    | xargs grep -nE '^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=' 2>/dev/null \
    | grep -vE ':(BshamelUI|SLASH_BSHAMELUI)' || true)
report "Aucun global non préfixé" "$hits"

# -------------------------------------------------------------------------
# 7. Réglages livrés cochés
# -------------------------------------------------------------------------
# Aucun défaut ne vaut `true` : installer l'addon ne doit rien changer au jeu.
# Une case commandée par un interrupteur éteint ne fait pas exception — elle est
# invisible, pas absente, et le jour où l'interrupteur s'allume elle décide à la
# place du joueur.
hits=$(awk '/^    defaults = \{/ { inside = 1 }
            inside && /=[[:space:]]*true,/ { print FILENAME ":" FNR ":" $0 }
            inside && /^    \},/ { inside = 0 }' Modules/*.lua || true)
report "Aucun réglage livré coché (tout défaut à false)" "$hits"

# -------------------------------------------------------------------------
# 8. Parité des clés de locale
# -------------------------------------------------------------------------
keys_of() {
    grep -oE '^\s*\["[^"]+"\]' "$1" 2>/dev/null | grep -oE '"[^"]+"' | sort -u
}
missing=$(comm -23 <(keys_of Locales/enUS.lua) <(keys_of Locales/frFR.lua) || true)
report "Toute clé enUS existe en frFR" "$missing"

extra=$(comm -13 <(keys_of Locales/enUS.lua) <(keys_of Locales/frFR.lua) || true)
report "Aucune clé frFR orpheline (absente de enUS)" "$extra"

# -------------------------------------------------------------------------
# 9. Le compilateur du client
# -------------------------------------------------------------------------
# Le jeu embarque **Lua 5.1**, dont les plafonds par fonction sont plus bas que
# ceux des versions récentes : deux cent cinquante registres, deux cents
# variables locales. Un fichier qui les dépasse ne se compile pas du tout —
# `function or expression too complex` —, et ce qui disparaît n'est pas la ligne
# fautive mais le module entier, son entrée dans le menu comprise.
#
# Ce n'est pas une erreur qu'une relecture voit, ni `luacheck`, ni un `luac`
# récent : seul le compilateur de cette version-là la rend. D'où ce contrôle, et
# d'où `lua5.1` dans l'image du job `lint`.
#
# Le remède, quand il tombe : sortir la grande table du corps du fichier et la
# rendre depuis une fonction, qui repart de zéro registre (voir `pageOptions`
# dans `Modules/Nameplates.lua`).
LUAC=$(command -v luac5.1 || command -v luac-5.1 || command -v luac || true)
if [[ -n "$LUAC" ]]; then
    hits=$(lua_files | xargs -n 1 "$LUAC" -p 2>&1 >/dev/null || true)
    report "Tout compile avec le Lua du client ($($LUAC -v 2>&1 | head -1))" "$hits"
else
    echo "· luac introuvable : compilation non vérifiée"
fi

echo
if [[ $FAILED -eq 0 ]]; then
    echo "Tous les garde-fous de design sont respectés."
else
    echo "Des règles de CLAUDE.md sont violées — voir ci-dessus."
fi
exit $FAILED
