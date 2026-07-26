#!/usr/bin/env bash
# Fresh-machine setup. Idempotent: safe to re-run; never overwrites stubs.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
if [ "$repo" != "$HOME/dotfiles" ]; then
  echo "error: repo must live at ~/dotfiles (out-of-store symlinks depend on it), found $repo" >&2
  exit 1
fi

command -v nix >/dev/null 2>&1 || {
  echo "error: install nix first (https://nixos.org/download), then re-run" >&2
  exit 1
}

# Stubs: create once, never overwrite (installers append to the real files).
[ -f "$HOME/.zshrc" ] || cp "$repo/zsh/zshrc.stub" "$HOME/.zshrc"
[ -f "$HOME/.gitconfig" ] || cp "$repo/git/gitconfig.stub" "$HOME/.gitconfig"

# Satellite tools at a stable path.
mkdir -p "$HOME/tools"
[ -d "$HOME/tools/save-our-sessions" ] || git clone git@github.com:dabd/save-our-sessions.git "$HOME/tools/save-our-sessions"
[ -d "$HOME/tools/claude-setup" ] || git clone git@github.com:dabd/claude-setup.git "$HOME/tools/claude-setup"
[ -d "$HOME/tools/tacit" ] || git clone git@github.com:dabd/tacit.git "$HOME/tools/tacit"

# oh-my-zsh + the two custom plugins zshrc.core expects.
[ -d "$HOME/.oh-my-zsh" ] || sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
zsh_custom="$HOME/.oh-my-zsh/custom"
[ -d "$zsh_custom/plugins/zsh-autosuggestions" ] || git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions"
[ -d "$zsh_custom/plugins/zsh-syntax-highlighting" ] || git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$zsh_custom/plugins/zsh-syntax-highlighting"

if command -v home-manager >/dev/null 2>&1; then
  home-manager switch --flake "$HOME/dotfiles#default" --impure
else
  nix run home-manager/master -- switch --flake "$HOME/dotfiles#default" --impure
fi

echo "done. work machines: clone the work overlay repo and run its install.sh."
