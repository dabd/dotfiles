;;; lsp.el --- eglot + dape -*- lexical-binding: t; -*-

;; scala-ts-mode is the tree-sitter major mode for Scala (not built in).
;; treesit-auto (see projects module) installs the grammar on first use.
(use-package scala-ts-mode
  :mode ("\\.scala\\'" "\\.sbt\\'"))

(use-package eglot
  :ensure nil
  :hook ((scala-ts-mode . eglot-ensure))
  :config
  ;; eglot's built-in server map keys Scala/Metals off `scala-mode'; since we
  ;; use the tree-sitter mode, map it explicitly to the Metals executable
  ;; (provided by the `metals' package in home.nix).
  (add-to-list 'eglot-server-programs '(scala-ts-mode . ("metals")))
  :bind (:map eglot-mode-map
              ("M-?"     . xref-find-references)
              ("M-."     . xref-find-definitions)
              ("C-c r"   . eglot-rename)
              ("C-c C-a" . eglot-code-actions)))

(use-package dape
  :custom (dape-buffer-window-arrangement 'right))

(provide 'lsp)
;;; lsp.el ends here
