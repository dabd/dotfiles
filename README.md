# dabd dotfiles

Vanilla Emacs + tooling, managed by Nix home-manager. Reproducible across
machines (macOS and, in principle, Linux). The Emacs config is plain Elisp, so
it works even cloned without Nix. Nix pins the binary, language servers, and CLI
tools for reproducibility.

## Layout

```
flake.nix / flake.lock   pinned inputs: nixpkgs, home-manager, emacs-overlay
home.nix                 packages and the config symlink
emacs/
  early-init.el          pre-frame tuning + Nix exec-path for GUI .app launches
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

## Launching Emacs (macOS)

Launch the **GUI via the `.app` bundle** so the window gets proper macOS keyboard
focus (Launch Services). Running the bare binary or a launchd-daemon GUI frame
does *not* receive focus: the window appears but keystrokes leak to the
terminal (a known macOS activation-policy behavior, worse on macOS 15.x). So:

```bash
open -a ~/.nix-profile/Applications/Emacs.app   # GUI (primary use)
emacs -nw                                       # quick terminal Emacs
```

Convenience shell functions (add to `~/.zshrc`, which is machine-local):

```bash
ec() { open -a "$HOME/.nix-profile/Applications/Emacs.app" "$@"; }  # GUI, optional files
et() { "$HOME/.nix-profile/bin/emacs" -nw "$@"; }                   # terminal frame
```

> No Emacs daemon is used. The `emacs-macport` daemon under launchd cannot serve
> a focus-correct GUI frame on macOS, so this setup launches the GUI app directly
> instead (it starts fast). `early-init.el` adds the Nix profile to `exec-path`,
> so the app finds `metals`/`rg`/`curl` even though a GUI app doesn't inherit the
> shell PATH.

## Machine-local files (NOT in this repo)

Two files hold per-machine or work-specific configuration. They live **outside**
this repo, are **never committed**, and are created by hand once per machine.
`~/.config/emacs` is fully Nix-owned (read-only store symlinks), so these live in
`~/.config/emacs-local/` instead. Both are loaded with a NOERROR guard, so a
machine without them still starts cleanly.

### `~/.config/emacs-local/local.el`: enterprise git/forge hosts

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

### `~/.config/emacs-local/llm-local.el`: gptel backend

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

Bedrock auth uses the AWS profile (SigV4), no API key. It needs a valid AWS
session (e.g. `aws sso login`) and curl >= 8.9 (provided by `home.nix`; macOS
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
treesit-auto prompts to install the Scala tree-sitter grammar; accept it.
Metals downloads and indexes its build server on first attach, so the first
connection in a project is slow. Add more languages by adding the server to
`home.nix` and a `-ts-mode` hook in `lsp.el`.

## Naming note: `projects.el`

The module is `projects.el` providing feature `projects` (not `project`). Emacs
has a built-in `project` feature; a `lisp/project.el` that also configures the
built-in causes a recursive-`require` clash at startup. The rename avoids it;
the module still configures the built-in `project` package internally.

## macOS GUI escape hatch

The normal GUI entry point is the app bundle (see "Launching Emacs" above). A
bare `emacs &` may start without a window, and a launchd-daemon GUI frame doesn't
get keyboard focus:

```bash
open -a ~/.nix-profile/Applications/Emacs.app
```

If an `emacs-macport` build ever breaks on a new macOS release, temporarily
install the Homebrew cask (`brew install --cask emacs-app`) and put
`/opt/homebrew/bin` ahead of the Nix profile on PATH until the overlay catches up.

## Work / personal git

`~/.gitconfig` (machine-local, not in this repo) routes identity by directory via
`includeIf`. Magit inherits this by shelling out to `git`, so Emacs needs no
identity config. Enterprise hosts and work emails stay out of this repo.
