;;; rc-twittering.el ---                             -*- lexical-binding: t; -*-

;;======================================================
;;Twittering-mode:用Emacs上Twitter
;;======================================================
(add-to-list 'load-path "~/.emacs.d/git/twittering-mode/")
(require 'twittering-mode)
(setq twittering-use-master-password t) ;;This requires GnuPG. And also, either EasyPG or alpaca.el (0.13) is necessary.
(twittering-enable-unread-status-notifier) ;;顯示未讀訊息數
;;(setq-default twittering-icon-mode t) ;;預設顯示頭像

;;開啟自己的favorite timeline
(defun my-twittering-favorites-timeline ()
  (interactive)
  (twittering-visit-timeline ":favorites"))

;;(defun twittering-mode-hook-func ()
;;  (set-face-bold-p 'twittering-username-face t)
;;  (set-face-foreground 'twittering-username-face "SkyBlue3"))
;;(add-hook 'twittering-mode-hook 'twittering-mode-hook-func)


(define-key twittering-mode-map (kbd "r") 'twittering-toggle-or-retrieve-replied-statuses)
(define-key twittering-mode-map (kbd "R") 'twittering-replies-timeline)
(define-key twittering-mode-map (kbd "U") 'twittering-user-timeline)
(define-key twittering-mode-map (kbd "W") 'twittering-update-status-interactive)
(define-key twittering-mode-map (kbd "O") 'twittering-organic-retweet)
(define-key twittering-mode-map (kbd "N") 'twittering-native-retweet)
(define-key twittering-mode-map (kbd "H") 'twittering-home-timeline)
(define-key twittering-mode-map (kbd "F") 'twittering-favorite)
(define-key twittering-mode-map (kbd "V") 'twittering-visit-timeline)
(define-key twittering-mode-map (kbd "M") 'my-twittering-favorites-timeline)
(define-key twittering-mode-map (kbd "M-w") 'twittering-push-tweet-onto-kill-ring)
(define-key twittering-mode-map (kbd "C-w") 'twittering-push-uri-onto-kill-ring)
(define-key twittering-mode-map (kbd "D") 'twittering-direct-messages-timeline)
(define-key twittering-mode-map (kbd "S") 'twittering-sent-direct-messages-timeline)
(define-key twittering-mode-map (kbd "q") 'twittering-bury-main-timeline-buffer)
(define-key twittering-mode-map (kbd "[") 'twittering-switch-to-previous-timeline)
(define-key twittering-mode-map (kbd "]") 'twittering-switch-to-next-timeline)

(define-key twittering-edit-mode-map (kbd "<f4>") 'ispell-word)
(define-key twittering-edit-mode-map (kbd "C-x <f4>") 'twittering-edit-replace-at-point)

(defun twittering-bury-main-timeline-buffer ()
  "If in main timeline buffer (:home), bury-buffer.
If not, kill-buffer instead. "
  (interactive)
  (if (and (or (equal (buffer-name) ":home")
               (equal (buffer-name) ":direct_messages")
               (equal (buffer-name) ":direct_messages_sent")
               (equal (buffer-name) ":replies"))
           (eq major-mode 'twittering-mode))
      (bury-buffer)
    (kill-buffer)))


(setq twittering-status-format
      "%i %s %FACE[font-lock-comment-face]{(%S)},%FACE[font-lock-string-face]{%p} %FACE[font-lock-comment-face]{%@}:
%FOLD[  ]{%T
%FACE[font-lock-comment-face]{from %f%L%r} %FACE[font-lock-preprocessor-face]{%R} %FACE[font-lock-keyword-face]{%e} %FACE[font-lock-function-name-face]{%F}}
 ")

(setq twittering-retweet-format
      '(nil _ " RT: %t (via @%s)")
      )

(autoload 'twittering-numbering "twittering-numbering" nil t)
(add-hook 'twittering-mode-hook 'twittering-numbering)

(add-hook 'twittering-mode-hook 'auto-fill-mode)

;; ====================================================
;; Filtering for Tweets
;; ====================================================

(defvar twittering-filter-users '()
  "*List of strings containing usernames (without '@' prefix) whose tweets should not be displayed in timeline.")
(defvar twittering-filter-tweets '()
  "*List of strings containing phrases which will prevent a tweet containing one of those phrases from being displayed in timeline.")

(defun twittering-filters-apply ()
  (setq non-matching-statuses '())
  (dolist (status twittering-new-tweets-statuses)
    (setq matched-tweets 0)
    (dolist (pat twittering-filter-users)
      (if (string-match pat (cdr (assoc 'user-screen-name status)))
          (setq matched-tweets (+ 1 matched-tweets))))
    (dolist (pat twittering-filter-tweets)
      (if (string-match pat (twittering-make-fontified-tweet-text-with-entity status))
          (setq matched-tweets (+ 1 matched-tweets))))
    (if (= 0 matched-tweets)
        (setq non-matching-statuses (append non-matching-statuses `(,status)))))
  (setq new-statuses non-matching-statuses))

(add-hook 'twittering-new-tweets-hook 'twittering-filters-apply)

(setq twittering-filter-tweets
      '(
	"http://4sq.com/.*"
	"http://adf.ly/.*"
	"I liked a @YouTube video"
	"我喜歡一部 .*@YouTube 影片"
	"中時"
	"郭董"
	"nikeplus"
	"采潔"
	"羅淑蕾"
	"連勝文"
	"神豬"
	"連D"
	"蔡正元"
	"星球與廣大的銀河系！"
	))

(defalias 'short-url 'twittering-tinyurl-replace-at-point)

(defface twittering-keyword-face
  `((t (:underline t :foreground "#a40000"))) "" :group 'faces)

(font-lock-add-keywords 'twittering-mode
			'(("keyword" 0 'twittering-keyword-face)))

;; ====================================================
;; Popup notification by calling `notify-send' (reply & DM)
;; ====================================================

(add-hook 'twittering-new-tweets-hook 'twittering-my-notification)
(defun twittering-my-notification ()
  (let ((timeline-name (twittering-timeline-spec-to-string twittering-new-tweets-spec)))
    (if (member timeline-name '(":replies" ":direct_messages"))
	(let ((n twittering-new-tweets-count)
	      ;;statuses are raw data of new tweets
	      (statuses twittering-new-tweets-statuses))
	  ;; When we initialize a timeline, it fetch 20 new tweets by default.
	  ;; But we don't need this kind of notification. So:
	  (if (not (eq 20 (length statuses)))
	      (start-process "twittering-notify" nil "notify-send"
			     "-i" (expand-file-name "~/.emacs.d/icon.png")
			     "New tweets"
			     (format (cond ((string= timeline-name ":replies")
					    "%d New Reply:\n%s")
					   ((string= timeline-name ":direct_messages")
					    "%d New DM:\n%s"))
				     n
				     (twittering-my-notification-format-statuses statuses))))))))

(defun twittering-my-notification-format-statuses (statuses)
  "Format statuses for `twittering-my-notification'."
  (mapconcat
   (lambda (s) (format "%s: %s"
		   (cdr (assq 'user-screen-name s))
		   (replace-regexp-in-string "\n" "" (cdr (assq 'text s)))
		   ))
   statuses
   "\n"))

;; ====================================================
;; Press "o" to open the page of current tweet.
;; ====================================================
(defun twittering-open-tweet-page ()
  (interactive)
  (browse-url (twittering-get-status-url
	       (get-text-property (point) 'user-name)
	       (get-text-property (point) 'id))))

(define-key twittering-mode-map (kbd "o") 'twittering-open-tweet-page)

;; ====================================================
;; Auto insert all mentioned users in tweet when reply.
;; ====================================================

;; Notice: library s.el is required. It's available on MELPA.
(require 's)
(defun twittering-my-enter ()
  (interactive)
  (let ((ori-buffer (current-buffer))
	user-list)
    (funcall #'twittering-enter)
    (when (eq major-mode 'twittering-edit-mode) ;check if entered edit mode
      (with-current-buffer ori-buffer
	(setq user-list (s-match-strings-all "@[A-Za-z0-9_]+"
					     (get-text-property (point) 'text))))
      (insert (mapconcat #'car user-list " "))
      )))


;; ====================================================
;; craps
;; ====================================================

;; (load-file "~/.emacs.d/git/twittering-myfav/twittering-myfav.el")
;; (require 'twittering-myfav)
;; (setq twittering-myfav-file-name "twittering_myfav") ; The org and html file's name.
;; (setq twittering-myfav-file-path "~/Dropbox/Blog/kuanyui.github.io/source/") ; remember "/" in the end
;; (setq twittering-myfav-your-username "azazabc123") ; without "@"
;; (define-key twittering-mode-map (kbd "A") 'twittering-myfav-add-to-file)
;;
;; (defun twittering-myfav-export-to-hexo ()
;;   (interactive)
;;   (twittering-myfav-export-to-html)
;;   (write-file "~/Dropbox/Blog/kuanyui.github.io/source/twittering_myfav.html" nil)
;;   (goto-char (point-min))
;;   (insert "layout: false\n---\n\n")
;;   (save-buffer))



(provide 'rc-twittering)
;;; rc-twittering.el ends here
