# Emacs + Nix home-manager Setup — Design

Date: 2026-05-31
Status: Approved (pending spec review)
Owner: dabd

## Goal

Replace a stock, unconfigured Emacs Prelude install with a from-scratch vanilla
Emacs config, managed reproducibly through Nix home-manager, versioned on
`github.com/dabd/dotfiles`. The setup must transport to another laptop (work or
personal) with minimal effort: `git clone` + `home-manager switch` + `op signin`.

Primary editor going forward, replacing IntelliJ. Ghostty + tmux remain the
outer window manager; Emacs is the inner editor, used whenever advantageous.

## Context (verified on this machine, 2026-05-31)

- Emacs binary: vanilla GNU Emacs 30.2 via Homebrew cask `emacs-app`
  (`/Applications/Emacs.app`). Not Prelude — "Prelude" is only the `~/.emacs.d`
  config directory.
- `~/.emacs.d`: clone of `bbatsov/prelude`, sitting exactly on upstream master,
  `origin` points at bbatsov's repo, `personal/` is essentially empty. No user
  work to preserve beyond the `modus-vivendi` theme choice.
- Nix: 2.32.2, multi-user daemon install (~April 2025, fleet-provisioned),
  flakes already enabled in `~/.config/nix/nix.conf`. No home-manager, no flake,
  no nixpkgs config yet — a bare, unused Nix install.
- Admin rights: yes. MDM: ManageEngine, User Approved (not DEP-locked).
- 1Password CLI (`op`) installed. No `pass`/`gpg`.
- gh authed as `dabd` over SSH.
- Ghostty + tmux 3.5a present.

## Decisions

| Axis | Decision | Rationale |
|---|---|---|
| Foundation | Fresh vanilla config (archive Prelude) | Full ownership, deep learning; no real Prelude work to keep |
| Distro | None — vanilla Emacs 30.2 + use-package | Emacs 30 ships use-package/eglot/treesit/which-key/native-comp in core |
| Keybindings | Vanilla + which-key | What deep-Emacs users run; Evil's value (preserving Vim habits) does not apply to an IntelliJ migrant |
| Elisp packages | elpaca + lockfile | Pins package versions in Elisp without dragging packages into Nix |
| Inline AI | minuet (Anthropic key, shared with gptel) | One key, open source, can swap to local Ollama |
| Chat/rewrite AI | gptel (Anthropic) | De facto anchor; native Claude backend |
| Secrets | 1Password (`op`) at runtime via auth-source shim | Already installed; key never enters repo or Nix store |
| Dotfiles/repro | Nix home-manager flake | User intends to use Nix anyway; reproduces whole environment, not just files |
| Emacs binary source | Nix emacs-overlay `emacs-macport` (pinned) | 100% reproducible, single source of truth |
| git config | Unmanaged by home-manager in v1; Magit inherits it | Do not risk the working `includeIf` identity routing on day one |

## Architecture

One repo, `github.com/dabd/dotfiles`, a Nix flake. Two cleanly separated layers
so the two learning curves (Nix, Emacs) never tangle:

- **Environment layer (Nix):** installs and pins the Emacs binary, CLI tools
  (ripgrep, fd, git, tmux), language servers, fonts. Declared in `home.nix`,
  locked in `flake.lock`.
- **Editor layer (plain Elisp):** `init.el` + `lisp/*.el`. home-manager
  *symlinks* these into `~/.config/emacs/`; Nix never generates Emacs config and
  treats it as an opaque blob. Elisp is hacked in Elisp.

```
~/dotfiles/                      (github.com/dabd/dotfiles)
├── flake.nix                    pins nixpkgs + emacs-overlay + home-manager
├── flake.lock                   the reproducibility anchor
├── home.nix                     packages + symlinks + program config
├── modules/                     optional: split home.nix (shell, git, tmux…)
├── docs/specs/                  this document
└── emacs/
    ├── early-init.el            GUI/startup tuning before frame loads
    ├── init.el                  bootstrap elpaca, load lisp/ modules in order
    └── lisp/
        ├── ui.el                modus-vivendi, fonts, which-key
        ├── completion.el        vertico + orderless + marginalia + consult + corfu
        ├── editing.el           sane defaults, multiple-cursors, IntelliJ-flavored binds
        ├── project.el           project.el + treesit + treesit-auto + dired
        ├── lsp.el               eglot + dape (primary language first)
        ├── git.el               magit + forge (multi-host)
        └── llm.el               gptel + minuet, key via 1Password auth-source shim
```

The `emacs/` tree is a self-contained, distro-free config that works even when
cloned without Nix. Nix wraps it for reproducibility but does not own it — this
is what enables migration, isolated debugging, or abandoning Nix later without
rewriting Elisp.

### Package management inside Emacs

Nix pins the binary and tools; Elisp packages are pinned by **elpaca** with its
lockfile, keeping Elisp concerns in Elisp. Rejected alternative: declaring every
Elisp package in Nix (emacs-overlay), which tangles the layers and pulls config
generation into Nix.

## Nix / home-manager mechanics

`flake.nix` inputs, all pinned: `nixpkgs`, `home-manager`, `emacs-overlay`.
These three locked in `flake.lock` are the entire reproducibility contract.

`home.nix` declares:
1. **Packages** (`home.packages`): `emacs-macport` (overlay) + toolchain
   (ripgrep, fd, git, tmux, language servers, fonts).
2. **Symlinks** (`xdg.configFile`): `~/.config/emacs/` → repo `emacs/` tree.
   Edit-in-repo, changes live immediately.
3. **Program config** (incremental, later): `programs.tmux`/`git`/`zsh`, ghostty
   — added one at a time after the first switch works.

macOS GUI nuance: `emacs-macport` builds a proper GUI app. First
`home-manager switch` compiles Emacs (long, tens of minutes); later switches are
cached. Retire the brew `emacs`/`emacs-app` casks for a single source of truth;
put Nix Emacs ahead on PATH. Escape hatch if a macOS release breaks the macport
GUI build: temporarily fall back to the brew cask while the overlay catches up.

Daemon: home-manager runs Emacs as a launchd-managed daemon (`services.emacs`);
attach with `emacsclient` (GUI frame for real work, `emacsclient -t` from tmux).

New-laptop bootstrap (Nix must be installed and allowed on that machine):
```
git clone https://github.com/dabd/dotfiles ~/dotfiles
nix run home-manager -- switch --flake ~/dotfiles
op signin
```

## Emacs config contents

- **early-init.el:** disable toolbar/scrollbar, raise GC during startup, set
  frame font early.
- **init.el:** bootstrap elpaca, `require` modules in order. Thin orchestration.
- **ui.el:** modus-vivendi theme (carried over), which-key, font, modeline.
- **completion.el:** vertico + orderless + marginalia + consult (live ripgrep) +
  corfu (in-buffer completion).
- **editing.el:** sane defaults (delete-selection, auto-revert, save-place,
  recentf), multiple-cursors (IntelliJ multi-cursor habit), a small set of
  IntelliJ-flavored custom binds (duplicate-line, expand-region).
- **project.el:** built-in project.el (`C-x p f`, `C-x p g`), treesit +
  treesit-auto, dired tweaks. treemacs deferred unless a persistent side panel
  is missed.
- **lsp.el:** eglot (built-in) → find-usages `M-?`, go-to-def `M-.`,
  `eglot-rename`, diagnostics; dape for debugging. Primary language first.
- **git.el:** see below.
- **llm.el:** gptel (chat/rewrite) + minuet (inline), both reading the same
  Anthropic key from 1Password at runtime.

Deferred (YAGNI for v1): aidermacs/agentic coding, treemacs, org config,
per-language deep config.

## Git layer (work + personal)

Existing machine git config (well-built, do not break):
- Directory-conditional identity via `includeIf`:
  - `~/projects/work/**` → `<work-email-enterprise>` (enterprise)
  - `~/projects/work-secondary/**` → `<work-email-secondary>`
  - `~/projects/mystuff/**` → `<personal-email>` (personal)
  - default → `<work-email-default>`
- Four enterprise GitHub hosts with `url.insteadOf` https→SSH rewrites:
  `<enterprise-host-2>`, `<enterprise-host-3>`, `<enterprise-host-4>`,
  `<enterprise-host-1>`.
- Alias/sync-helper collection (`mm`/`rm`/`sm`/`sr`, etc.), `pull.rebase=false`,
  global ignore at `~/.config/git/ignore`.

Design consequences:
1. **Magit needs no special config.** It shells out to the real `git`, so it
   inherits `includeIf` identity routing, `url.insteadOf` rewrites, aliases.
   Commit in a work repo → work identity, automatically.
2. **Forge needs explicit multi-host setup.** Five GitHub hosts (four enterprise
   + github.com). Register each in `forge-alist` with a per-host API token in
   auth-source, sourced from 1Password. github.com auths as `dabd`; enterprise
   hosts get their own tokens. Without this, Forge sees only github.com.

Hygiene split (the repo is personal/`dabd` and public-capable):
- **In repo (portable):** aliases, sync helpers, `pull.rebase`, default
  identity, `includeIf` structure.
- **Never in repo (machine-local / 1Password):** enterprise `url.insteadOf`
  rewrites, work emails, enterprise Forge host names + tokens. Kept in a
  gitignored local include (`~/.gitconfig-local`) and 1Password.

v1 safety: home-manager does **not** manage `~/.gitconfig`. The existing
conditional-include setup stays untouched; Emacs consumes it. Migrating portable
parts into `programs.git` (work bits in a local include) is a later increment.

Optional deferred: 1Password SSH agent to serve the SSH keys, making the
new-laptop SSH story reproducible without manual key copying.

## Secrets flow (1Password → Emacs)

Principle: the repo (public-capable) and the Nix store (world-readable) never
contain a secret. Secrets resolve at runtime from 1Password via `op`.

Secrets:
1. Anthropic API key → gptel + minuet.
2. Per-host GitHub tokens → Forge (one per enterprise host + github.com).
3. (Deferred) SSH keys via 1Password SSH agent.

Mechanism — `auth-source` (the native interface gptel/minuet/forge already
query). Backend = a custom-function shim in `llm.el` that shells out to
`op read "op://…"` on demand and caches per session. Lazy fetch, never written
to disk; the repo holds only the `op://` reference string (a pointer, not a
secret).

Rejected: shell-injected env vars via `op run` — fragile for daemon/launchd
Emacs that does not inherit the shell environment. Rejected: Nix-managed secrets
— derivations land in the world-readable store.

Committed vs not:

| In repo (safe) | Never in repo |
|---|---|
| `op://` reference strings | actual API key / tokens |
| auth-source shim code | resolved secret values |
| github.com Forge host name | enterprise tokens (1Password) + enterprise host names (local include) |

Safety net: `.gitignore` covering `*.gpg`, `*-secrets.el`, `.authinfo*`,
auth-source cache files; enable a pre-commit secret scan.

## Build phasing

Each phase ends with a working Emacs you could stop at. Riskiest/most-reversible
steps isolated. Prelude is not deleted until the new setup is proven.

- **Phase 0 — Safety net (runnable in current session):** rename `~/.emacs.d` →
  `~/.emacs.d.prelude-backup` (instant rollback). Confirm brew Emacs still
  launches. Create `~/dotfiles` directory + this spec under `docs/specs/`.
  `git init` and the first commit (spec only) happen at the start of Phase 1
  from the fresh session, so repo creation and the cwd handoff coincide.
- **Phase 1 — Flake skeleton + minimal home-manager (start fresh session from
  `~/dotfiles`):** `flake.nix` (three pinned inputs); minimal `home.nix`
  (emacs-macport + ripgrep/fd + symlink empty-ish `~/.config/emacs/`); first
  `home-manager switch` (long compile). Gate: Nix Emacs launches.
- **Phase 2 — Core config boots clean:** early-init/init + elpaca, ui.el,
  completion.el. Gate: no errors, theme + completion work.
- **Phase 3 — IDE layer:** editing.el, project.el, lsp.el (primary language);
  add LSP server to home.nix. Gate: find-usages/go-to-def/rename on a real
  project.
- **Phase 4 — Git:** git.el — magit (inherits identity routing), forge
  multi-host + 1Password tokens. Gate: commit in `~/projects/work` shows
  work identity; Forge lists PRs on an enterprise host.
- **Phase 5 — LLM:** llm.el — gptel + minuet via auth-source/1Password shim.
  Gate: gptel chats; minuet inline suggestions; no key on disk.
- **Phase 6 — Integration:** launchd daemon, emacsclient from tmux,
  ghostty/tmux coexistence. Gate: emacsclient attaches to persistent frame.
- **Phase 7 — Retire Prelude & document:** after a few days as daily driver,
  remove the Prelude backup. README: bootstrap steps, GUI escape hatch,
  work/personal git split.

Session-root handoff: Phase 0 can run in the current (work) session. **Phase 1
onward runs from a fresh session rooted at `~/dotfiles`** — correct cwd for git
defaults and for filing personal-project memory outside the work work project.

## Deferred backlog (out of scope for v1)

aidermacs/agentic coding (aidermacs vs claude-code-ide vs OpenCode), treemacs,
org config, migrating `~/.gitconfig` into home-manager, 1Password SSH agent,
per-language LSP beyond primary, `programs.tmux`/`zsh`/ghostty under
home-manager.

## Open questions carried forward

- Is the other target laptop the same Nix-friendly corporate fleet? If not, Nix
  may be blocked there and a plain `git clone` of `emacs/` remains the
  lowest-common-denominator fallback (the layered architecture supports this).
- Primary language for the Phase 3 LSP server (drives which server enters
  home.nix first).
