#!/bin/sh
set -e
src=$(cd "$(dirname "$0")" && pwd)
dst="$HOME/.local/bin"
mkdir -p "$dst"
cp "$src"/bin/*.ps1 "$src/bin/clm" "$dst/"
rm -rf "$dst/clm-web"
cp -R "$src/bin/clm-web" "$dst/clm-web"
chmod +x "$dst/clm"
echo "scripts copies dans $dst"
rm -f "$dst/clm.version"
if command -v git >/dev/null 2>&1 && [ -e "$src/.git" ]; then
  echo "$(git -C "$src" log -1 --format='%H %ct') $(git -C "$src" rev-list --count HEAD)" > "$dst/clm.version" || rm -f "$dst/clm.version"
elif [ -f "$src/clm.version" ]; then
  cp "$src/clm.version" "$dst/clm.version"
fi

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
