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
  ];

  # Symlink the plain-Elisp config into place. Nix never generates this;
  # it points ~/.config/emacs at the repo's emacs/ tree.
  xdg.configFile."emacs" = {
    source = ./emacs;
    recursive = true;
  };
}
