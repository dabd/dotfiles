;;; early-init.el --- pre-frame startup tuning -*- lexical-binding: t; -*-
;; Raise GC threshold during startup; reset later in init.el.
(setq gc-cons-threshold most-positive-fixnum)
;; Disable chrome before the frame is drawn (avoids flicker).
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(scroll-bar-width . 0) default-frame-alist)
(menu-bar-mode -1)
;; elpaca manages packages; stop package.el from initializing.
(setq package-enable-at-startup nil)

;; PATH for non-shell launches. A launchd daemon (services.emacs) or a macOS
;; .app bundle inherits only the bare system PATH (/usr/bin:/bin:...), not the
;; Nix profile — so executable-find fails for metals (eglot), rg/fd
;; (consult/project), curl (gptel), etc. Nix is this config's single source of
;; truth for tools, so prepend the Nix profile dirs to exec-path and $PATH.
;; OS-agnostic and dependency-free (no exec-path-from-shell); covers standalone
;; home-manager (~/.nix-profile/bin, macOS + Linux) and system/NixOS profiles.
;; Other tools (e.g. git) stay on the inherited system PATH. Absent dirs are
;; skipped, so this is a no-op on a non-Nix machine.
(dolist (nix-bin (list (expand-file-name "~/.nix-profile/bin")
                       (concat "/etc/profiles/per-user/" (user-login-name) "/bin")
                       "/run/current-system/sw/bin"))
  (when (file-directory-p nix-bin)
    (add-to-list 'exec-path nix-bin)
    (let ((path (getenv "PATH")))
      (unless (and path (string-match-p (regexp-quote nix-bin) path))
        (setenv "PATH" (concat nix-bin path-separator path))))))
;;; early-init.el ends here
