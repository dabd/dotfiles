# dabd dotfiles

Vanilla Emacs + tooling, managed by Nix home-manager. Reproducible across
machines (macOS and, in principle, Linux). The Emacs config is plain Elisp —
it works even cloned without Nix; Nix just pins the binary, language servers,
and CLI tools for reproducibility.

## Layout

```
flake.nix / flake.lock   pinned inputs: nixpkgs, home-manager, emacs-overlay
home.nix                 packages, the Emacs daemon, and the config symlink
emacs/
  early-init.el          pre-frame tuning + Nix exec-path for daemon/.app launches
  init.el                elpaca bootstrap + module loader
  lisp/
    ui.el                modus-vivendi, which-key, font
    completion.el        vertico + orderless + marginalia + consult + corfu
    editing.el           defaults, multiple-cursors, duplicate-line
    projects.el          project.el, treesit-auto, dired (see naming note below)
    lsp.el               eglot + dape (Scala / Metals)
    git.el               magit + forge (github.com; enterprise hosts loaded locally)
    llm.el               gptel; backend chosen per-machine (work: AWS Bedrock)
```

## Bootstrap a new machine

Requires Nix (with flakes) installed and permitted on the target machine.

```bash
git clone https://github.com/dabd/dotfiles ~/dotfiles
cd ~/dotfiles
nix run home-manager/master -- switch --flake .#"$(whoami)"
```

> The flake's `homeConfigurations` key is the username `<your-whoami>`;
> adjust `flake.nix` (`home.username`/`home.homeDirectory`) for a different
> account. First switch compiles or fetches `emacs-macport` (can be tens of
> minutes if not cached); later switches are fast.

After the first switch, Emacs runs as a launchd-managed daemon. Attach with:

```bash
emacsclient -c     # new GUI frame (primary use)
emacsclient -t     # terminal frame (e.g. inside tmux)
```

`EDITOR`/`VISUAL` are set to emacsclient (`services.emacs.defaultEditor`).

## Machine-local files (NOT in this repo)

Two files hold per-machine or work-specific configuration. They live **outside**
this repo, are **never committed**, and are created by hand once per machine.
`~/.config/emacs` is fully Nix-owned (read-only store symlinks), so these live in
`~/.config/emacs-local/` instead. Both are loaded with a NOERROR guard, so a
machine without them still starts cleanly.

### `~/.config/emacs-local/local.el` — enterprise git/forge hosts

Registers enterprise GitHub hosts with Forge. Kept out of this public repo
because the hostnames are work infrastructure. Example:

```elisp
;;; local.el --- machine-local: enterprise forge hosts -*- lexical-binding: t; -*-
(with-eval-after-load 'forge
  (dolist (h '(("github.example-corp.com" "github.example-corp.com/api/v3"
                "github.example-corp.com" "github.example-corp.com")))
    (add-to-list 'forge-alist h)))
(provide 'local)
```

### `~/.config/emacs-local/llm-local.el` — gptel backend

Selects the LLM backend for this machine. `llm.el` ships no backend, so gptel is
inert until this file provides one. On a work laptop with AWS Bedrock:

```elisp
;;; llm-local.el --- machine-local gptel backend -*- lexical-binding: t; -*-
(with-eval-after-load 'gptel
  (require 'gptel-bedrock)
  (setq gptel-backend
        (gptel-make-bedrock "AWS-Bedrock"
          :region "us-east-1"
          :model-region 'us
          :stream t
          :aws-profile "your-bedrock-profile")
        gptel-model 'claude-sonnet-4-20250514))
(provide 'llm-local)
```

Bedrock auth uses the AWS profile (SigV4) — no API key. It needs a valid AWS
session (e.g. `aws sso login`) and curl ≥ 8.9 (provided by `home.nix`; macOS
ships 8.7). A personal machine could instead point gptel at any other backend
(an API key via auth-source, a local Ollama, etc.).

## Secrets

No secrets are committed. API access is per-machine: work LLM uses AWS Bedrock
via an AWS profile (above); GitHub/Forge tokens resolve through auth-source
(e.g. `~/.authinfo.gpg` or the 1Password `op` CLI), never stored in the repo.

## Language servers

`lsp.el` uses the built-in `eglot`. The primary language is **Scala** via
**Metals** (`metals` is in `home.nix`; `scala-ts-mode` is the major mode, and
eglot is mapped to launch Metals for it). On first open of a `.scala` file,
treesit-auto prompts to install the Scala tree-sitter grammar — accept it.
Metals downloads and indexes its build server on first attach, so the first
connection in a project is slow. Add more languages by adding the server to
`home.nix` and a `-ts-mode` hook in `lsp.el`.

## Naming note: `projects.el`

The module is `projects.el` providing feature `projects` (not `project`). Emacs
has a built-in `project` feature; a `lisp/project.el` that also configures the
built-in causes a recursive-`require` clash at startup. The rename avoids it;
the module still configures the built-in `project` package internally.

## macOS GUI launch / escape hatch

The daemon is the normal entry point (`emacsclient -c`). To launch a standalone
GUI without the daemon, use the app bundle (a bare `emacs &` may start without a
window on macOS):

```bash
open ~/.nix-profile/Applications/Emacs.app
```

If an `emacs-macport` build ever breaks on a new macOS release, temporarily
install the Homebrew cask (`brew install --cask emacs-app`) and put
`/opt/homebrew/bin` ahead of the Nix profile on PATH until the overlay catches up.

## Work / personal git

`~/.gitconfig` (machine-local, not in this repo) routes identity by directory via
`includeIf`. Magit inherits this automatically by shelling out to `git` — no
identity config in Emacs. Enterprise hosts and work emails stay out of this repo.
