;;; byok.el --- BYOK Device access library -*- lexical-binding: t; -*-

;; Author: Watts Martin <watts@coyotetracks.org>
;; URL: https://github.com/chipotle/byok.el
;; Version: 0.5.0

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; byok.el provides functions and a transient menu for working
;; with a BYOK device (https://byok.io).

;;; Code:

(defun byok-copy-file-to-device ()
  "Copy current file to mounted BYOK device."
  (interactive)
  (byok-confirm-mounted)
  (save-buffer)
  (let*
      ((file-name (byok-file-name))
       (file-path (concat (byok-directory) "/" file-name)))
    (make-directory (byok-directory) t)
    (when (and (file-exists-p file-path) (eq byok-backup-on-device t))
      (copy-file file-path (concat file-path "~") t))
    (copy-file buffer-file-name file-path t)
    (message "Copied to BYOK (%s > %s)" (byok-project-name) file-name)))


(defun byok-copy-file-from-device ()
  "Copy matching file from mounted BYOK device to current buffer."
  (interactive)
  (byok-confirm-mounted)
  (let*
      ((file-name (byok-file-name))
       (file-path (concat (byok-directory) "/" file-name)))
    (byok-confirm-file-exists file-name)
    (save-buffer)
    (byok-backup)
    (insert-file-contents file-path nil nil nil t)
    (message "Copied from BYOK (%s > %s)" (byok-project-name) file-name)))

(defun byok-diff-files ()
  "Diff current file with matched file on BYOK device."
  (interactive)
  (byok-confirm-mounted)
  (let*
      ((file-name (byok-file-name))
       (file-path (concat (byok-directory) "/" file-name)))
    (byok-confirm-file-exists file-name)
    (ediff-files file-path buffer-file-name)))


(defun byok-copy-subtree-to-device ()
  "Copy current subtree to mounted BYOK device."
  (interactive)
  (byok-confirm-mounted)
  (let*
      ((file-name (concat (byok-get-heading) ".txt"))
       (file-path (concat (byok-directory) "/" file-name)))
    (make-directory (byok-directory) t)
    (when (and (file-exists-p file-path) (eq byok-backup-on-device t))
      (copy-file file-path (concat file-path "~") t))
    (save-mark-and-excursion
      (byok-mark-subtree)
      (write-region (region-beginning) (region-end) file-path
                    nil nil nil nil))
    (message "Copied to BYOK (%s > %s)" (byok-project-name) file-name)))


(defun byok-copy-subtree-from-device ()
  "Copy matching file from mounted BYOK device to current subtree."
  (interactive)
  (byok-confirm-mounted)
  (let*
      ((file-name (concat (byok-get-heading) ".txt"))
       (file-path (concat (byok-directory) "/" file-name)))
    (byok-confirm-file-exists file-name)
    (save-buffer)
    (byok-backup)
    (byok-mark-subtree)
    (delete-region (region-beginning) (region-end))
    (insert-file-contents file-path)
    (message "Copied from BYOK (%s > %s)"
             (byok-project-name) file-name)))


(defun byok-diff-subtrees ()
  "Diff current subtree with matched file on BYOK device."
  (interactive)
  (byok-confirm-mounted)
  (let*
      ((file-name (concat (byok-get-heading) ".txt"))
       (file-path (concat (byok-directory) "/" file-name)))
    (byok-confirm-file-exists file-name)
    (byok-narrow-to-subtree)
    (ediff-buffers
     (find-file-noselect file-path)
     (current-buffer))))


(defun byok-unmount ()
  "Unmount BYOK device."
  (interactive)
  (byok-confirm-mounted)
  (shell-command byok-unmount-command))


(defun byok-projects-directory ()
  "Open BYOK top-level Projects directory."
  (interactive)
  (byok-confirm-mounted)
  (dired (concat byok-path "/Projects/")))


;; Helper functions

(defun byok-project-name ()
  "Return project name."
  (car (last (split-string default-directory "/" t))))

(defun byok-file-name ()
  "Return file name on BYOK."
  (concat
   (file-name-sans-extension (file-name-nondirectory buffer-file-name))
   ".txt"))

(defun byok-directory ()
  "Return project directory on BYOK."
  (concat byok-path "/Projects/" (byok-project-name)))

(defun byok-confirm-mounted ()
  "Confirm the BYOK device is mounted."
  (unless (file-exists-p byok-path)
    (user-error "BYOK device does not appear to be mounted")))

(defun byok-confirm-file-exists (file-name)
  "Confirm file FILE-NAME exists on the BYOK."
  (unless (file-exists-p (concat (byok-directory) "/" file-name))
    (user-error (message "File '%s' does not exist on BYOK." file-name))))

(defun byok-buffer-has-subtree ()
  "Confirm the current buffer has subtree capability."
  (unless (or (eq major-mode 'org-mode) (eq major-mode 'markdown-mode))
    (user-error "Subtree commands require Org or Markdown mode")))

(defun byok-backup ()
  "Backup file on system based on setting."
  (if (eq byok-backup-on-system t)
      (copy-file buffer-file-name (concat buffer-file-name "~") t)
    (backup-buffer)))

(defun byok-mark-subtree ()
  "Mark the current subtree."
  (if (eq major-mode 'org-mode)
      (org-mark-subtree)
    (markdown-mark-subtree)))

(defun byok-narrow-to-subtree ()
  "Narrow to the current subtree."
  (if (eq major-mode 'org-mode)
      (org-narrow-to-subtree)
    (markdown-narrow-to-subtree)))

(defun byok-get-heading ()
  "Get the heading of the current subtree."
  (let
      ((heading-text
        (if (eq major-mode 'org-mode)
            (substring-no-properties (org-get-heading))
          (save-mark-and-excursion
            (markdown-back-to-heading t)
            (when (looking-at markdown-regex-header)
              (or (match-string-no-properties 1)
                  (match-string-no-properties 5)))))))
    (replace-regexp-in-string "[,?/*\[&`()]" "" heading-text)))


;;; Customizable options

(defgroup byok nil "BYOK Device Access Functions.")

(defcustom byok-path "/Volumes/BYOK"
  "Path BYOK is mounted on."
  :type 'directory
  :group 'byok)

(defcustom byok-backup-on-system nil
  "Make explicit backups when copying from BYOK to your system.

When this is set to 't', a backup (ending in '~') will be made of
the file on your system before copying from the BYOK. If it is
set to 'nil', the 'backup-buffer' function will be called
instead; the effect of this depends on your configuration.

Note that when enabled, this always backs up the entire file,
even if you are using the subtree command."
  :type 'boolean
  :group 'byok)

(defcustom byok-backup-on-device nil
  "Make explicit backups when copying from your system to BYOK.

When set to 't', a backup file (ending in '~') will be made on
the BYOK before copying from the system. These files cannot be
accessed on the device, but can be accessed in the Projects
directory when the device is mounted."
  :type 'boolean
  :group 'byok)

(defcustom byok-unmount-command "diskutil eject /Volumes/BYOK"
  "Command to use to unmount/eject BYOK device."
  :type 'string
  :group 'byok)


;;; Define BYOK transient menu

(transient-define-prefix byok-menu ()
  ["BYOK whole file operations"
   ("t" "Copy file from Emacs to BYOK" byok-copy-file-to-device)
   ("f" "Copy file from BYOK to Emacs" byok-copy-file-from-device)
   ("d" "Ediff BYOK and Emacs file versions" byok-diff-files)]

  ["BYOK subtree (chapter/heading) operations"
   ("s" "Copy subtree from Emacs to BYOK" byok-copy-subtree-to-device)
   ("r" "Copy subtree from BYOK to Emacs" byok-copy-subtree-from-device)
   ("e" "Ediff BYOK and Emacs subtree versions" byok-diff-subtrees)]

  ["Utilities"
   ("p" "Open BYOK Projects directory" byok-projects-directory)
   ("u" "Unmount/eject BYOK" byok-unmount)])

(keymap-set text-mode-map "C-c b" #'byok-menu)

(provide 'byok)
;;; byok.el ends here
