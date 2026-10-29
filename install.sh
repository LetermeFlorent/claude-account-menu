#!/bin/sh
set -e
src=$(cd "$(dirname "$0")" && pwd)
dst="$HOME/.local/bin"
marker="$dst/clm.installing"
manifest="$dst/clm.files"
stamp="$dst/clm.version"
pending=

finish() {
  rm -f "$marker"
  if [ -n "$pending" ]; then rm -f "$pending"; fi
}

list_shipped() {
  (cd "$1" && find . -type f) | sed 's|^\./||' | grep -v '^[^/]*\.cmd$' | LC_ALL=C sort
}

contains() {
  printf '%s\n' "$1" | grep -Fxiq -- "$2"
}

place_file() {
  target="$dst/$1"
  dir=$(dirname "$target")
  mkdir -p "$dir"
  pending="$dir/.$(basename "$target").$$.tmp"
  cp "$src/bin/$1" "$pending"
  if [ "$1" = clm ]; then chmod +x "$pending"; fi
  mv -f "$pending" "$target"
  pending=
}

copy_missing() {
  while IFS= read -r rel; do
    if [ -n "$rel" ] && [ ! -e "$dst/$rel" ]; then place_file "$rel"; fi
  done <<EOF
$files
EOF
}

copy_changed() {
  while IFS= read -r rel; do
    if [ -n "$rel" ] && ! cmp -s "$src/bin/$rel" "$dst/$rel"; then place_file "$rel"; fi
  done <<EOF
$files
EOF
}

stale_candidates() {
  if [ -f "$manifest" ]; then tr -d '\r' < "$manifest"; fi
  printf '%s\n' "$files" | sed -n 's|^\([^/]*\)/.*|\1|p' | LC_ALL=C sort -u | while IFS= read -r top; do
    if [ -d "$dst/$top" ]; then (cd "$dst" && find "./$top" -type f) | sed 's|^\./||'; fi
  done
}

prune_dirs() {
  folder=$1
  while [ "$folder" != . ] && [ "$folder" != / ]; do
    rmdir "$dst/$folder" 2>/dev/null || return 0
    folder=$(dirname "$folder")
  done
}

remove_stale() {
  candidates=$(stale_candidates | LC_ALL=C sort -u)
  while IFS= read -r rel; do
    case $rel in
      ''|/*|..|../*|*/..|*/../*|clm.version|clm.files|clm.installing) continue ;;
    esac
    if contains "$files" "$rel" || [ -d "$dst/$rel" ]; then continue; fi
    rm -f "$dst/$rel"
    prune_dirs "$(dirname "$rel")"
  done <<EOF
$candidates
EOF
}

write_manifest() {
  pending="$dst/.clm.files.$$.tmp"
  printf '%s\n' "$files" > "$pending"
  mv -f "$pending" "$manifest"
  pending=
}

write_version() {
  pending="$dst/.clm.version.$$.tmp"
  if command -v git >/dev/null 2>&1 && [ -e "$src/.git" ]; then
    if echo "$(git -C "$src" log -1 --format='%H %ct') $(git -C "$src" rev-list --count HEAD)" > "$pending"; then
      mv -f "$pending" "$stamp"
    else
      rm -f "$pending" "$stamp"
    fi
  elif [ -f "$src/clm.version" ]; then
    cp "$src/clm.version" "$pending"
    mv -f "$pending" "$stamp"
  else
    rm -f "$stamp"
  fi
  pending=
}

mkdir -p "$dst"
trap 'status=$?; finish; exit "$status"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
echo "$$" > "$marker"
files=$(list_shipped "$src/bin")
if [ -z "$files" ]; then
  echo "aucun fichier a installer dans $src/bin"
  exit 1
fi
copy_missing
copy_changed
remove_stale
write_manifest
chmod +x "$dst/clm"
echo "scripts copies dans $dst"
write_version

case ":$PATH:" in
  *":$dst:"*) ;;
  *)
    echo "$dst n'est pas dans le PATH. Ajoute cette ligne a ~/.profile, ~/.bashrc ou ~/.zshrc :"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac

if ! command -v claude >/dev/null 2>&1 && [ ! -x "$dst/claude" ]; then
  echo "Claude Code introuvable : installe-le d'abord, puis relance clm"
fi
if [ "$(uname)" = "Linux" ] && ! command -v bsdtar >/dev/null 2>&1; then
  echo "bsdtar absent : les sauvegardes seront des .tar.gz, et un .zip venu de Windows ne pourra pas etre restaure (paquet libarchive-tools)"
fi
pwsh_bin=${CLM_PWSH:-pwsh}
if ! command -v "$pwsh_bin" >/dev/null 2>&1; then
  echo "pwsh introuvable : installe PowerShell 7 (voir INSTALL.md), puis relance ce script pour le hook de la barre d'etat"
  exit 1
fi
"$pwsh_bin" -NoProfile -File "$src/install-hook.ps1"
echo "termine, lance clm"
