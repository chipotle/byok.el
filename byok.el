;; byok.el - BYOK Device access library
;; Watts Martin, October 2026


(defun byok-copy-file-to-device ()
  "Copy current file to mounted BYOK device."
  (interactive)
  (byok-confirm-mounted)
  (save-buffer)
  (make-directory (byok-directory) t)
  (byok-test-newer (byok-full-path) buffer-file-name "device")
  (copy-file buffer-file-name (byok-full-path) t)
  (message "Copied to BYOK (%s > %s)" (byok-project-name) (byok-file-name)))


(defun byok-copy-file-from-device ()
  "Copy matching file from mounted BYOK device to current buffer."
  (interactive)
  (byok-confirm-mounted)
  (byok-confirm-file-exists (byok-file-name))
  (save-buffer)
  (byok-test-newer buffer-file-name (byok-full-path) "system")
  (byok-backup)
  (insert-file-contents (byok-full-path) nil nil nil t)
  (message "Copied from BYOK (%s > %s)" (byok-project-name) (byok-file-name)))


(defun byok-copy-subtree-to-device ()
  "Copy current subtree to mounted BYOK device."
  (interactive)
  (byok-confirm-mounted)
  (let*
      ((file-name (concat (org-get-heading) ".txt"))
       (file-path (concat (byok-directory) "/" file-name)))
    (make-directory (byok-directory) t)
    (byok-test-newer file-path buffer-file-name "device")
    (save-mark-and-excursion
      (org-mark-subtree)
      (write-region (region-beginning) (region-end)
                    (concat (byok-directory) "/" file-name)
                    nil nil nil nil))
    (message "Copied to BYOK (%s > %s.txt)"
             (byok-project-name)
             (substring-no-properties (org-get-heading)))))


(defun byok-copy-subtree-from-device ()
  "Copy matching file from mounted BYOK device to current subtree."
  (interactive)
  (byok-confirm-mounted)
  (let*
      ((file-name (concat (substring-no-properties (org-get-heading)) ".txt"))
       (file-path (concat (byok-directory) "/" file-name)))
    (byok-confirm-file-exists file-name)
    (save-buffer)
    (byok-test-newer buffer-file-name file-path "system")
    (byok-backup)
    (org-cut-subtree)
    (insert-file-contents file-path)
    (message "Copied from BYOK (%s > %s)"
             (byok-project-name) file-name)))


(defun byok-unmount ()
  "Unmount BYOK device."
  (interactive)
  (byok-confirm-mounted)
  (shell-command byok-unmount-command))

;; Helper functions

(defun byok-project-name ()
  (car (last (split-string default-directory "/" t))))

(defun byok-file-name ()
  (let
      ((file-name (file-name-nondirectory buffer-file-name)))
    (if (eq (substring file-name -4 nil) ".txt")
      file-name
    (concat file-name ".txt"))))

(defun byok-directory ()
  (concat byok-path "/Projects/" (byok-project-name)))

(defun byok-full-path ()
  (concat (byok-directory) "/" (byok-file-name)))

(defun byok-confirm-mounted ()
  (if (not (file-exists-p byok-path))
      (user-error "BYOK device does not appear to be mounted.")))

(defun byok-confirm-file-exists (file-name)
  (if (not (file-exists-p
            (concat (byok-directory) "/" file-name)))
      (user-error (message "File '%s' does not exist on BYOK." file-name))))

(defun byok-backup ()
  (if (eq byok-backups t)
      (copy-file buffer-file-name (concat buffer-file-name ".bak") t)
    (backup-buffer)))

(defun byok-test-newer (file1 file2 item)
  (if (file-newer-than-file-p file1 file2) ;; tests if file1 newer than file2
      (if (not (yes-or-no-p (format "File on %s is newer. Copy anyway?" item)))
          (user-error "Copy cancelled."))))

;; Customizable options

(defgroup byok nil "BYOK Device Syncing")

(defcustom byok-path "/Volumes/BYOK"
  "Path BYOK Device is mounted on."
  :type 'directory
  :group 'byok)

(defcustom byok-backups nil
  "How to make backups of documents when syncing to BYOK."
  :type '(choice (const :tag "Create .bak file" t)
                (const :tag "Use Emacs 'backup-buffer' function" nil))
  :group 'byok)

(defcustom byok-unmount-command "diskutil eject /Volumes/BYOK"
  "Command to use to unmount BYOK device."
  :type 'string
  :group 'byok)

;; Keyboard mappings

(transient-define-prefix byok-menu ()
  ["BYOK tasks"
   ("t" "Copy current file to device" byok-copy-file-to-device)
   ("f" "Copy matching file from device to buffer" byok-copy-file-from-device)
   ("s" "Copy current subtree to file on device" byok-copy-subtree-to-device)
   ("r" "Retrieve current subtree from file on device" byok-copy-subtree-from-device)
   ("u" "Unmount/eject BYOK device" byok-unmount)])

(keymap-set text-mode-map "C-c b" #'byok-menu)
