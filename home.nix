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
    # withMailutils=false: nothing in emacs/ uses rmail/movemail, and mailutils
    # 3.21 fails to link on aarch64-darwin in current unstable (libmu_sieve).
    (emacs-macport.override { withMailutils = false; })
    metals          # Scala LSP server (Metals)
    curl            # >= 8.9, required by gptel's Bedrock SigV4 signing (macOS ships 8.7)
    pandoc          # GFM -> HTML for markdown-mode preview (see lisp/markup.el)
    # Prebuilt tree-sitter grammars (json, yaml, toml, scala, bash, ...), named
    # libtree-sitter-LANG.dylib as Emacs expects. Lands in ~/.nix-profile/lib;
    # projects.el adds that to treesit-extra-load-path. Reproducible: no
    # per-machine runtime grammar installs / prompts (replaces that backlog item).
    emacs.pkgs.treesit-grammars.with-all-grammars
    tmux            # was the Homebrew binary; Nix-pinned. Retire Homebrew tmux in Phase 2.
                    # Keep the pin fresh: 3.6a's grid corruption crashed the server
                    # 2026-08-03 (tmux/tmux#5302); bin/rig-update-check watches the gap.
    fzf             # required by the tmux MRU pickers; also revives the tmux-fzf plugin (inert until now)
  ];

  # Symlink the plain-Elisp config into place. Nix never generates this;
  # it points ~/.config/emacs at the repo's emacs/ tree.
  xdg.configFile."emacs" = {
    source = ./emacs;
    recursive = true;
  };

  # Symlink the tmux config + pickers. Nix never generates these; same pattern
  # as emacs/ above. Plugins stay TPM-managed (cloned at runtime), the analog
  # of elpaca for Elisp.
  xdg.configFile."tmux/tmux.conf".source = ./tmux/tmux.conf;
  xdg.configFile."tmux/scripts" = {
    source = ./tmux/scripts;
    recursive = true;
  };

  xdg.configFile."ghostty" = {
    source = ./ghostty;
    recursive = true;
  };

  xdg.configFile."zsh/zshrc.core".source = ./zsh/zshrc.core;

  xdg.configFile."git/gitconfig-core".source = ./git/gitconfig-core;
  xdg.configFile."git/gitconfig-dirs".source = ./git/gitconfig-dirs;

  # Weekly git-aware janitor for the agents/ work roots (bin/agents-gc).
  # Replaces relying on macOS tmp_cleaner, which blindly ate multi-day /tmp
  # checkouts (2026-07-31). Report-only: add "--apply" to ProgramArguments
  # once a report has been eyeballed. Work machines add their own root via
  # a roots.d drop-in from their overlay's install script.
  xdg.configFile."agents-gc/roots.d/00-mystuff".text =
    "${homeDirectory}/projects/mystuff/agents\n";
  launchd.agents.agents-gc = {
    enable = true;
    config = {
      ProgramArguments = [ "${homeDirectory}/bin/agents-gc" ];
      StartCalendarInterval = [ { Weekday = 1; Hour = 9; Minute = 0; } ];
      StandardOutPath = "${homeDirectory}/Library/Logs/agents-gc.log";
      StandardErrorPath = "${homeDirectory}/Library/Logs/agents-gc.log";
    };
  };

  # Weekly report-only staleness check on the flake pins (bin/rig-update-check).
  # Born 2026-08-03: the nixpkgs pin sat ten weeks behind while upstream fixed
  # the tmux grid-corruption crash that killed the server and three sessions.
  launchd.agents.rig-update-check = {
    enable = true;
    config = {
      ProgramArguments = [ "${homeDirectory}/bin/rig-update-check" ];
      StartCalendarInterval = [ { Weekday = 1; Hour = 9; Minute = 15; } ];
      StandardOutPath = "${homeDirectory}/Library/Logs/rig-update-check.log";
      StandardErrorPath = "${homeDirectory}/Library/Logs/rig-update-check.log";
    };
  };

  # Agent CLIs rewrite these at runtime (model saves, hook edits), so they must
  # stay writable: out-of-store symlinks into the repo working copy. Requires
  # the repo at ~/rig and --impure (both already required).
  home.file = let
    repoFile = path: config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/rig/${path}";
  in {
    ".claude-personal/CLAUDE.md".source = repoFile "claude/CLAUDE.md";
    ".claude-personal/settings.json".source = repoFile "claude/settings.json";
    ".claude-personal/statusline.sh".source = repoFile "claude/statusline.sh";
    ".claude-personal/hooks".source = repoFile "claude/hooks";
    ".claude-shared/prose-rules.md".source = repoFile "claude-shared/prose-rules.md";
    ".claude-personal/skills".source = repoFile "claude-shared/skills";
    ".codex-personal/AGENTS.md".source = repoFile "codex/AGENTS.md";
    ".codex-personal/config.toml".source = repoFile "codex/config.toml";
    ".codex-personal/hooks.json".source = repoFile "codex/hooks.json";
    ".codex-personal/skills".source = repoFile "codex/skills";
    ".gitconfig-personal".source = ./git/gitconfig-personal;
    "bin/agents-gc" = { source = ./bin/agents-gc; executable = true; };
    "bin/rig-update-check" = { source = ./bin/rig-update-check; executable = true; };
  };
}
