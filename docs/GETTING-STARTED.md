# Getting Started & Soak-Driving This Emacs

A practical guide to start using this Emacs setup day-to-day and to "soak-drive"
it (use it as your primary editor for a while) before publishing the repo and
retiring any old config.

---

## 0. One-time checks before you start

Everything is built and verified except two things that need live external
services. Confirm these once so you trust the setup.

### A. Launch it

Launch the GUI via the macOS app bundle (Launch Services) so the window gets
proper keyboard focus:

```bash
open -a ~/.nix-profile/Applications/Emacs.app
```

- You should see the dark modus-vivendi theme, line numbers, and a modeline, and
  be able to type in the window.
- Do NOT launch with a bare `emacs &` or via a launchd daemon: on macOS the
  window appears but doesn't receive keyboard focus (keystrokes leak to the
  terminal). The `.app` bundle avoids this. See §6.
- A quick terminal Emacs (no window) is `emacs -nw`.

### B. Confirm the language server (Scala / Metals)

Open a real Scala project (one with `build.sbt`):

```bash
open -a ~/.nix-profile/Applications/Emacs.app ~/projects/<some-scala-repo>/.../Foo.scala
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

Launch the GUI via the `.app` bundle (Launch Services) so it gets keyboard focus.
Add these helpers to `~/.zshrc` (machine-local, not in this repo):

```bash
ec() { open -a "$HOME/.nix-profile/Applications/Emacs.app" "$@"; }  # GUI, optional files
et() { "$HOME/.nix-profile/bin/emacs" -nw "$@"; }                   # terminal Emacs
```

| Command | Use |
|---|---|
| `ec` | Open the GUI (main use) |
| `ec file…` | Open files in the GUI |
| `et` | Quick terminal Emacs (inside tmux / over ssh) |

- No daemon is used (the macport daemon can't serve a focus-correct GUI frame on
  macOS — see §6). The `.app` starts fast.
- Quit with `C-x C-c`, or close a frame with `C-x 5 0`.
- To set Emacs as `EDITOR`, point it at a terminal Emacs in `~/.zshrc`:
  `export EDITOR='emacs -nw'` (or `export EDITOR=ec` if you prefer a GUI editor).

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

`C-g` cancel anything · `C-x C-s` save · `C-/` undo · `C-x C-c` quit Emacs ·
`C-x 5 0` close one frame · `C-h k <key>` describe a key · `C-h f <fn>` describe
a function.

---

## 3. Soak-drive plan

The point of soaking is to discover what's missing for *your* workflow before you
publish and before you delete any old config.

**Week 1 — force yourself onto it.** Use `ec` (the GUI app) for real work. Keep
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

You run `switch` only when you change the config or tooling. Daily editing
needs none of it: launch with `ec` and go.

### Elisp tweaks (most changes)

Edit a file in `~/dotfiles/emacs/lisp/`, then:

```bash
cd ~/dotfiles && home-manager switch --flake .#default --impure   # update the store symlink
# then quit Emacs (C-x C-c) and relaunch: `ec`
```

`~/.config/emacs` is Nix-managed symlinks, so editing the repo file is not live
until you `switch` and restart Emacs. (For a quick in-session try you can
`M-x eval-buffer`, but commit + switch + relaunch is the real path.)

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
- **GUI window has no keyboard focus (keystrokes go to the terminal):** launch
  via the `.app` (`open -a ~/.nix-profile/Applications/Emacs.app` / `ec`), not a
  bare `emacs &` or a launchd daemon — Launch Services is what grants focus.
- **emacs-macport breaks on a macOS update:** temporarily
  `brew install --cask emacs-app` and put `/opt/homebrew/bin` ahead on PATH until
  the overlay catches up.
- **Config error on startup:** `emacs -Q -nw` launches with zero config to fix
  things; check `*Messages*` / `*Warnings*` in the running Emacs.
- **A package misbehaves:** `M-x elpaca-log` shows build status;
  `M-x elpaca-rebuild` rebuilds one.

---

## 7. When the soak passes

1. Re-run the pre-publish audit and push (see the plan's Task 13 Step 3).
2. After several days as your daily driver with no need to roll back:
   `rm -rf ~/.emacs.d.prelude-backup`.
