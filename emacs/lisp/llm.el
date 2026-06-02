;;; llm.el --- gptel (LLM chat/rewrite) -*- lexical-binding: t; -*-

;; gptel is the chat/rewrite client. This committed module is intentionally
;; BACKEND-LESS: it ships no API key and no default backend, so it is fully
;; portable and contains nothing work-specific or secret. Each machine selects
;; its own backend in a machine-local file kept OUTSIDE this public repo:
;; ~/.config/emacs-local/llm-local.el (hand-placed per machine, see README).
;;
;; On a work laptop that file registers AWS Bedrock (gptel-make-bedrock with the
;; work AWS profile); a personal machine could point at any other gptel backend.
;; Until such a file exists, gptel loads but has no configured backend.
;;
;; minuet (inline completion) is deliberately deferred: it does not support
;; Bedrock, and local-model/API-key backends are out of scope here.

(use-package gptel
  :bind (("C-c g" . gptel)             ; open/switch to a chat buffer
         ("C-c RET" . gptel-send))     ; send the current prompt/region
  :config
  ;; gptel's Bedrock backend needs curl >= 8.9 for SigV4, but macOS ships 8.7
  ;; and a GUI/daemon Emacs on macOS doesn't inherit the shell PATH (so
  ;; executable-find picks /usr/bin/curl). Prefer the Nix-profile curl (home.nix
  ;; installs >= 8.9)
  ;; by pointing gptel-use-curl at it; fall back to PATH curl elsewhere.
  (let ((nix-curl (expand-file-name "~/.nix-profile/bin/curl")))
    (when (file-executable-p nix-curl)
      (setq gptel-use-curl nix-curl)))
  ;; Per-machine backend selection (Bedrock on work laptops, etc.). NOERROR (t)
  ;; so a machine without the local file still loads gptel cleanly.
  (load (expand-file-name "emacs-local/llm-local.el"
                          (expand-file-name (or (getenv "XDG_CONFIG_HOME")
                                                "~/.config")))
        t))

(provide 'llm)
;;; llm.el ends here
