#!/bin/sh
# Publish a built gozpak binary repo to GitHub Releases (M2b).
# Usage: ./scripts/publish.sh <dir-with-gpkgs> [release-tag] [sign-key-file]
#
#   1. gozpak index-build <dir> <release-base-url>
#   2. gozpak sign <dir>   (GOZPAK_SIGN_KEY=<seed>)
#   3. gh release upload  : *.gpkg + index.json + index.json.sig
#
# The release URL becomes the client GOZPAK_REPOS endpoint:
#   https://github.com/Gozjaro/gozjaro-repo/releases/download/<tag>/
set -e

REPO_DIR="${1:?usage: publish.sh <dir-with-gpkgs> [tag] [sign-key]}"
TAG="${2:-stable}"
KEY="${3:-$HOME/.secrets/gozjaro-repo.key}"
GH_REPO="Gozjaro/gozjaro-repo"
GOZPAK="${GOZPAK:-gozpak}"

command -v gh >/dev/null || { echo "error: 'gh' (GitHub CLI) required" >&2; exit 1; }
command -v "$GOZPAK" >/dev/null || { echo "error: '$GOZPAK' not in PATH (set GOZPAK=...)" >&2; exit 1; }
[ -f "$KEY" ] || { echo "error: signing key '$KEY' not found (packaging host only)" >&2; exit 1; }

BASE="https://github.com/$GH_REPO/releases/download/$TAG"
n_gpkg=$(find "$REPO_DIR" -maxdepth 1 -name '*.gpkg' | wc -l | tr -d ' ')
[ "$n_gpkg" -ge 1 ] || { echo "error: no .gpkg files in $REPO_DIR" >&2; exit 1; }

echo "=> index-build: $n_gpkg .gpkg packages, base-url $BASE"
"$GOZPAK" index-build "$REPO_DIR" "$BASE"
GOZPAK_SIGN_KEY="$KEY" "$GOZPAK" sign "$REPO_DIR"
[ -f "$REPO_DIR/index.json.sig" ] || { echo "error: sign produced no index.json.sig" >&2; exit 1; }

echo "=> gh release upload -> $GH_REPO @ $TAG"
gh release create "$TAG" --title "GozJaro $TAG binary repo" --notes "gozpak binary repo (M2b): $n_gpkg packages, signed index." \
    --target main --draft=false 2>/dev/null || true   # release may already exist
gh release upload "$TAG" "$REPO_DIR"/*.gpkg --clobber
gh release upload "$TAG" "$REPO_DIR/index.json" "$REPO_DIR/index.json.sig" --clobber

echo "done. clients:"
echo "  echo '$BASE' > /etc/gozpak/repos.conf"
echo "  gozpak sync && gozpak list-remote"
