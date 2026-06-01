;;; projects.el --- project navigation and tree-sitter -*- lexical-binding: t; -*-
;; NOTE: file is named projects.el (not project.el) to avoid a recursive-require
;; clash with Emacs' built-in `project' feature. init.el loads `projects'.

;; project.el is built in; bindings live under C-x p (see which-key).
(use-package project :ensure nil)

;; treesit-auto installs/maps tree-sitter grammars to *-ts-modes automatically.
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

(provide 'projects)
;;; projects.el ends here
