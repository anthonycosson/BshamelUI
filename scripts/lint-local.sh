#!/usr/bin/env bash
# =========================================================================
#  Bshamel UI — vérification locale
#
#  Deux passes :
#    1. syntaxe pure  (luac -p)         — rapide, attrape les fautes de frappe
#    2. diagnostics   (lua-language-server --check) — globals inconnus,
#       variables mortes, incohérences de types annotés
#
#  luacheck n'est pas utilisé en local : il dépend de luafilesystem, qui exige
#  un compilateur C sous Windows. Il tourne dans la CI, où l'image Alpine en a
#  un. lua-language-server couvre le même besoin sans compilation.
#
#  Usage : bash scripts/lint-local.sh
# =========================================================================

set -uo pipefail
cd "$(dirname "$0")/.."

LUAC="${LUAC:-$LOCALAPPDATA/Programs/Lua/bin/luac.exe}"
LLS="${LLS:-$LOCALAPPDATA/Microsoft/WinGet/Packages/LuaLS.lua-language-server_Microsoft.Winget.Source_8wekyb3d8bbwe/bin/lua-language-server.exe}"

FAILED=0

echo "== syntaxe =="
if [[ -x "$LUAC" ]] || command -v luac >/dev/null 2>&1; then
    [[ -x "$LUAC" ]] || LUAC=$(command -v luac)
    while read -r file; do
        if ! out=$("$LUAC" -p "$file" 2>&1); then
            echo "  ✗ $file"
            echo "    $out"
            FAILED=1
        fi
    done < <(find Core UI Modules Locales -name '*.lua' | sort)
    [[ $FAILED -eq 0 ]] && echo "  ✓ tous les fichiers compilent"
else
    echo "  — luac introuvable, passe ignorée (définir \$LUAC)"
fi

echo
echo "== diagnostics =="
if [[ -x "$LLS" ]] || command -v lua-language-server >/dev/null 2>&1; then
    [[ -x "$LLS" ]] || LLS=$(command -v lua-language-server)
    logdir=$(mktemp -d)
    "$LLS" --check "$(pwd -W 2>/dev/null || pwd)" \
           --checklevel=Warning \
           --logpath="$logdir" 2>&1 \
        | sed 's/\x1b\[[0-9;]*m//g' \
        | grep -vE '^\s*$' \
        | tail -40
    if [[ -s "$logdir/check.json" ]] && ! grep -q '^\[\]$' "$logdir/check.json"; then
        FAILED=1
    fi
    rm -rf "$logdir"
else
    echo "  — lua-language-server introuvable, passe ignorée (définir \$LLS)"
fi

echo
echo "== garde-fous de design =="
bash scripts/check-design.sh || FAILED=1

exit $FAILED
