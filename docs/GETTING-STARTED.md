# Getting Started & Soak-Driving This Emacs

A practical guide to start using this Emacs setup day-to-day and to "soak-drive"
it (use it as your primary editor for a while) before publishing the repo and
retiring any old config.

---

## 0. One-time checks before you start

Everything is built and verified except two things that need live external
services. Confirm these once so you trust the setup.

### A. Launch it

The editor runs as a launchd-managed daemon. Don't run `emacs` directly — attach:

```bash
emacsclient -c
```

- If it errors with "can't find socket" (can happen right after a fresh login),
  run `emacs --daemon` once, or launch the app bundle:
  `open ~/.nix-profile/Applications/Emacs.app`.
- You should see the dark modus-vivendi theme, line numbers, and a modeline.

### B. Confirm the language server (Scala / Metals)

Open a real Scala project (one with `build.sbt`):

```bash
emacsclient -c ~/projects/<some-scala-repo>/.../Foo.scala
```

- First time: it prompts to install the Scala tree-sitter grammar — say yes.
- The modeline shows `eglot` once Metals connects. **The first connect is slow**
  (minutes): Metals downloads and indexes the build. Subsequent opens are fast.
- Then test: point on a symbol and try `M-.` (definition), `M-?` (references),
  `C-c r` (rename), `C-c C-a` (code actions).

### C. Confirm the LLM (gptel → AWS Bedrock)

Make sure your AWS session is live first:

```bash
aws sso login    # or however you authenticate your Bedrock profile
```

Then in Emacs: `C-c g` → type a question → `C-c RET` to send. You should get a
streamed Claude reply. (Credential errors usually mean the AWS session expired —
re-run the login.)

If A, B, and C work, the setup is fully proven on your machine.

---

## 1. Daily launch habit

The editor is a persistent daemon — attach to it instead of starting new Emacsen:

| Command | Use |
|---|---|
| `emacsclient -c` | New GUI frame (main use) |
| `emacsclient -t` | Terminal frame (inside tmux / over ssh) |
| `emacsclient <file>` | Open a file in the running daemon |

`EDITOR`/`VISUAL` point at emacsclient, so `git commit`, `kubectl edit`, etc.
open in the daemon automatically.

- Close a frame: `C-x 5 0` (the daemon keeps running — fast next open).
- Restart the daemon after a config change:
  `launchctl kickstart -k "gui/$(id -u)/org.nix-community.home.emacs"`

---

## 2. Keybinding cheat sheet (what this config actually sets)

**Most important key:** press `C-x` (or `C-c`) and wait ~0.3s — **which-key**
pops up showing every follow-on key. When unsure, pause and read.

### Finding things (vertico + consult)

| Key | Action |
|---|---|
| `M-x` | Run any command (fuzzy; orderless matches partial words) |
| `C-x C-f` | Open file (fuzzy path matching) |
| `C-x b` | Switch buffer (consult) |
| `C-s` | Search in buffer (consult-line) |
| `M-y` | Paste from kill-ring history |
| _typing_ | in-buffer completion popup appears automatically (corfu) |

### Editing (IntelliJ-flavored)

| Key | Action |
|---|---|
| `C-c d` | Duplicate line (IntelliJ Cmd-D) |
| `C->` | Add cursor at next occurrence (multiple-cursors) |
| `C-<` | Add cursor at previous occurrence |
| `C-c C-<` | Add cursors at all occurrences |
| `C-=` | Expand selection by semantic region |

### Projects & code

| Key | Action |
|---|---|
| `C-x p f` | Find file in project |
| `C-x p g` | Grep across project (ripgrep) |
| `C-x p p` | Switch project |
| `M-.` / `M-?` | Go to definition / find references |
| `C-c r` / `C-c C-a` | Rename symbol / code actions |

### Git (magit)

| Key | Action |
|---|---|
| `C-x g` | Magit status |

Inside magit: `s` stage, `u` unstage, `c c` commit, `P p` push, `F p` pull,
`b b` switch branch, `?` help.

### AI (gptel)

| Key | Action |
|---|---|
| `C-c g` | Open/switch to a Claude chat buffer |
| `C-c RET` | Send the prompt / selected region |

### Survival keys (vanilla Emacs)

`C-g` cancel anything · `C-x C-s` save · `C-/` undo · `C-x 5 0` close frame
(use this, not `C-x C-c`, which would kill the daemon) · `C-h k <key>` describe a
key · `C-h f <fn>` describe a function.

---

## 3. Soak-drive plan

The point of soaking is to discover what's missing for *your* workflow before you
publish and before you delete any old config.

**Week 1 — force yourself onto it.** Use `emacsclient -c` for real work. Keep
which-key on (it is). Expect friction — note it, don't fix it mid-flow.

**Keep a friction log.** When something annoys you ("I reach for X and it's not
there"), jot it down instead of yak-shaving. Common additions after soaking a
lean config like this (all deferred-backlog — add later, one module at a time):

- snippets (yasnippet / tempel), format-on-save, diagnostics surfacing,
  `avy` for jumping, a richer modeline, `embark` for actions on candidates.

**Stress-test the two things most likely to bite:**

- **Metals on a second, differently-structured Scala project** — confirm it
  indexes and `M-.` works there too.
- **gptel when the AWS session lapses** — you'll hit this naturally; confirm the
  failure is obvious and `aws sso login` fixes it. If it's annoying, that's a
  signal to script the login.

**"Soak passed" looks like:** several days where you didn't reach for the old
setup, both gates work reliably, and the friction log has cooled off. Then
publish + retire the old config.

---

## 4. Editing the config (the dev loop)

### Elisp tweaks (most changes)

Edit a file in `~/dotfiles/emacs/lisp/`, then:

```bash
cd ~/dotfiles && home-manager switch --flake .#"$(whoami)"          # update the store symlink
launchctl kickstart -k "gui/$(id -u)/org.nix-community.home.emacs"  # restart the daemon
```

`~/.config/emacs` is Nix-managed symlinks, so editing the repo file is not live
until you `switch`. (For a quick in-session try you can `M-x eval-buffer`, but
commit + switch is the real path.)

### Tools / packages (Nix)

Edit `~/dotfiles/home.nix` to add a CLI tool or language server →
`home-manager switch`. For a new Elisp package, add the `use-package` form,
`switch`, then let elpaca install it on next launch (or `M-x elpaca-process-queues`).

Commit tweaks as you go (`git -C ~/dotfiles commit`) — that's what keeps the
setup reproducible.

---

## 5. Machine-local files (per machine, never committed)

Work-specific and backend config lives outside the repo in `~/.config/emacs-local/`:

- `local.el` — enterprise forge hosts (Magit/Forge).
- `llm-local.el` — the gptel backend (e.g. AWS Bedrock with your AWS profile).

On a new machine, recreate these by hand (templates are in the README). The
committed config loads them with a NOERROR guard, so a machine without them still
starts cleanly.

---

## 6. Escape hatches (so you're never stuck)

- **Roll back to the old config entirely:**
  `mv ~/.emacs.d.prelude-backup ~/.emacs.d` — the Nix Emacs is independent, so the
  old config returns instantly. (Don't delete the backup until you're confident.)
- **GUI won't open from the terminal:** `open ~/.nix-profile/Applications/Emacs.app`.
- **emacs-macport breaks on a macOS update:** temporarily
  `brew install --cask emacs-app` and put `/opt/homebrew/bin` ahead on PATH until
  the overlay catches up.
- **Config error on startup:** `emacs -Q` launches with zero config to fix things;
  check `*Messages*` / `*Warnings*` in the running daemon.
- **A package misbehaves:** `M-x elpaca-log` shows build status;
  `M-x elpaca-rebuild` rebuilds one.

---

## 7. When the soak passes

1. Re-run the pre-publish audit and push (see the plan's Task 13 Step 3).
2. After several days as your daily driver with no need to roll back:
   `rm -rf ~/.emacs.d.prelude-backup`.
