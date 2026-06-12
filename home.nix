{ config, pkgs, username, homeDirectory, ... }:
{
  # username/homeDirectory are supplied per-machine by the flake's mkHome.
  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    ripgrep
    fd
    emacs-macport
    metals          # Scala LSP server (Metals)
    curl            # >= 8.9, required by gptel's Bedrock SigV4 signing (macOS ships 8.7)
    pandoc          # GFM -> HTML for markdown-mode preview (see lisp/markup.el)
    # Prebuilt tree-sitter grammars (json, yaml, toml, scala, bash, ...), named
    # libtree-sitter-LANG.dylib as Emacs expects. Lands in ~/.nix-profile/lib;
    # projects.el adds that to treesit-extra-load-path. Reproducible: no
    # per-machine runtime grammar installs / prompts (replaces that backlog item).
    emacs.pkgs.treesit-grammars.with-all-grammars
  ];

  # Symlink the plain-Elisp config into place. Nix never generates this;
  # it points ~/.config/emacs at the repo's emacs/ tree.
  xdg.configFile."emacs" = {
    source = ./emacs;
    recursive = true;
  };
}
