;;; editing.el --- editing defaults and IntelliJ-flavored binds -*- lexical-binding: t; -*-

(delete-selection-mode 1)
(global-auto-revert-mode 1)
(save-place-mode 1)
(recentf-mode 1)
(setq-default indent-tabs-mode nil)
(electric-pair-mode 1)

;; Session persistence: restore the set of open buffers/windows on restart.
;; No daemon here, so a config change means a full quit + relaunch - without
;; this, the open-buffer set is lost each time. State lives in the runtime
;; ~/.config/emacs/ (not the repo). `save-place-mode' above then restores point.
;;
;; The restore is deferred to `elpaca-after-init-hook', NOT enabled eagerly.
;; desktop normally restores on `after-init-hook', but elpaca loads packages
;; asynchronously *after* that hook, so an eager restore races two ways:
;;   1. buffers come back in Fundamental mode because their major modes
;;      (markdown-mode, scala-ts-mode, ...) are not loaded yet; and
;;   2. restoring a vertico/corfu buffer forces an early `(require 'compat)'
;;      that - before elpaca puts its build dirs on `load-path' - resolves to
;;      Emacs' built-in compat 30, permanently shadowing elpaca's compat 31.
;;      That leaves `set-local' (a compat-31 function vertico calls) void and
;;      breaks the minibuffer (vertico--setup errors on every M-x).
;; `elpaca-after-init-hook' fires once the package queue is drained, so compat
;; 31 and all major modes are loaded before we restore.
(defun dabd/desktop-init ()
  "Enable session persistence and restore the saved desktop.
Run only after elpaca has loaded every package, so restored buffers get
their real major modes (markdown-mode, scala-ts-mode, ...) and compat 31
is in place before any minibuffer/corfu buffer is recreated."
  (setq desktop-save t                       ; save on exit without prompting
        desktop-load-locked-desktop 'check-pid ; ignore a stale lock (dead Emacs)
        ;; Pin the save file to ~/.config/emacs/ so the location is
        ;; deterministic and `desktop-kill' never prompts on exit.
        desktop-path (list user-emacs-directory)
        desktop-dirname user-emacs-directory)
  (desktop-save-mode 1)
  (desktop-read))

(use-package desktop
  :ensure nil
  :init
  ;; This :init may run before OR after elpaca-after-init-hook fires, depending
  ;; on queue timing, so handle both: run now if it already fired, else defer.
  (if (bound-and-true-p elpaca-after-init-time)
      (dabd/desktop-init)
    (add-hook 'elpaca-after-init-hook #'dabd/desktop-init)))

(use-package multiple-cursors
  :bind (("C->"     . mc/mark-next-like-this)
         ("C-<"     . mc/mark-previous-like-this)
         ("C-c C-<" . mc/mark-all-like-this)))

(use-package expand-region
  :bind ("C-=" . er/expand-region))

;; IntelliJ Cmd-D "duplicate line" equivalent.
(defun dabd/duplicate-line ()
  "Duplicate the current line below point."
  (interactive)
  (let ((col (current-column))
        (line (thing-at-point 'line t)))
    (save-excursion (end-of-line) (newline) (insert (string-trim-right line "\n")))
    (forward-line 1) (move-to-column col)))
(global-set-key (kbd "C-c d") #'dabd/duplicate-line)

;; Copy the current buffer's file path to the kill ring. With a prefix arg,
;; copy only the file name. Works in dired buffers via `list-buffers-directory'.
(defun dabd/copy-buffer-path (&optional just-name)
  "Copy the current buffer's file path to the kill ring.
With prefix arg JUST-NAME, copy only the file name."
  (interactive "P")
  (if-let* ((path (or (buffer-file-name) list-buffers-directory)))
      (let ((out (if just-name (file-name-nondirectory path) path)))
        (kill-new out)
        (message "Copied: %s" out))
    (user-error "Buffer is not visiting a file")))
(global-set-key (kbd "C-c w") #'dabd/copy-buffer-path)

(provide 'editing)
;;; editing.el ends here
