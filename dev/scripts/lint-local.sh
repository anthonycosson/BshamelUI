#!/usr/bin/env bash
# =========================================================================
#  Bshamel UI — vérification locale
#
#  Quatre passes :
#    1. syntaxe pure  (luac -p)         — rapide, attrape les fautes de frappe
#    2. diagnostics   (lua-language-server --check) — globals inconnus,
#       variables mortes, incohérences de types annotés
#    3. longueur des lignes             — la seule règle de luacheck que
#       lua-language-server ne couvre pas
#    4. garde-fous de design            — les règles de CLAUDE.md
#
#  luacheck n'est pas utilisé en local : il dépend de luafilesystem, qui exige
#  un compilateur C sous Windows. Il tourne dans la CI GitHub Actions, où le
#  runner Ubuntu en a un. lua-language-server couvre le même besoin sans compilation — sauf
#  `max_line_length`, d'où la passe 3. Sans elle, une ligne trop longue passe
#  ici et fait échouer la CI : un avertissement luacheck y est fatal.
#
#  Usage : bash dev/scripts/lint-local.sh
# =========================================================================

set -uo pipefail
cd "$(dirname "$0")/../.."

LUAC="${LUAC:-${LOCALAPPDATA:-}/Programs/Lua/bin/luac.exe}"
LLS="${LLS:-${LOCALAPPDATA:-}/Microsoft/WinGet/Packages/LuaLS.lua-language-server_Microsoft.Winget.Source_8wekyb3d8bbwe/bin/lua-language-server.exe}"

FAILED=0

echo "== syntaxe =="
# Même ordre de recherche que check-design.sh : le Lua du client est 5.1, et un
# luac plus récent laisse passer des erreurs que le jeu, lui, lève.
if [[ ! -x "$LUAC" ]]; then
    LUAC=$(command -v luac5.1 || command -v luac-5.1 || command -v luac || true)
fi
if [[ -n "$LUAC" && -x "$LUAC" ]]; then
    echo "  (compilateur : $LUAC)"
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
echo "== longueur des lignes =="
# Seuil lu dans .luacheckrc plutôt que recopié : deux valeurs qui doivent rester
# égales finissent toujours par diverger.
MAXLEN=$(sed -n 's/^max_line_length[[:space:]]*=[[:space:]]*\([0-9]\+\).*/\1/p' .luacheckrc)
MAXLEN="${MAXLEN:-120}"

# On compte les **octets**, là où luacheck compte les caractères. Un accent vaut
# deux octets en UTF-8, cette mesure est donc toujours supérieure ou égale à la
# sienne. C'est le bon sens de l'inégalité : ce qui passe ici passe forcément
# dans la CI, l'inverse n'étant pas garanti. Quelques faux positifs valent mieux
# qu'un faux négatif, qui est précisément ce qui a laissé passer une pipeline
# rouge.
long=$(while read -r file; do
    awk -v max="$MAXLEN" -v f="$file" \
        '{ n = length($0); if (n > max) printf "%s:%d (%d)\n", f, FNR, n }' "$file"
done < <(find Core UI Modules Locales -name '*.lua' | sort))

if [[ -n "$long" ]]; then
    echo "  ✗ lignes de plus de $MAXLEN caractères (luacheck W631)"
    echo "$long" | sed 's/^/    /'
    FAILED=1
else
    echo "  ✓ aucune ligne de plus de $MAXLEN caractères"
fi

echo
echo "== globals déclarés des deux côtés =="
# Deux fichiers déclarent les globales du client : `.luarc.json` pour l'analyse
# locale, `.luacheckrc` pour la CI. Ils sont tenus à la main, donc ils divergent
# — et la divergence ne se voit qu'en CI, une fois le tag posé, c'est-à-dire au
# pire moment. Une globale utilisée est ajoutée au premier, oubliée au second, et
# `luacheck` la signale comme variable indéfinie (W113).
#
# Le sens du test compte : ce qui est déclaré ici doit l'être là-bas. L'inverse
# est permis — `.luacheckrc` peut citer des noms que l'analyse locale connaît
# déjà d'elle-même.
#
# On ne lit que le **bloc des globales**, et non tout le fichier : `.luarc.json`
# porte d'autres réglages dont les valeurs sont des chaînes — les sévérités de
# diagnostics, par exemple —, et un « Warning » pris pour une globale ferait
# échouer la comparaison sans rien avoir à voir avec elle.
missing=$(comm -23 \
    <(sed -n '/"diagnostics.globals": \[/,/^  \]/p' .luarc.json \
        | grep -o '"[A-Za-z_][A-Za-z0-9_]*"' | tr -d '"' | sort -u) \
    <(sed -n '/^globals = {/,/^}/p; /^read_globals = {/,/^}/p' .luacheckrc \
        | grep -o '"[A-Za-z_][A-Za-z0-9_]*"' | tr -d '"' | sort -u) \
    | grep -vxE 'dev|require')

if [[ -n "$missing" ]]; then
    echo "  ✗ déclarés dans .luarc.json mais absents de .luacheckrc :"
    echo "$missing" | sed 's/^/    /'
    FAILED=1
else
    echo "  ✓ .luarc.json et .luacheckrc s'accordent"
fi

echo
echo "== garde-fous de design =="
bash dev/scripts/check-design.sh || FAILED=1

exit $FAILED
