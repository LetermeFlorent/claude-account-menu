#!/bin/sh
set -e
src=$(cd "$(dirname "$0")" && pwd)
dst="$HOME/.local/bin"
mkdir -p "$dst"
cp "$src"/bin/*.ps1 "$src/bin/clm" "$dst/"
chmod +x "$dst/clm"
echo "scripts copies dans $dst"

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
if ! command -v pwsh >/dev/null 2>&1; then
  echo "pwsh introuvable : installe PowerShell 7 (voir INSTALL.md), puis relance ce script pour le hook de la barre d'etat"
  exit 1
fi
pwsh -NoProfile -File "$src/install-hook.ps1" -HookCommand "pwsh -NoProfile -File \"$dst/claude-statusline-seed.ps1\""
echo "termine, lance clm"
