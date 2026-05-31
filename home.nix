{ pkgs, ... }:
{
  home.username = "<your-whoami>";
  home.homeDirectory = "/Users/<your-whoami>";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    ripgrep
    fd
  ];
}
