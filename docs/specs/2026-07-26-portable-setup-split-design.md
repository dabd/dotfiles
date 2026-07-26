# Portable Setup Split: Public Core + Work Overlay

**Date:** 2026-07-26
**Status:** Approved

## Goal

Consolidate the remaining loose `$HOME` configuration (zsh, tmux, ghostty, git,
Claude/Codex profile config) into this repo, managed by home-manager where that
fits, without leaking any work-specific configuration into this public repo.
Work-specific fragments move to a separate overlay repo on the employer-side
git host; the core works with or without the overlay present.

## Repo topology

- **This repo (core, public):** everything portable and personal-safe. Nix
  flake, emacs (existing), tmux (per the 2026-06-26 port plan), ghostty, zsh
  core, git core, personal Claude/Codex config.
- **Work overlay repo (employer git host, private):** plain files plus an
  idempotent `install.sh` that symlinks them to fixed paths in `$HOME`
  (`~/.zshrc.work`, `~/.gitconfig-work`, work agent config). No Nix on the
  work side. Deleting the repo and its symlinks removes every trace of work
  config.
- **Satellites stay standalone repos:** `save-our-sessions` (tmux session
  recovery) and `claude-setup` (safety-net hooks). Bootstrap clones both to
  `~/tools/`; the `sos` alias and the tmux resurrect hook reference
  `~/tools/save-our-sessions/...` instead of a projects directory.
  `claude-setup`'s canonical home becomes the personal GitHub account (the
  local copy is ahead of any other copy and currently has no remote).

## The stub pattern (zsh and git)

`~/.zshrc` and `~/.gitconfig` must stay loose, writable files because
third-party installers append to them directly (container tooling blocks,
credential-helper hook lines). Neither is symlinked. Instead:

- `~/.zshrc` becomes a stub, created once by bootstrap:
  1. `source ~/.config/zsh/zshrc.core` (symlinked by home-manager from
     `zsh/zshrc.core` in this repo)
  2. `[ -f ~/.zshrc.work ] && source ~/.zshrc.work`
  Anything tools append later lands harmlessly below.
- `~/.gitconfig` becomes a stub with two `[include]` paths:
  `~/.config/git/gitconfig-core` then `~/.gitconfig-work`. Git ignores
  missing include paths, so the same stub works on machines without the
  overlay.

Ordering does the work/personal switching: the work file loads last, so on a
work machine its function and identity definitions win (for example a `claude`
wrapper routed to an employer-provided model endpoint, or the employer git
identity as default). On a personal machine those files are absent and the
core's personal defaults apply.

Content split:

- **zsh core:** oh-my-zsh setup, nix daemon sourcing, version managers
  (pyenv, sdkman, nvm, tgenv), generic PATH entries, history settings,
  terraform plugin cache, `tmux_extract_window`, the personal AI CLI wrappers
  (`claude-personal`, `claude-kimi`, `codex-personal`, `_codex_real`), `sos`,
  `ec`/`et` emacs launchers, `bcode` wrapper.
- **zsh work overlay:** the work `claude()` wrapper, internal CLI bundle PATH
  and completions, internal credential-helper sourcing, internal tool
  functions and PATH entries.
- **left in the stub:** blocks owned and rewritten by their installers.
- **git core:** aliases, `pull.rebase`, personal identity as default,
  includeIf blocks for personal project directories.
- **git work overlay:** employer identity override, host URL rewrites for
  internal git hosts, includeIf blocks for work project directories.

The concrete line-by-line assignment of the current live files (with internal
names) lives in a companion inventory outside this repo; it seeds the overlay
repo's initial commit.

## home-manager mechanics

Existing pattern, unchanged, for emacs, tmux, ghostty: binaries in
`home.packages`, hand-written config symlinked via `xdg.configFile`, plugins
on runtime managers (TPM, elpaca; bootstrap installs oh-my-zsh if missing).
The tmux port follows its own committed plan
(`docs/superpowers/plans/2026-06-26-tmux-port.md`) verbatim, including the
deferred user-triggered server cutover.

New mechanism for agent-CLI config only: Claude Code rewrites its
`settings.json` at runtime, so a read-only nix-store symlink would break it.
These files use `config.lib.file.mkOutOfStoreSymlink` pointing at the repo
working copy: writable through the symlink, and runtime changes surface as a
dirty git diff to review, commit, or discard. This requires the repo at a
fixed path (`~/dotfiles`), which bootstrap enforces; the flake already
requires `--impure`.

Tracked file-by-file, never whole-dir (these directories mix config with
machine state):

- `claude/` -> `~/.claude-personal/`: `CLAUDE.md`, `settings.json`,
  `statusline.sh`, `hooks/`, `skills/`. Never tracked: `memory/`,
  `projects/`, `sessions/`, caches, history, backups.
- `claude-shared/` -> `~/.claude-shared/`: `prose-rules.md`.
- `codex/` -> `~/.codex-personal/`: `config.toml`, `hooks.json`. Never:
  `auth.json`, sqlite state, history, logs.
- Work agent config (`~/.claude` profile: its `CLAUDE.md`, rules, settings)
  belongs to the overlay repo, symlinked by its `install.sh`.

Publication gate: before any of these files land in this public repo, review
them for client names, internal hostnames, and personal details; sanitize or
leave untracked anything borderline. Secrets are already externalized (API
keys resolve via a password-manager CLI at call time).

## Bootstrap

`bootstrap.sh` at the repo root, idempotent, fresh-machine order:

1. Preconditions: nix installed, repo cloned at `~/dotfiles`.
2. Create the `~/.zshrc` and `~/.gitconfig` stubs if missing (never
   overwrite existing ones).
3. Clone satellites to `~/tools/` if absent.
4. Install oh-my-zsh if absent.
5. `home-manager switch --flake ~/dotfiles#default --impure`.
6. Work machines only, manual: clone the overlay repo, run its `install.sh`.

## Migration order (live machine)

Ordered by risk; each step verified before the next:

1. tmux port Phase 1 staging plus ghostty (touches nothing live).
2. zsh split; verify in a fresh shell before closing existing ones.
3. git split; verify `git config user.email` resolves correctly from a work
   project dir, a personal project dir, and the scratch-clone paths.
4. Claude/Codex symlinks, with timestamped backups of every replaced file.
5. Push `claude-setup` to personal GitHub; move satellite clones to
   `~/tools/` and repoint the `sos` alias and resurrect hook.
6. tmux Phase 2 cutover: deferred, user-triggered only (it strands the
   running tmux server and every agent session in it).

## Error handling

- Stub sourcing is guarded (`[ -f ... ]`); git includes skip missing files
  natively. A machine with core only, or core plus overlay, both work.
- Bootstrap is re-runnable; it never overwrites an existing stub or clone.
- Out-of-store symlinks fail loudly if the repo is not at `~/dotfiles`;
  bootstrap checks the path up front.

## Testing

- `home-manager build` (dry) before every `switch`.
- Fresh interactive shell after the zsh split: omz loads, wrappers resolve,
  work functions defined only when the overlay is installed.
- `git config user.email` spot checks per directory class.
- After the Claude/Codex symlink step: launch each profile, change a setting,
  confirm the change lands in the repo working copy as a diff.

## Out of scope

- Absorbing the satellite repos into this repo.
- Managing work-host tooling from this repo in any form.
- The tmux server cutover itself (owned by the tmux port plan).
