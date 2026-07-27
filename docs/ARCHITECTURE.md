# Architecture

How this repo, its satellites, and the private work overlay compose into one
machine setup. The core repo is public-safe; anything employer-specific lives
in a separate private overlay repo that is present only on work machines and
always wins by loading last.

```mermaid
flowchart TB
    subgraph core["~/rig (this repo, public-bound)"]
        flake["flake.nix + home.nix<br/>Emacs, CLI tools, language servers"]
        emacs["emacs/<br/>init.el, lisp/*.el"]
        zshcore["zsh/zshrc.core"]
        gitcore["git/gitconfig-core + fragments"]
        claudeshared["claude-shared/<br/>prose-rules, shared skills"]
        bootstrap["bootstrap.sh"]
    end

    subgraph tools["~/tools (satellites, cloned by bootstrap.sh)"]
        csetup["claude-setup<br/>agent profile base: CLAUDE.md,<br/>guard hooks, safety-net, bootstrap"]
        sos["save-our-sessions<br/>tmux session recovery"]
        tacit["tacit<br/>prose plugin"]
    end

    subgraph overlay["work overlay repo (private, work machines only)"]
        zshwork["zshrc.work"]
        gitwork["git/gitconfig-work + identities"]
        claudework["claude-work/<br/>CLAUDE.md, rules, brief supplement"]
        installsh["install.sh (idempotent symlinker)"]
    end

    subgraph home["installed surfaces in $HOME"]
        zshrc["~/.zshrc stub"]
        gitconfig["~/.gitconfig stub"]
        cfgemacs["~/.config/emacs (store symlinks)"]
        personalprofile["~/.claude-personal<br/>personal agent profile"]
        workprofile["~/.claude<br/>work agent profile"]
    end

    bootstrap -->|clones| tools
    flake -->|home-manager switch| cfgemacs
    flake -->|home-manager switch| zshrc
    zshrc -->|sources first| zshcore
    zshrc -->|sources last, wins| zshwork
    gitconfig -->|includes| gitcore
    gitconfig -->|includes, wins| gitwork
    csetup -->|bootstrap.sh| personalprofile
    csetup -->|bootstrap.sh, base layer| workprofile
    installsh -->|symlinks on top| workprofile
    claudework --> installsh
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
