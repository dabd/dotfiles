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

;; IntelliJ Cmd-D "duplicate line" equivalent.
(defun dabd/duplicate-line ()
  "Duplicate the current line below point."
  (interactive)
  (let ((col (current-column))
        (line (thing-at-point 'line t)))
    (save-excursion (end-of-line) (newline) (insert (string-trim-right line "\n")))
    (forward-line 1) (move-to-column col)))
(global-set-key (kbd "C-c d") #'dabd/duplicate-line)

(provide 'editing)
;;; editing.el ends here
