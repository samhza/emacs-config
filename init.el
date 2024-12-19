;; -*- lexical-binding: t; -*-

;; my emacs config
;; modal editing via meow
;; some stuff is borrowed from other people's configs
;; for larger copied chunks i've included their names

(add-to-list 'default-frame-alist '(font . "Iosevka Comfy Fixed Semibold-10:antialias=none"))
;;(add-to-list 'default-frame-alist '(font . "Go Mono 10"))

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(setq inhibit-splash-screen t)
(setq use-dialog-box nil)
(setq inhibit-startup-echo-area-message t)
(setq initial-major-mode 'fundamental-mode)
(setq initial-scratch-message "")
(setq use-short-answers t)
(setq-default fill-column 80)
(setq vc-follow-symlinks t)
(setq ring-bell-function 'ignore)
(blink-cursor-mode 1)
(setq window-resize-pixelwise t
      frame-resize-pixelwise t)
(setq sentence-end-double-space t)

;; * Repeat Mode
(repeat-mode 1)

;; * Backups

(setq auto-save-interval 2400)
(setq auto-save-timeout 300)
(setq auto-save-list-file-prefix
      "/home/sam/.cache/emacs/auto-save-list/.saves-")
(setq backup-directory-alist
      `(("." . ,"/home/sam/.cache/emacs/backup"))
      backup-by-copying t ; Use copies
      version-control t ; Use version numbers on backups
      delete-old-versions t ; Automatically delete excess backups
      kept-new-versions 10 ; Newest versions to keep
      kept-old-versions 5 ; Old versions to keep
      )
(setq project-vc-extra-root-markers
      '(".jj"))

;; * SAVEHIST
(use-package savehist
  ;; :defer 2
  :hook (after-init . savehist-mode)
  :config
  (setq savehist-additional-variables '(mark-ring
                                                 global-mark-ring
                                                 search-ring
                                                 regexp-search-ring
                                                 extended-command-history))

  (setq savehist-file "/home/sam/.local/share/emacs/savehist")
  (setq history-length 1000)
  (setq history-delete-duplicates t)
  (setq savehist-save-minibuffer-history t))

;; * Elpaca

(setq native-comp-async-report-warnings-errors nil)
(setq elpaca-core-date '(20231211))

(defvar elpaca-installer-version 0.8)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-repos-directory (expand-file-name "repos/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca--activate-package)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-repos-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (< emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let* ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                  ,@(when-let* ((depth (plist-get order :depth)))
                                                      (list (format "--depth=%d" depth) "--no-single-branch"))
                                                  ,(plist-get order :repo) ,repo))))
                  ((zerop (call-process "git" nil buffer t "checkout"
                                        (or (plist-get order :ref) "--"))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                        "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (load "./elpaca-autoloads")))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))
(setq use-package-always-ensure t)

(elpaca elpaca-use-package
  ;; Enable use-package :ensure support for Elpaca.
  (elpaca-use-package-mode))

;; * General

(use-package general
  :ensure (:wait t))

(general-auto-unbind-keys)

;; * Some DOOM helpers (copied from noctuid)

;; ** Large file handling
(defvar-local doom-large-file-p nil)
(put 'doom-large-file-p 'permanent-local t)

(defvar doom-large-file-size-alist '(("." . 3.0))
  "An alist mapping regexps (like `auto-mode-alist') to filesize thresholds.

If a file is opened and discovered to be larger than the threshold, Doom
performs emergency optimizations to prevent Emacs from hanging, crashing or
becoming unusably slow.

These thresholds are in MB, and is used by `doom--optimize-for-large-files-a'.")

(defvar doom-large-file-excluded-modes
  '(so-long-mode
    special-mode archive-mode tar-mode jka-compr
    git-commit-mode image-mode doc-view-mode doc-view-mode-maybe
    ebrowse-tree-mode pdf-view-mode tags-table-mode)
  "Major modes that `doom-check-large-file-h' will ignore.")

(defun doom--optimize-for-large-files-a (orig-fn &rest args)
  "Set `doom-large-file-p' if the file is too large.

Uses `doom-large-file-size-alist' to determine when a file is too large. When
`doom-large-file-p' is set, other plugins can detect this and reduce their
runtime costs (or disable themselves) to ensure the buffer is as fast as
possible."
  (if (setq doom-large-file-p
            (and buffer-file-name
                 (not doom-large-file-p)
                 (file-exists-p buffer-file-name)
                 (ignore-errors
                   (> (nth 7 (file-attributes buffer-file-name))
                      (* 1024 1024
                         (assoc-default buffer-file-name
                                        doom-large-file-size-alist
                                        #'string-match-p))))))
      (prog1 (apply orig-fn args)
        (if (memq major-mode doom-large-file-excluded-modes)
            (setq doom-large-file-p nil)
          (when (fboundp 'so-long-minor-mode) ; in case the user disabled it
            (so-long-minor-mode))
          (message "Large file! Cutting corners to improve performance")))
    (apply orig-fn args)))

(general-add-advice 'after-find-file :around #'doom--optimize-for-large-files-a)

;; * Indent

(setq-default indent-tabs-mode nil
              tab-width 4)


;; * Blackout

(use-package blackout
  :ensure (blackout :host github :repo "raxod502/blackout" :wait t)
  :demand t)
(use-package eldoc
  :ensure nil
  :blackout t)
;; * GCMH
(use-package gcmh
      :defer 2
      :ensure t
      :blackout t
      ;; :hook (after-init . gcmh-mode)
      :config
      (defun gcmh-register-idle-gc ()
        "Register a timer to run `gcmh-idle-garbage-collect'.
Cancel the previous one if present."
        (unless (eq this-command 'self-insert-command)
          (let ((idle-t (if (eq gcmh-idle-delay 'auto)
		            (* gcmh-auto-idle-delay-factor gcmh-last-gc-time)
		          gcmh-idle-delay)))
            (if (timerp gcmh-idle-timer)
                (timer-set-time gcmh-idle-timer idle-t)
              (setf gcmh-idle-timer
	            (run-with-timer idle-t nil #'gcmh-idle-garbage-collect))))))
      (setq gcmh-idle-delay 'auto  ; default is 15s
            gcmh-high-cons-threshold (* 32 1024 1024)
            gcmh-verbose nil)
      (gcmh-mode 1))

;; * Theme

(use-package doom-themes
  :disabled t
  :ensure t
  :demand t
  :config (load-theme 'doom-zenburn t))

(use-package catppuccin-theme
  :ensure t
  :disabled t
  :demand t
  :config (load-theme 'catppuccin t))

(use-package standard-themes
  :ensure t
  :demand t
  :config (load-theme 'standard-dark t))

;; * Meow
;; (custom-set-faces
;;  '(meow-motion-cursor ((t (:background "#B58DAE")))))

;; (custom-set-faces
;;  '(meow-normal-cursor ((t (:background "#80A0C2")))))
(general-create-definer general-spc
  :keymaps '(meow-normal-state-keymap meow-motion-state-keymap)
  :prefix "SPC")
(defun sam-I ()
  (interactive)
  (beginning-of-line-text)
  (meow-insert))
(defun sam-A ()
  (interactive)
  (end-of-line)
  (when (region-active-p)
    (meow-cancel-selection))
  (meow-insert))
(defun select-next-window ()
  (interactive)
  (select-window (next-window)))
(defun select-previous-window ()
  (interactive)
  (select-window (previous-window)))
(defun my/meow-grab (arg)
  (interactive "P")
  (if arg (meow-pop-grab) (meow-grab)))
(defun meow-avy-goto-char-2 ()
  (interactive)
  (set-mark-command nil)
  (call-interactively 'avy-goto-char-2))
(defun meow-avy-goto-line ()
  (interactive)
  (avy-goto-line (if current-prefix-arg 4 nil))
  (if (equal '(expand . line) (meow--selection-type))
      (if (> (point) (mark)) (move-end-of-line nil) (move-beginning-of-line nil))
    (meow-line 1)
    (meow--remove-expand-highlights)))


(defun meow-setup ()
  (setq meow-cheatsheet-layout meow-cheatsheet-layout-colemak)
  ;; (setq meow-keypad-leader-dispatch leader-spc-map)
  (meow-motion-overwrite-define-key
   '("e" . meow-prev)
   '("<escape>" . ignore))
  (general-spc
   "?" #'meow-cheatsheet
   ;; To execute the originally e in MOTION state, use SPC e.
   ;; "e" #'"H-e"
   "1" #'meow-digit-argument
   "2" #'meow-digit-argument
   "3" #'meow-digit-argument
   "4" #'meow-digit-argument
   "5" #'meow-digit-argument
   "6" #'meow-digit-argument
   "7" #'meow-digit-argument
   "8" #'meow-digit-argument
   "9" #'meow-digit-argument
   "0" #'meow-digit-argument)

  ;;(general-def meow-normal-state-keymap
  ;;  "SPC" leader-spc-map)
  (meow-normal-define-key
   '("S-<right>" . meow-right-expand)
   '("S-<left>" . meow-left-expand)
   '("0" . meow-expand-0)
   '("1" . meow-expand-1)
   '("2" . meow-expand-2)
   '("3" . meow-expand-3)
   '("4" . meow-expand-4)
   '("5" . meow-expand-5)
   '("6" . meow-expand-6)
   '("7" . meow-expand-7)
   '("8" . meow-expand-8)
   '("9" . meow-expand-9)
   '("-" . negative-argument)
   '(";" . meow-reverse)
   '("," . meow-inner-of-thing)
   '("." . meow-bounds-of-thing)
   '("[" . meow-beginning-of-thing)
   '("]" . meow-end-of-thing)
   '("/" . meow-visit)
   '("A" . sam-A)
   '("a" . meow-append)
   '("B" . meow-back-symbol)
   '("b" . meow-back-word)
   '("c" . meow-change)
   '("D" . meow-delete)
   '("d" . meow-kill)
   '("e" . meow-prev)
   '("E" . meow-prev-expand)
   '("g" . meow-cancel-selection)
   '("G" . my/meow-grab)
   '("H" . meow-left-expand)
   '("i" . meow-insert)
   '("I" . sam-I)
   '("j" . meow-join)
   '("k" . meow-search)
   '("M" . meow-mark-symbol)
   '("m" . meow-mark-word)
   '("n" . meow-next)
   '("N" . meow-next-expand)
   '("O" . meow-open-above)
   '("o" . meow-open-below)
   '("p" . meow-yank)
   '("q" . meow-quit)
   '("r" . meow-replace)
   '("R" . meow-swap-grab)
   '("t" . meow-till)
   '("u" . meow-undo)
   '("U" . meow-undo-in-selection)
   '("W" . meow-next-symbol)
   '("w" . meow-next-word)
   '("x" . meow-line)
   '("X" . meow-block)
   '("y" . meow-save)
   '("z" . meow-pop-selection)
   '("'" . repeat)
   '("<escape>" . ignore)))

(use-package meow
  :ensure (:wait t)
  :config
  (setq meow-use-clipboard t
        meow-visit-sanitize-completion nil)
  (meow-setup)
  (meow-global-mode 1)
  )
(setq meow-expand-exclude-mode-list nil)

;; * Avy

(defun my/avy-isearch ()
  (interactive)
  (goto-char (min (point) isearch-other-end))
  (avy-isearch)
  )
 
(use-package avy
  :bind
  (:map isearch-mode-map ("C-f" . my/avy-isearch))
  :config
  
  (setq avy-keys '(?a ?r ?s ?t ?h ?n ?e ?i ?o ?w ?f ?l ?u)
        avy-all-windows nil
	    avy-single-candidate-jump nil)
  
  (meow-normal-define-key
   '("f" . avy-goto-char-2)
   '("F" . avy-goto-line)
   '("h" . avy-goto-word-1)
   '("?" . avy-goto-char-timer)
   ))

(defun my-meow--beacon-advice (&rest _)
  (meow--beacon-remove-overlays)
  (advice-remove 'meow--beacon-apply-kmacros #'my-meow--beacon-advice))

(defun avy-action-add-cursor (pt)
  (unwind-protect
      (progn
        (meow--beacon-add-overlay-at-point pt)
        (kmacro-keyboard-quit)
        (avy-resume))
    (advice-add 'meow--beacon-apply-kmacros :after #'my-meow--beacon-advice)
    (meow-beacon-start)))

(defun avy-action-change (pt)
  (avy-action-kill-move pt)
  (when (and meow-mode
             (not meow-insert-mode))
    (meow-insert)))
(defun avy-action-embark (pt)
  (unwind-protect
      (save-excursion
        (goto-char pt)
        (embark-act))
    (select-window
     (cdr (ring-ref avy-ring 0))))
  t)
(defun avy-action-teleport-whole-line (pt)
  (avy-action-kill-whole-line pt)
  (save-excursion (yank)) t)


(with-eval-after-load 'avy
  (setq avy-dispatch-alist '((?d . avy-action-kill-stay)
                             (?c . avy-action-change)
                             (?t . avy-action-teleport)
                             (?T . avy-action-teleport-whole-line)
                             (?m . avy-action-mark)
                             (?y . avy-action-copy)
                             (?p . avy-action-yank)
                             (?P . avy-action-yank-line)
                             (?i . avy-action-ispell)
			                 (?  . avy-action-embark)
                             (?\; . avy-action-add-cursor)
                             (?z . avy-action-zap-to-char))))
;; * Marginalia
(use-package marginalia
  ;; Bind `marginalia-cycle' locally in the minibuffer.  To make the binding
  ;; available in the *Completions* buffer, add it to the
  ;; `completion-list-mode-map'.
  ;; :bind (:map minibuffer-local-map
  ;;        ("M-A" . marginalia-cycle))

  ;; The :init section is always executed.
  :init

  ;; Marginalia must be activated in the :init section of use-package such that
  ;; the mode gets enabled right away. Note that this forces loading the
  ;; package.
  (marginalia-mode))

;; * Vertico
;; Enable vertico
(use-package vertico
  ;; :custom
  ;; (vertico-scroll-margin 0) ;; Different scroll margin
  ;; (vertico-count 20) ;; Show more candidates
  ;; (vertico-resize t) ;; Grow and shrink the Vertico minibuffer
  ;; (vertico-cycle t) ;; Enable cycling for `vertico-next/previous'
  :init
  (vertico-mode))


;; A few more useful configurations...
(use-package emacs
  :ensure nil
  :custom
  ;; Support opening new minibuffers from inside existing minibuffers.
  (enable-recursive-minibuffers t)
  ;; Emacs 28 and newer: Hide commands in M-x which do not work in the current
  ;; mode.  Vertico commands are hidden in normal buffers. This setting is
  ;; useful beyond Vertico.
  (read-extended-command-predicate #'command-completion-default-include-p)
  :init
  ;; Add prompt indicator to `completing-read-multiple'.
  ;; We display [CRM<separator>], e.g., [CRM,] if the separator is a comma.
  (defun crm-indicator (args)
    (cons (format "[CRM%s] %s"
                  (replace-regexp-in-string
                   "\\`\\[.*?]\\*\\|\\[.*?]\\*\\'" ""
                   crm-separator)
                  (car args))
          (cdr args)))
  (advice-add #'completing-read-multiple :filter-args #'crm-indicator)

  ;; Do not allow the cursor in the minibuffer prompt
  (setq minibuffer-prompt-properties
        '(read-only t cursor-intangible t face minibuffer-prompt))
  (add-hook 'minibuffer-setup-hook #'cursor-intangible-mode))


;; * Orderless
(use-package orderless
  :custom
  ;; Configure a custom style dispatcher (see the Consult wiki)
  ;; (orderless-style-dispatchers '(+orderless-consult-dispatch orderless-affix-dispatch))
  ;; (orderless-component-separator #'orderless-escapable-split-on-space)
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles partial-completion)))))

;; * No littering
(use-package no-littering
  :demand t)

;; * Corfu
(use-package corfu
  ;; Optional customizations
  :custom
  ;; (corfu-cycle t)                ;; Enable cycling for `corfu-next/previous'
  (corfu-auto t)                 ;; Enable auto completion
  ;; (corfu-separator ?\s)          ;; Orderless field separator
  ;; (corfu-quit-at-boundary nil)   ;; Never quit at completion boundary
  ;; (corfu-quit-no-match nil)      ;; Never quit, even if there is no match
  ;; (corfu-preview-current nil)    ;; Disable current candidate preview
  ;; (corfu-preselect 'prompt)      ;; Preselect the prompt
  ;; (corfu-on-exact-match nil)     ;; Configure handling of exact matches
  ;; (corfu-scroll-margin 5)        ;; Use scroll margin

  ;; Enable Corfu only for certain modes. See also `global-corfu-modes'.
  ;; :hook ((prog-mode . corfu-mode)
  ;;        (shell-mode . corfu-mode)
  ;;        (eshell-mode . corfu-mode))

  ;; Recommended: Enable Corfu globally.  This is recommended since Dabbrev can
  ;; be used globally (M-/).  See also the customization variable
  ;; `global-corfu-modes' to exclude certain modes.
  :init
  (global-corfu-mode))
;; A few more useful configurations...
(use-package emacs
  :ensure nil
  :custom
  ;; TAB cycle if there are only few candidates
  ;; (completion-cycle-threshold 3)

  ;; Enable indentation+completion using the TAB key.
  ;; `completion-at-point' is often bound to M-TAB.
  (tab-always-indent 'complete)

  ;; Emacs 30 and newer: Disable Ispell completion function. As an alternative,
  ;; try `cape-dict'.
  (text-mode-ispell-word-completion nil)

  ;; Emacs 28 and newer: Hide commands in M-x which do not apply to the current
  ;; mode.  Corfu commands are hidden, since they are not used via M-x. This
  ;; setting is useful beyond Corfu.
  (read-extended-command-predicate #'command-completion-default-include-p))

;; * misc programming modes
(use-package go-mode)
(use-package nix-mode)
(use-package treesit-auto
  :config
  (setq treesit-auto-install 'prompt)
  ;;(setq treesit-auto-langs (remove 'tsx treesit-auto-langs))
  ;;(setq treesit)
  (setq treesit-auto-langs '(go))
  (global-treesit-auto-mode))
(use-package envrc
  :when (executable-find "direnv")
  :blackout t
  :config
  (envrc-global-mode))

(use-package web-mode)

(define-derived-mode typescript-tsx-mode web-mode "TSX"
  "A major mode for tsx.")

 (add-hook 'typescript-tsx-mode-hook
           (lambda ()
             (setq-local electric-indent-chars
                         (delq 10 electric-indent-chars))))

(use-package typescript-mode
  :mode (("\\.ts\\'" . typescript-mode)
         ("\\.tsx\\'" . typescript-tsx-mode)))

;; * tecosaur latex fork for org-preview-mode
(use-package org
  :defer
  :config
  (setq org-preview-latex-default-process 'dvisvgm)
  (plist-put org-latex-preview-appearance-options
             :zoom 1.6)
  :ensure `(org
            :remotes ("tecosaur"
                      :repo "https://git.tecosaur.net/tec/org-mode.git"
                      :branch "dev")
            :files (:defaults ("etc/styles/" "etc/styles/*" "doc/*.texi"))
            :build t
            :pre-build
            (progn
              (with-temp-file "org-version.el"
               (require 'lisp-mnt)
               (let ((version
                      (with-temp-buffer
                        (insert-file-contents "lisp/org.el")
                        (lm-header "version")))
                     (git-version
                      (string-trim
                       (with-temp-buffer
                         (call-process "git" nil t nil "rev-parse" "--short" "HEAD")
                         (buffer-string)))))
                (insert
                 (format "(defun org-release () \"The release version of Org.\" %S)\n" version)
                 (format "(defun org-git-version () \"The truncate git commit hash of Org mode.\" %S)\n" git-version)
                 "(provide 'org-version)\n")))
              (require 'elpaca-menu-org)
              (elpaca-menu-org--build))
            :pin nil))

;; * Consult
(use-package consult
  :config
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)
  (use-package consult-flymake
    :bind ("M-g f" . consult-flymake))
  :bind
  (("M-s l" . consult-line))
  :general
  (general-spc
	"/" #'consult-ripgrep
	"k" #'consult-fd
	"f" #'consult-buffer))

;; * Window

(use-package switchy-window
  :ensure t
  :defer 2
  :init (switchy-window-minor-mode)
  :bind ("M-o" . switchy-window)
  :config)


;; * Recentf
(use-package recentf
  :ensure nil
  :init
  (general-add-advice '(after-find-file consult-buffer)
                      :before
                      (lambda (&rest _)
                        (recentf-mode))
                      nil
                      t)
  :config
  (setq recentf-max-saved-items 1000)

  (defun doom--recent-file-truename (file)
    (if (or (file-remote-p file nil t)
            (not (file-remote-p file)))
        (file-truename file)
      file))

  ;; settings from doom
  (setq recentf-filename-handlers
        '(;; Text properties inflate the size of recentf's files, and there is
          ;; no purpose in persisting them, so we strip them out.
          substring-no-properties
          ;; Resolve symlinks of local files. Otherwise we get duplicate
          ;; entries opening symlinks.
          doom--recent-file-truename
          ;; Replace $HOME with ~, which is more portable, and reduces how much
          ;; horizontal space the recentf listing uses to list recent files.
          abbreviate-file-name)
        recentf-auto-cleanup 'never)
  (general-add-hook 'kill-emacs-hook #'recentf-cleanup)
  (general-add-hook
   '(on-switch-window-hook write-file-functions)
   (progn (defun doom--recentf-touch-buffer-h ()
            "Bump file in recent file list when it is switched or written to."
            (when buffer-file-name
              (recentf-add-file buffer-file-name))
            ;; Return nil for `write-file-functions'
            nil)
          #'doom--recentf-touch-buffer-h))
  )

;; * Project
(general-spc
  "p" #'project-find-file
  "P" #'project-find-file-in
  "-" #'project-dired)

;; * LSP

(use-package eglot
  :ensure t
  :hook
  ((js-mode
    typescript-mode
    typescript-tsx-mode) . eglot-ensure)
  :config
  (cl-pushnew '((js-base-mode typescript-mode typescript-tsx-mode) . ("typescript-language-server" "--stdio"))
              eglot-server-programs
              :test #'equal))

;; * Embark
(defconst noct-minibuffer-maps
  '(minibuffer-local-map
    minibuffer-local-ns-map
    minibuffer-local-completion-map
    minibuffer-local-must-match-map
    minibuffer-local-isearch-map
    evil-ex-completion-map)
  "List of minibuffer keymaps.")

(use-package embark
  :after minibuffer
  :bind (("M-SPC" . embark-act))
  :general (:keymaps noct-minibuffer-maps
                     "C-l" #'embark-become
                     "M-c" #'embark-export))
(use-package embark-consult
  :config
  (define-key embark-region-map (kbd "M-U") '0x0-upload-text)
  (define-key embark-file-map (kbd "M-U") '0x0-upload-file)


  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

  
 
;; * Indent?

(defvar doom-detect-indentation-excluded-modes '(fundamental-mode so-long-mode)
  "Major modes for which indentation should not be automatically detected.")

(defvar-local doom-inhibit-indent-detection nil
  "A buffer-local flag that indicates whether `dtrt-indent' should be used.
This should be set by editorconfig if it successfully sets
indent_style/indent_size.")

(defun doom-detect-indentation-h ()
  (unless (or (not after-init-time)
              doom-inhibit-indent-detection
              doom-large-file-p
              (memq major-mode doom-detect-indentation-excluded-modes)
              (member (substring (buffer-name) 0 1) '(" " "*"))
              (not (derived-mode-p 'prog-mode)))
    (dtrt-indent-mode +1)))


(use-package dtrt-indent
  :ghook ('(change-major-mode-after-body-hook read-only-mode-hook)
          'doom-detect-indentation-h)
  ;; TODO fix
  :blackout " ›"
  :config
  ;; Enable dtrt-indent even in smie modes so that it can update `tab-width',
  ;; `standard-indent' and `evil-shift-width' there as well.
  (setq dtrt-indent-run-after-smie t)
  ;; Reduced from the default of 5000 for slightly faster analysis
  (setq dtrt-indent-max-lines 2000)

  ;; always keep tab-width up-to-date
  (push '(t tab-width) dtrt-indent-hook-generic-mapping-list)

  (defvar dtrt-indent-run-after-smie)
  (defun doom--fix-broken-smie-modes-a (orig-fn arg)
    "Some smie modes throw errors when trying to guess their indentation.
One example is `nim-mode'. This prevents them from leaving Emacs in a broken
state."
    (let ((dtrt-indent-run-after-smie dtrt-indent-run-after-smie))
      (cl-letf* ((old-smie-config-guess (symbol-function 'smie-config-guess))
                 (old-smie-config--guess
                  (symbol-function 'symbol-config--guess))
                 ((symbol-function 'symbol-config--guess)
                  (lambda (beg end)
                    (funcall old-smie-config--guess beg (min end 10000))))
                 ((symbol-function 'smie-config-guess)
                  (lambda ()
                    (condition-case e (funcall old-smie-config-guess)
                      (error (setq dtrt-indent-run-after-smie t)
                             (message "[WARNING] Indent detection: %s"
                                      (error-message-string e))
                             (message "")))))) ; warn silently
        (funcall orig-fn arg))))

  (general-add-advice 'dtrt-indent-mode :around #'doom--fix-broken-smie-modes-a))

(use-package gptel
  :config
  (setq gptel-default-mode 'org-mode)
  
;; * notmuch
(use-package notmuch
  :bind
  ("C-x m" . 'notmuch)
  :config
  (setq notmuch-saved-searches '((:name "seen inbox" :query "tag:inbox and -tag:unread" :key [105])
     (:name "unread inbox" :query "tag:inbox and tag:unread" :key [117])
     (:name "flagged" :query "tag:flagged" :key [102])
     (:name "sent" :query "tag:sent" :key [116])
     (:name "drafts" :query "tag:draft" :key [100])
     (:name "all mail" :query "*" :key [97])))
  (setq-default notmuch-search-oldest-first nil))
;; * 0x0
(use-package 0x0
  :ensure t
  :commands (0x0-upload 0x0-dwim)
  :bind ("C-x M-U" . 0x0-dwim))
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("cdad4e5bc718111deb1f1a2a35e9781e11724144a1eb2064732c337160946760" default))
 '(elfeed-feeds
   '("https://drewdevault.com/blog/index.xml" "https://drewdevault.com"))
 '(notmuch-saved-searches
   '((:name "seen inbox" :query "tag:inbox and -tag:unread" :key [105])
     (:name "unread inbox" :query "tag:inbox and tag:unread" :key [117])
     (:name "flagged" :query "tag:flagged" :key [102])
     (:name "sent" :query "tag:sent" :key [116])
     (:name "drafts" :query "tag:draft" :key [100])
     (:name "all mail" :query "*" :key [97])))
 '(notmuch-show-logo nil)
 '(org-agenda-files '("~/TODO.org"))
 '(safe-local-variable-values '((eval outline-hide-sublevels 5)))
 '(send-mail-function 'mailclient-send-it))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

;; * EAT
(use-package eat
  :ensure
  (:host codeberg
   :repo "akib/emacs-eat"
   :files ("*.el" ("term" "term/*.el") "*.texi"
           "*.ti" ("terminfo/e" "terminfo/e/*")
           ("terminfo/65" "terminfo/65/*")
           ("integration" "integration/*")
           (:exclude ".dir-locals.el" "*-tests.el")))
  :hook ((eshell-mode . eat-eshell-mode))
  ;;        (eat-mode . my/eat-keys))
  :config
  (setq eat-kill-buffer-on-exit t))

;; * ACE-WINDOW
(use-package ace-window
  :config
  (setq aw-dispatch-always t)
  :bind
  ("C-x o" . 'ace-window))

(defvar-keymap isearch-repeat-map
    :repeat (:exit (my/avy-isearch))
    "s" #'isearch-repeat-forward
    "r" #'isearch-repeat-backward
    "f" #'my/avy-isearch)

;; * Markdown mode
(use-package mardown-mode)
;; * next-error (credit karthink)
(use-package simple
  :ensure nil
  :hook (next-error . recenter)
  :config
  (defcustom my-next-error-functions nil
    "Additional functions to use as `next-error-function'."
    :group 'next-error
    :type 'hook)
  
  (defun my-next-error-delegate (orig-fn &optional arg reset)
    (if my-next-error-functions
        (if-let* ((buf (ignore-errors (next-error-find-buffer t)))
                  ((get-buffer-window buf)))
            (funcall orig-fn arg reset)
          (run-hook-with-args-until-success
           'my-next-error-functions (or arg 1)))
      (funcall orig-fn arg reset)))
  
  (defun my-next-error-register (fn)
    "Add FUN to `my-next-error-functions'."
    (lambda ()
      (if (memq fn my-next-error-functions)
          (remove-hook 'my-next-error-functions fn 'local)
        (add-hook 'my-next-error-functions fn nil 'local))))
  
  (advice-add 'next-error :around #'my-next-error-delegate)
  
  (setq next-error-message-highlight t
        next-error-found-function #'next-error-quit-window))
;; * flymake
(use-package flymake
  :defer
  :blackout t
  :config
  (add-hook 'flymake-mode-hook
            (my-next-error-register 'flymake-goto-next-error)))

;; * activitywatch
(use-package activity-watch-mode
  :blackout t
  :config
  :init (global-activity-watch-mode 1))

;; * outline stuff
;; Local Variables:
;; outline-regexp: ";; \\*+"
;; page-delimiter: ";; \\**"
;; eval:(outline-minor-mode 1)
;; eval:(outline-hide-sublevels 5)
;; End:
