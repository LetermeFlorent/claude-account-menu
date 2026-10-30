#!/bin/sh
set -e
src=$(cd "$(dirname "$0")" && pwd)
dst="$HOME/.local/bin"
marker="$dst/clm.installing"
manifest="$dst/clm.files"
stamp="$dst/clm.version"
pending=
if [ -r "$src/bin/clm-text.sh" ]; then . "$src/bin/clm-text.sh"; fi
type clm_text >/dev/null 2>&1 || clm_text() { printf '%s
' "$2"; }
CLM_LANG_DIR="$src/bin/lang"

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

check_folders() {
  printf '%s
' "$files" | sed -n 's|/[^/]*$||p' | LC_ALL=C sort -u | while IFS= read -r folder; do
    while [ "$folder" != . ]; do
      if [ -e "$dst/$folder" ] && [ ! -d "$dst/$folder" ]; then
        clm_text install.sh.folderBlocked "{0} is a file, so the folder of the same name cannot be created: move it, then run the installation again" "$dst/$folder"
        exit 1
      fi
      folder=$(dirname "$folder")
    done
  done
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
  printf '%s\n' "$files" | sed -n 's|^.*/\(claude-[a-z0-9-]*\.ps1\)$|\1|p'
  printf '%s\n' "$files" | grep -E '^(lang|clm-web)/' | sed 's|/.*||' | LC_ALL=C sort -u | while IFS= read -r top; do
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
    if head=$(git -C "$src" log -1 --format='%H %ct') && count=$(git -C "$src" rev-list --count HEAD) && [ -n "$head" ] && printf '%s %s
' "$head" "$count" > "$pending"; then
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
  clm_text install.sh.noFiles "no file to install in {0}" "$src/bin"
  exit 1
fi
check_folders || exit 1
copy_missing
copy_changed
remove_stale
write_manifest
chmod +x "$dst/clm"
clm_text install.sh.copied "scripts copied to {0}" "$dst"
write_version

case ":$PATH:" in
  *":$dst:"*) ;;
  *)
    clm_text install.sh.pathMissing "{0} is not in the PATH. Add this line to ~/.profile, ~/.bashrc or ~/.zshrc:" "$dst"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac

if ! command -v claude >/dev/null 2>&1 && [ ! -x "$dst/claude" ]; then
  clm_text install.sh.noClaude "Claude Code not found: install it first, then run clm again"
fi
if [ "$(uname)" = "Linux" ] && ! command -v bsdtar >/dev/null 2>&1; then
  clm_text install.sh.noBsdtar "bsdtar is missing: backups will be .tar.gz files, and a .zip coming from Windows cannot be restored (libarchive-tools package)"
fi
pwsh_bin=${CLM_PWSH:-pwsh}
if ! command -v "$pwsh_bin" >/dev/null 2>&1; then
  clm_text install.sh.noPwsh "pwsh not found: install PowerShell 7 (see INSTALL.md), then run this script again for the status bar hook"
  exit 1
fi
"$pwsh_bin" -NoProfile -File "$src/install-hook.ps1"
clm_text install.sh.done "done, run clm"
