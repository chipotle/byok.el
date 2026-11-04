;; byok.el - BYOK Device access library
;; Watts Martin, November 2026 (version 0.5)


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
    (org-narrow-to-subtree)
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
  (car (last (split-string default-directory "/" t))))

(defun byok-file-name ()
  (concat
   (file-name-sans-extension (file-name-nondirectory buffer-file-name))
   ".txt"))

(defun byok-directory ()
  (concat byok-path "/Projects/" (byok-project-name)))

(defun byok-confirm-mounted ()
  (unless (file-exists-p byok-path)
    (user-error "BYOK device does not appear to be mounted.")))

(defun byok-confirm-file-exists (file-name)
  (unless (file-exists-p (concat (byok-directory) "/" file-name))
    (user-error (message "File '%s' does not exist on BYOK." file-name))))

(defun byok-buffer-has-subtree ()
  (unless (or (eq major-mode 'org-mode) (eq major-mode 'markdown-mode))
    (user-error "Subtree commands require Org or Markdown mode.")))

(defun byok-backup ()
  (if (eq byok-backup-on-system t)
      (copy-file buffer-file-name (concat buffer-file-name "~") t)
    (backup-buffer)))

(defun byok-mark-subtree ()
  (if (eq major-mode 'org-mode)
      (org-mark-subtree)
    (markdown-mark-subtree)))

(defun byok-get-heading ()
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

;; Customizable options

(defgroup byok nil "BYOK Device Syncing")

(defcustom byok-path "/Volumes/BYOK"
  "Path BYOK Device is mounted on."
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

;; Keyboard mappings

(transient-define-prefix byok-menu ()
  ["BYOK whole file operations"
   ("t" "Copy current file to device" byok-copy-file-to-device)
   ("f" "Copy matching file from device to current buffer" byok-copy-file-from-device)
   ("d" "Ediff system file and device file" byok-diff-files)]

  ["BYOK subtree (chapter/heading) operations"
   ("s" "Copy current subtree to file on device" byok-copy-subtree-to-device)
   ("r" "Copy current subtree from device to buffer" byok-copy-subtree-from-device)
   ("e" "Ediff current subtree and device file" byok-diff-subtrees)]

  ["Utilities"
   ("p" "Open BYOK top-level projects directory" byok-projects-directory)
   ("u" "Unmount/eject BYOK device" byok-unmount)])

(keymap-set text-mode-map "C-c b" #'byok-menu)
