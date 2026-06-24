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
      # `username' feeds home.username; the home directory derives from the OS,
      # so the same config works on macOS and Linux.
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
      # One machine-agnostic entry. The username and system are read from the
      # environment at switch time, so no per-machine login is ever committed.
      # That makes evaluation impure, hence the --impure flag:
      #   home-manager switch --flake .#default --impure
      # flake.lock still pins the toolchain, so what gets installed stays
      # reproducible; only the per-machine username/system are left impure.
      homeConfigurations.default = mkHome {
        system   = builtins.currentSystem;
        username = builtins.getEnv "USER";
      };
    };
}
