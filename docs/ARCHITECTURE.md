# Architecture

How this repo (`rig`), its satellites, and the private work overlay
(`rig-work`) compose into one machine setup. The core repo is public-safe;
anything employer-specific lives in the overlay, which is present only on work
machines and always wins by loading last.

Two views, both flowing top to bottom from source repos to installed surfaces.

## Shell, git and Emacs config

```mermaid
flowchart TB
    subgraph core["~/rig (this repo, public-bound)"]
        flake["flake.nix + home.nix<br/>Emacs, CLI tools, language servers"]
        emacs["emacs/<br/>init.el, lisp/*.el"]
        zshcore["zsh/zshrc.core"]
        gitcore["git/gitconfig-core + fragments"]
    end

    subgraph overlay["rig-work (private overlay, work machines only)"]
        zshwork["zshrc.work"]
        gitwork["git/gitconfig-work + identities"]
    end

    subgraph home["installed surfaces in $HOME"]
        cfgemacs["~/.config/emacs (store symlinks)"]
        zshrc["~/.zshrc stub"]
        gitconfig["~/.gitconfig stub"]
    end

    flake -->|home-manager switch| cfgemacs
    zshcore -->|sourced first| zshrc
    zshwork -->|sourced last, wins| zshrc
    gitcore -->|included first| gitconfig
    gitwork -->|included last, wins| gitconfig
```

## Agent profiles

```mermaid
flowchart TB
    subgraph core2["~/rig (this repo, public-bound)"]
        bootstrap["bootstrap.sh"]
        codexdir["claude/ + codex/<br/>personal agent profiles"]
        claudeshared["claude-shared/<br/>prose-rules, shared skills"]
    end

    subgraph tools["~/tools (satellites)"]
        csetup["claude-setup<br/>agent profile base: CLAUDE.md,<br/>guard hooks, safety-net, bootstrap"]
        sos["save-our-sessions<br/>tmux session recovery"]
        tacit["tacit<br/>prose plugin"]
    end

    subgraph overlay2["rig-work (private overlay, work machines only)"]
        claudework["claude-work/<br/>CLAUDE.md, rules, brief supplement"]
        installsh["install.sh (idempotent symlinker)"]
    end

    subgraph home2["profiles in $HOME"]
        personalprofile["~/.claude-personal + ~/.codex-personal<br/>personal agent profiles"]
        workprofile["~/.claude + ~/.codex<br/>work agent profiles"]
    end

    bootstrap -->|clones| tools
    codexdir -->|home-manager switch| personalprofile
    csetup -->|bootstrap.sh| personalprofile
    csetup -->|bootstrap.sh, base layer| workprofile
    claudework --> installsh
    installsh -->|symlinks on top| workprofile
    claudeshared -->|shared skills| workprofile
```

Layering rules:

- The core repo never contains client names, internal hostnames, or secrets.
  The overlay repo holds all of those and is never public.
- Overlay config always loads after core config, so work settings win on work
  machines and their absence is harmless everywhere else.
- Agent profiles follow the same pattern as the shell: `claude-setup` installs
  the shared base into each profile dir, then the overlay's `install.sh`
  symlinks work-specific instructions and rules on top.
- Machine-local, uncommitted state (Emacs `~/.config/emacs-local/`, secrets in
  1Password) sits outside all three repos.
