;;; poly-asciidoc.el --- Polymode for asciidoc-mode -*- lexical-binding: t -*-
;;
;; Author: Rongsonf Shen
;; Maintainer: Rongsong Shen
;; Copyright (C) 2020
;; Version: 0.0.1
;; Package-Requires: ((emacs "25") (polymode "0.2.2") (adoc-mode ))
;; URL: https://github.com/shen390s/poly-asciidoc
;; Keywords: emacs
;;
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This file is *NOT* part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;;
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Code:

(require 'polymode)
(require 'adoc-mode)

(defun poly-asciidoc-compilation-mode-hook ()
  "Hook function to set local value for `compilation-error-screen-columns'."
  ;; In Emacs > 20.7 compilation-error-screen-columns is buffer local.
  (or (assq 'compilation-error-screen-columns (buffer-local-variables))
      (make-local-variable 'compilation-error-screen-columns))
  (setq compilation-error-screen-columns nil))

(defvar poly-asciidoc-output-format 'pdf
  "The format of generated file")

(defvar poly-asciidoc-verbose nil
  "Show verbose information when run compiler")

(defvar poly-asciidoc-compiler "poly-asciidoc"
  "The compiler used to generate output")

;; (defvar poly-asciidoc-mode-map
;;   (let ((map (make-sparse-keymap)))
;;     ;; add key bindings for poly-asciidoc mode here
;;     ;;
;;     (define-key map "\C-c\C-c" 'poly-asciidoc-compile)
;;     (define-key map "\C-c\C-v" 'poly-asciidoc-view)
;;     map)
;;   "Keymap for poly-asciidoc mode")

(defun poly-asciidoc-compiler (output-format)
  (cond
   ((string= output-format "pdf") "asciidoctor-pdf")
   ((string= output-format "html") "asciidoctor")
   (t "true")))

;;;###autoload
(defun poly-asciidoc-compile ()
  (interactive)
  (let ((cmd (format "%s %s"
		     (poly-asciidoc-compiler (symbol-name poly-asciidoc-output-format))
                     (buffer-file-name))))
        (buf-name "*poly-asciidoc compilation")
        (compilation-mode-hook (cons 'poly-asciidoc-compilation-mode-hook compilation-mode-hook)))
    (if (fboundp 'compilation-start)
        (compilation-start cmd nil
                           #'(lambda (mode-name)
                               buf-name))
      (compile-internal cmd "No more errors" buf-name))))

;;;###autoload
(defun poly-asciidoc-view ()
  (interactive)
  (let ((dst-file-name (concat (buffer-file-name)
                               (poly-asciidoc-output-ext))))
    (if (file-exists-p dst-file-name)
        (find-file-other-window dst-file-name)
      (error "Please compile the it first!\n"))))


;; Declarations

(define-obsolete-variable-alias 'pm-host/asciidoc 'poly-asciidoc-hostmode "v0.0.1")
(define-obsolete-variable-alias 'pm-inner/asciidoc-source-code 'poly-asciidoc-source-code-innermode "v0.0.1")
(define-obsolete-variable-alias 'pm-poly/asciidoc 'poly-asciidoc-polymode "v0.0.1")

(defconst tag-pattern
  "^\\[%s\\([ \t]*,[ \t]*\\w+\\)*[ \t]*\\][ \t]*\n-\\{4,\\}[ \t]*$"
  "patten template for tag")

(define-hostmode poly-asciidoc-hostmode
  :mode 'adoc-mode
  :init-functions '(poly-asciidoc-remove-asciidoc-hooks))

(define-innermode poly-asciidoc-root-innermode
  :mode nil
  :fallback-mode 'host
  :head-mode 'host
  :tail-mode 'host)

(defun poly-asciidoc-remove-asciidoc-hooks (host)
  t)

(defun poly-asciidoc-source-head-matcher (count)
  (when (re-search-forward
	 "^\\(\\[source,[ \t]*[^ \t]+[ \t]*\\][ \t]*\n----[-]*[ \t]*\\)$" nil t
	 count)
    (cons (match-beginning 0)
	  (match-end 0))))

(defun poly-asciidoc-source-tail-matcher (count)
  (when (re-search-forward "^-\\{4,\\}[ \t]*$" nil t)
    (cons (match-beginning 0)
	  (match-end 0))))

(defun poly-asciidoc-get-lang-mode (lang)
  (cond
   ((string= lang "shell") "shell-script-mode")
   ((string= lang "asciidoc") "adoc-mode")
   ((string= lang "yaml") "yaml-mode")
   (t (let ((s-mode (pm-get-mode-symbol-from-name lang)))
	(if s-mode
	    s-mode
	  "text-mode")))))

(defun poly-asciidoc-source-mode-matcher ()
  (when (re-search-forward
	 "^\\[source,[ \t]*\\([^ \t]+\\)[ \t]*\\]\n*$"
	 (point-at-eol) t)
    (let ((lang (match-string-no-properties 1)))
      (poly-asciidoc-get-lang-mode lang))))

(define-auto-innermode poly-asciidoc-source-code-innermode
  poly-asciidoc-root-innermode
  :head-matcher 'poly-asciidoc-source-head-matcher
  :tail-matcher 'poly-asciidoc-source-tail-matcher
  :mode-matcher 'poly-asciidoc-source-mode-matcher)

(defun poly-asciidoc-tag-head-matcher (tag count)
  (message "search tag %s count %d" tag count)
  (when (re-search-forward (format tag-pattern tag) 
		           nil t count)
    (cons (match-beginning 0)
	  (match-end 0))))

(defun poly-asciidoc-ditaa-head-matcher (count)
  (poly-asciidoc-tag-head-matcher "ditaa" count))

(defun poly-asciidoc-ditaa-mode-matcher ()
  "artist-mode")

(define-auto-innermode poly-asciidoc-ditaa-code-innermode
  poly-asciidoc-root-innermode
  :head-matcher 'poly-asciidoc-ditaa-head-matcher
  :tail-matcher 'poly-asciidoc-source-tail-matcher
  :mode-matcher 'poly-asciidoc-ditaa-mode-matcher)

;;;###autoload  (autoload 'poly-asciidoc-mode "poly-asciidoc")
(define-polymode poly-asciidoc-mode
  :hostmode 'poly-asciidoc-hostmode
  :innermodes '(poly-asciidoc-source-code-innermode
		poly-asciidoc-ditaa-code-innermode
                ;;
		))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.adoc\\'" . poly-asciidoc-mode))

(provide 'poly-asciidoc-mode)
