;;; ui.el --- appearance -*- lexical-binding: t; -*-

;; doom-themes: colorful, high-contrast syntax highlighting (doom-one is the
;; classic). modus-vivendi (built in) is deliberately low-saturation, so we use
;; doom-one for richer coloring. :ensure-system-package not needed; elpaca fetches.
(use-package doom-themes
  :config
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t)
  (load-theme 'doom-one t))

;; which-key is built in on Emacs 30; enable it.
(use-package which-key
  :ensure nil
  :init (which-key-mode)
  :custom (which-key-idle-delay 0.3))

;; Sensible visual defaults.
(setq inhibit-startup-screen t
      ring-bell-function 'ignore)
(global-display-line-numbers-mode 1)
(column-number-mode 1)
(when (member "Menlo" (font-family-list))
  (set-face-attribute 'default nil :family "Menlo" :height 100)) ; 10pt

(provide 'ui)
;;; ui.el ends here
