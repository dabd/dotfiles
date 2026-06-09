{
  description = "dotfiles - Emacs + tooling via home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, emacs-overlay, ... }:
    let
      # One entry per machine. `username' feeds both the homeConfigurations
      # attr key and home.username; the home directory derives from the OS, so
      # the same config works on macOS and Linux.
      mkHome = { system, username }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ emacs-overlay.overlays.default ];
          };
          extraSpecialArgs = {
            inherit username;
            homeDirectory =
              if nixpkgs.lib.hasSuffix "darwin" system
              then "/Users/${username}"
              else "/home/${username}";
          };
          modules = [ ./home.nix ];
        };
    in {
      homeConfigurations = {
        # Work laptop (Apple Silicon).
        "<your-whoami>" = mkHome {
          system = "aarch64-darwin";
          username = "<your-whoami>";
        };
        # Add a machine: copy the block above with that machine's `whoami'
        # (the attr key + username) and `uname -m' (arm64 -> aarch64-darwin,
        # x86_64 -> x86_64-darwin, Linux -> *-linux).
      };
    };
}
