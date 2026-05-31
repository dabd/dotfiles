;;; early-init.el --- pre-frame startup tuning -*- lexical-binding: t; -*-
;; Raise GC threshold during startup; reset later in init.el.
(setq gc-cons-threshold most-positive-fixnum)
;; Disable chrome before the frame is drawn (avoids flicker).
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(scroll-bar-width . 0) default-frame-alist)
(menu-bar-mode -1)
;; elpaca manages packages; stop package.el from initializing.
(setq package-enable-at-startup nil)
;;; early-init.el ends here
