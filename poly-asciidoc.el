;;; poly-asciidoc.el --- Polymode for asciidoc-mode -*- lexical-binding: t -*-
;;
;; Author: Rongsonf Shen
;; Maintainer: Rongsong Shen
;; Copyright (C) 2020
;; Version: 0.0.1
;; Package-Requires: ((emacs "25") (polymode "0.2.2") (adoc-mode
;;"0.6.6") ("plantuml-mode" ))
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

(defconst tag-pattern
  "^\\[%s\\([ \t]*,.*\\)*\\]\n-\\{4,\\}[ \t]*$"
  "patten template for tag")

(defconst asciidoc-diagram-tags
  '(a2s actdiag blockdiag bpmn bytefield ditaa dpic erd
	gnuplot graphviz meme mermaid msc nomnoml nwdiag
	packetdiag pikchr plantuml rackdiag seqdiag shaape smcat
	svgbob syntrax umlet vega vega vegalite wavedrom)
  "tags which need asciidoctor-diagram")

(defun poly-asciidoc-mkfun (tag fn type)
  (intern (format "poly-asciidoc-%s-%s-%s"
		  tag fn type)))

(defmacro poly-asciidoc-innermode! (tag tag-mode-fun)
  `(progn
     (defun ,(poly-asciidoc-mkfun tag "head" "matcher") (count)
       (poly-asciidoc-tag-head-matcher ,tag  count))
     (defun ,(poly-asciidoc-mkfun tag "tail" "matcher") (count)
       (poly-asciidoc-source-tail-matcher count))
     (defun ,(poly-asciidoc-mkfun tag "mode" "matcher") ()
       (funcall ,tag-mode-fun))
     (define-auto-innermode
       ,(poly-asciidoc-mkfun tag "code" "innermode")
       poly-asciidoc-root-innermode
       :head-matcher ',(poly-asciidoc-mkfun tag "head" "matcher")
       :tail-matcher ',(poly-asciidoc-mkfun tag "tail" "matcher")
       :mode-matcher ',(poly-asciidoc-mkfun tag "mode" "matcher"))))

(defmacro poly-asciidoc-mk-innermodes! (modes)
  `(progn
     ,@(cl-loop for mode in modes
		collect `(poly-asciidoc-innermode!
			  ,(car mode)
			  ,(cdr mode)))))

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

(defun poly-asciidoc-compiler (output-format)
  (cond
   ((string= output-format "pdf") "asciidoctor-pdf")
   ((string= output-format "html") "asciidoctor")
   ((string= output-format "epub") "asciidoctor")
   (t "true")))

(defun poly-asciidoc-check-tag (tag)
  (save-excursion
    (goto-char (point-min))
    (re-search-forward (format tag-pattern tag)
		       nil t 1)))

(defun poly-asciidoc-check-tags (tags)
  (if (null tags)
      nil
    (if (poly-asciidoc-check-tag (car tags))
	t
      (poly-asciidoc-check-tags (cdr  tags)))))

(defun poly-asciidoc-check-diagram ()
  (interactive)
  (poly-asciidoc-check-tags asciidoc-diagram-tags))

(defun poly-asciidoc-compile-options (output-format)
  (setq options "")
  (progn
    (when (poly-asciidoc-check-diagram)
      (setq options (format "%s -r asciidoctor-diagram" options)))
    (cond
     ((string= output-format "epub")
      (setq options (format "%s -r asciidoctor-epub3 -b epub3 "
			    options)))
     (t t)))
  options)

;;;###autoload
(defun poly-asciidoc-compile ()
  (interactive)
  (let ((cmd (format "%s %s %s"
		     (poly-asciidoc-compiler (symbol-name poly-asciidoc-output-format))
		     (poly-asciidoc-compile-options (symbol-name poly-asciidoc-output-format))
                     (buffer-file-name)))
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
  (let ((dst-file-name (format "%s.%s"
			       (file-name-sans-extension (buffer-file-name))
                               (symbol-name poly-asciidoc-output-format))))
    (if (file-exists-p dst-file-name)
        (find-file-other-window dst-file-name)
      (error "Please compile the it first!\n"))))

;;;###autoload
(defun poly-asciidoc-set-output-format ()
  (interactive)
  (setq poly-asciidoc-output-format
	(intern (completing-read "Choose output format:"
				 '(("pdf" 1) ("html" 2) ("epub" 3))
				 nil t "" nil "pdf"))))

;; Declarations

(define-obsolete-variable-alias 'pm-host/asciidoc 'poly-asciidoc-hostmode "v0.0.1")
(define-obsolete-variable-alias 'pm-inner/asciidoc-source-code 'poly-asciidoc-source-code-innermode "v0.0.1")
(define-obsolete-variable-alias 'pm-inner/asciidoc-ditaa-code 'poly-asciidoc-ditaa-code-innermode "0.0.1")
(define-obsolete-variable-alias 'pm-poly/asciidoc 'poly-asciidoc-polymode "v0.0.1")

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
  (let ((pattern (format tag-pattern tag)))
    (when (re-search-forward pattern nil t count)
      (cons (match-beginning 0)
	    (match-end 0)))))

;; NOTICE:
;; avoid duplicated name 
(defun poly-asciidoc/graphviz-mode-matcher ()
  "graphviz-mode")

(poly-asciidoc-mk-innermodes! 
 (("ditaa" . (lambda () "artist-mode"))
  ("plantuml" . (lambda () "plantuml-mode"))
  ("actdiag" . 'poly-asciidoc/graphviz-mode-matcher)
  ("blockdiag" . 'poly-asciidoc/graphviz-mode-matcher)
  ("graphviz" . 'poly-asciidoc/graphviz-mode-matcher)
  ("nwdiag" . 'poly-asciidoc/graphviz-mode-matcher)
  ("seqdiag" . 'poly-asciidoc/graphviz-mode-matcher)))

;;;###autoload  (autoload 'poly-asciidoc-mode "poly-asciidoc")
(define-polymode poly-asciidoc-mode
  :hostmode 'poly-asciidoc-hostmode
  :innermodes '(poly-asciidoc-source-code-innermode
		poly-asciidoc-ditaa-code-innermode
		poly-asciidoc-plantuml-code-innermode
		poly-asciidoc-actdiag-code-innermode
		poly-asciidoc-blockdiag-code-innermode
		poly-asciidoc-graphviz-code-innermode
		poly-asciidoc-nwdiag-code-innermode
		poly-asciidoc-seqdiag-code-innermode
                ;;
		))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.adoc\\'" . poly-asciidoc-mode))

(provide 'poly-asciidoc-mode)
