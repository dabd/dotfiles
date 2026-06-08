;;; markup.el --- markdown preview -*- lexical-binding: t; -*-

;; markdown-mode itself arrives as a forge dependency and needs no declaration;
;; this module only fixes its preview. The defaults render via the old
;; Daringfireball `markdown' (CSS-less, no GFM) with no stylesheet, so the
;; preview (C-c C-c p) looks bare. Use pandoc for GFM -> HTML and inject a
;; stylesheet so the output is readable. C-c C-c p (markdown-preview) renders
;; to the browser via a temp buffer and writes no file; prefer it over
;; C-c C-c v (export-and-preview), which leaves a sibling .html on disk.
(use-package markdown-mode
  :defer t
  :custom
  ;; Pandoc reads the buffer on stdin and emits an HTML *fragment* (no
  ;; --standalone: markdown-mode adds its own <head>, so standalone would
  ;; double-wrap). Prefer the Nix-profile pandoc; a GUI .app does not inherit
  ;; the shell PATH, so fall back to PATH lookup only if that is absent.
  (markdown-command
   (let ((nix-pandoc (expand-file-name "~/.nix-profile/bin/pandoc")))
     (concat (if (file-executable-p nix-pandoc) nix-pandoc "pandoc")
             " --from=gfm --to=html5")))
  ;; Inline stylesheet injected into the export <head>. Kept inline (not an
  ;; external CSS file) so preview is self-contained and needs no file:// path
  ;; resolution. A small GitHub-ish theme: readable measure, real code blocks,
  ;; bordered tables.
  (markdown-xhtml-header-content
   (concat
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
    "<style>"
    "body{box-sizing:border-box;max-width:48rem;margin:0 auto;padding:2rem;"
    "font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;"
    "font-size:16px;line-height:1.6;color:#1f2328;}"
    "h1,h2{border-bottom:1px solid #d1d9e0;padding-bottom:.3em;}"
    "h1,h2,h3,h4{margin-top:1.5em;margin-bottom:.5em;font-weight:600;line-height:1.25;}"
    "a{color:#0969da;text-decoration:none;}a:hover{text-decoration:underline;}"
    "code{background:#eff1f3;border-radius:6px;padding:.2em .4em;font-size:85%;"
    "font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;}"
    "pre{background:#f6f8fa;border-radius:6px;padding:1em;overflow:auto;}"
    "pre code{background:none;padding:0;font-size:100%;}"
    "blockquote{margin:0;padding:0 1em;color:#59636e;border-left:.25em solid #d1d9e0;}"
    "table{border-collapse:collapse;}"
    "th,td{border:1px solid #d1d9e0;padding:6px 13px;}"
    "tr:nth-child(2n){background:#f6f8fa;}"
    "img{max-width:100%;}"
    "</style>")))

(provide 'markup)
;;; markup.el ends here
