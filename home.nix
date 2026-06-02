{ config, pkgs, ... }:
{
  home.username = "<your-whoami>";
  home.homeDirectory = "/Users/<your-whoami>";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    ripgrep
    fd
    emacs-macport
    metals          # Scala LSP server (Metals)
    curl            # >= 8.9, required by gptel's Bedrock SigV4 signing (macOS ships 8.7)
  ];

  # Symlink the plain-Elisp config into place. Nix never generates this;
  # it points ~/.config/emacs at the repo's emacs/ tree.
  xdg.configFile."emacs" = {
    source = ./emacs;
    recursive = true;
  };
}
