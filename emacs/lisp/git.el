;;; git.el --- magit + forge -*- lexical-binding: t; -*-

;; This Emacs (Nix macport 30.2.50) ships transient 0.7.2.2, but magit 4.5
;; requires transient >= 0.13. Install a current transient via elpaca BEFORE
;; magit so elpaca-check-version is satisfied (same rationale as bundling a
;; newer compat).
(use-package transient)

(use-package magit
  :bind (("C-x g" . magit-status))
  :custom
  ;; Magit shells out to git, inheriting includeIf identity routing and
  ;; url.insteadOf rewrites from ~/.gitconfig. No identity config here.
  (magit-define-global-key-bindings 'recommended))

(use-package forge
  :after magit
  :config
  ;; github.com is built into forge. Enterprise hosts (work infrastructure)
  ;; are registered in a machine-local file kept OUTSIDE this Nix-managed,
  ;; public repo, so the hostnames never get committed. ~/.config/emacs is
  ;; entirely Nix-owned (read-only store symlinks), so the local file lives in
  ;; ~/.config/emacs-local/ instead and is hand-placed per machine (see README).
  ;; Tokens are resolved from auth-source (1Password shim, llm.el).
  (load (expand-file-name "emacs-local/local.el"
                          (expand-file-name (or (getenv "XDG_CONFIG_HOME")
                                                "~/.config")))
        t))

(provide 'git)
;;; git.el ends here
