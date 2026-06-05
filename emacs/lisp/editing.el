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
(use-package desktop
  :ensure nil
  :init (desktop-save-mode 1)
  :custom
  (desktop-save t)                          ; save on exit without prompting
  (desktop-load-locked-desktop 'check-pid)) ; ignore a stale lock from a dead Emacs

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
