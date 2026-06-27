;;; projects.el --- project navigation and tree-sitter -*- lexical-binding: t; -*-
;; NOTE: file is named projects.el (not project.el) to avoid a recursive-require
;; clash with Emacs' built-in `project' feature. init.el loads `projects'.

;; project.el is built in; bindings live under C-x p (see which-key).
(use-package project :ensure nil)

;; Tree-sitter grammars come from Nix (home.nix installs the prebuilt bundle
;; into ~/.nix-profile/lib as libtree-sitter-LANG.dylib). Add that dir to the
;; grammar search path so built-in *-ts-modes (json, yaml, toml, ...) and the
;; scala grammar load with no per-machine install. The NixOS system profile path
;; is included for Linux; absent dirs are simply ignored.
(dolist (dir (list (expand-file-name "~/.nix-profile/lib")
                   "/run/current-system/sw/lib"))
  (when (file-directory-p dir)
    (add-to-list 'treesit-extra-load-path dir)))

;; treesit-auto maps grammars to *-ts-modes. With the Nix grammars already on
;; the load path it rarely needs to fetch; `prompt' stays as a fallback for any
;; language not in the bundle.
(use-package treesit-auto
  :custom (treesit-auto-install 'prompt)
  :config
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode))

;; dired tweaks for file-tree navigation.
(use-package dired :ensure nil
  :custom
  (dired-listing-switches "-alh")
  (dired-dwim-target t))

;; treemacs: a persistent file-tree side panel (the IntelliJ "Project view"
;; analog), toggled with C-x t t. LSP-agnostic - it tracks files, not symbols,
;; so it needs nothing from eglot. `treemacs-project-follow-mode' keeps the tree
;; focused on the project of the current buffer instead of a manually pinned set.
(use-package treemacs
  :bind ("C-x t t" . treemacs)
  :config
  (treemacs-project-follow-mode 1))

(provide 'projects)
;;; projects.el ends here
