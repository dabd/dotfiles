;;; editing.el --- editing defaults and IntelliJ-flavored binds -*- lexical-binding: t; -*-

(delete-selection-mode 1)
(global-auto-revert-mode 1)
(save-place-mode 1)
(recentf-mode 1)
(setq-default indent-tabs-mode nil)
(electric-pair-mode 1)

(use-package multiple-cursors
  :bind (("C->"     . mc/mark-next-like-this)
         ("C-<"     . mc/mark-previous-like-this)
         ("C-c C-<" . mc/mark-all-like-this)))

(use-package expand-region
  :bind ("C-=" . er/expand-region))

;; Session persistence: restore open buffers + window layout on each launch.
;; No daemon here, so a config change means quit + relaunch; without this the
;; open-buffer set is lost each time. State lives in ~/.config/emacs/easysession/
;; (runtime, not the repo). easysession is used instead of the built-in
;; desktop.el because it cooperates with elpaca's async package loading: its
;; `easysession-setup' detects elpaca and registers restore on
;; `elpaca-after-init-hook' (after every package is built), so restored buffers
;; get their real major modes and compat 31 is loaded before any minibuffer
;; buffer is recreated. (desktop.el restores on `after-init-hook', which runs
;; mid-elpaca-queue - that raced packages and broke vertico's minibuffer setup.)
(use-package easysession
  :demand t                        ; must load eagerly so setup can register hooks
  :custom
  ;; Restore buffers + window layout, but NOT frame size/position. Must be set
  ;; before `easysession-setup' runs.
  (easysession-setup-load-session-including-geometry nil)
  :config
  (easysession-setup))

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
