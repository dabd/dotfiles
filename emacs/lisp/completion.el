;;; completion.el --- minibuffer + in-buffer completion -*- lexical-binding: t; -*-

;; vertico/consult/corfu/etc. require compat >= 31, but Emacs 30 ships a
;; built-in compat 30.x. elpaca trusts the stale built-in and refuses to
;; fetch the newer one unless we manage compat explicitly — so declare it
;; first to install compat 31 before the packages that depend on it.
(use-package compat)

(use-package vertico
  :init (vertico-mode))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package marginalia
  :init (marginalia-mode))

(use-package consult
  :bind (("C-s"   . consult-line)
         ("C-x b" . consult-buffer)
         ("M-y"   . consult-yank-pop)))

;; C-x b (consult-buffer) is the fast fuzzy switcher. Bind C-x C-b to the
;; electric buffer browser/manager instead of the static `list-buffers' table:
;; a self-contained recursive-edit list (n/p to move, RET select, d/x to mark
;; and kill buffers) that restores the window layout on exit. Built in via
;; ebuff-menu; loads lazily on the key.
(use-package ebuff-menu
  :ensure nil
  :bind ("C-x C-b" . electric-buffer-list))

(use-package corfu
  :init (global-corfu-mode)
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.2))

(use-package savehist
  :ensure nil
  :init (savehist-mode))

(provide 'completion)
;;; completion.el ends here
