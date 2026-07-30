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
# 7. Parité des clés de locale
# -------------------------------------------------------------------------
keys_of() {
    grep -oE '^\s*\["[^"]+"\]' "$1" 2>/dev/null | grep -oE '"[^"]+"' | sort -u
}
missing=$(comm -23 <(keys_of Locales/enUS.lua) <(keys_of Locales/frFR.lua) || true)
report "Toute clé enUS existe en frFR" "$missing"

extra=$(comm -13 <(keys_of Locales/enUS.lua) <(keys_of Locales/frFR.lua) || true)
report "Aucune clé frFR orpheline (absente de enUS)" "$extra"

echo
if [[ $FAILED -eq 0 ]]; then
    echo "Tous les garde-fous de design sont respectés."
else
    echo "Des règles de CLAUDE.md sont violées — voir ci-dessus."
fi
exit $FAILED
