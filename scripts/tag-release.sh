#!/usr/bin/env bash
# =========================================================================
#  Bshamel UI — préparer une version
#
#  Enchaîne tout ce qui doit être fait avant de publier, dans l'ordre, et
#  s'arrête au premier problème :
#
#      vérifications  ->  CHANGELOG  ->  commit  ->  tag  ->  (push)
#
#  Le push n'est PAS automatique par défaut. Pousser un tag déclenche une
#  publication réelle sur CurseForge, visible par tout le monde et pénible à
#  retirer : c'est un geste qui mérite d'être explicite. `--push` le fait quand
#  tu es sûr.
#
#  Usage :
#      bash scripts/tag-release.sh 0.2.0
#      bash scripts/tag-release.sh 0.2.0 --push
# =========================================================================

set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
PUSH="${2:-}"

die() { echo "✗ $*" >&2; exit 1; }
step() { echo; echo "── $* ──"; }

[[ -n "$VERSION" ]] || die "usage : bash scripts/tag-release.sh <version> [--push]   (ex. 0.2.0)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version attendue au format X.Y.Z, reçu « $VERSION »"

TAG="v$VERSION"
TODAY=$(date +%Y-%m-%d)

# -------------------------------------------------------------------------
step "état du dépôt"
# -------------------------------------------------------------------------
[[ -z "$(git status --porcelain)" ]] || die "l'arbre de travail contient des modifications non commitées"
git rev-parse "$TAG" >/dev/null 2>&1 && die "le tag $TAG existe déjà"
echo "✓ arbre propre, $TAG disponible"

# -------------------------------------------------------------------------
step "vérifications"
# -------------------------------------------------------------------------
bash scripts/lint-local.sh || die "les vérifications échouent — rien n'a été modifié"

# -------------------------------------------------------------------------
step "CHANGELOG"
# -------------------------------------------------------------------------
grep -q '^## Non publié' CHANGELOG.md \
    || die "CHANGELOG.md doit contenir une section « ## Non publié » décrivant cette version"

# La section en cours devient la version, et une nouvelle section vide la
# remplace pour le travail suivant.
tmp=$(mktemp)
sed "s|^## Non publié$|## Non publié\n\n## $VERSION — $TODAY|" CHANGELOG.md > "$tmp"
mv "$tmp" CHANGELOG.md
echo "✓ section $VERSION datée du $TODAY"

# -------------------------------------------------------------------------
step "commit et tag"
# -------------------------------------------------------------------------
git add CHANGELOG.md
git commit -q -m "Preparer la version $VERSION"
git tag -a "$TAG" -m "$TAG"
echo "✓ $TAG créé"

# -------------------------------------------------------------------------
step "aperçu du paquet"
# -------------------------------------------------------------------------
rm -rf .release/BshamelUI
bash .release/release.sh -d -o -z >/dev/null 2>&1 || true
if [[ -f .release/BshamelUI/BshamelUI.toc ]]; then
    grep -E '^## (Version|Author|Interface|X-Curse-Project-ID)' .release/BshamelUI/BshamelUI.toc
    echo "✓ $(find .release/BshamelUI -type f | wc -l) fichiers dans le paquet"
else
    echo "— aperçu indisponible (packager non exécuté)"
fi

# -------------------------------------------------------------------------
step "publication"
# -------------------------------------------------------------------------
if [[ "$PUSH" == "--push" ]]; then
    git push origin HEAD
    git push origin "$TAG"
    echo "✓ $TAG poussé — la pipeline construit et envoie sur CurseForge"
else
    cat <<EOF
Rien n'a été poussé. Pour publier :

    git push origin HEAD && git push origin $TAG

Pour annuler à la place :

    git tag -d $TAG && git reset --hard HEAD~1
EOF
fi
