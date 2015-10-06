;;; erc-slack-log.el --- Restore slack history in ERC for context

;; Author: Eric J. Collins <eric@tabfugni.cc>
;; Version: 0.1.0
;; Keywords: irc
;; URL: https://github.com/tabfugnic/erc-slack-log/erc-slack-log.el

;; This file is NOT part of GNU Emacs.

;;; Commentary:

;; 'erc-slack-log' is an ERC plugin that helps better integrate
;; with Slack service. It uses the slack history, channel and user
;; APIs to backfill messages in ERC.

;;; License:

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'erc)
(require 'json)
(require 'cl)

(defgroup erc-slack-log nil
  "Enable slack logs"
  :group 'erc)

(define-erc-module slack-log nil
  "ERC pulls in slack users, channel information and logs"
  ((add-hook 'erc-before-connect 'erc-slack-log-find-users)
   (add-hook 'erc-before-connect 'erc-slack-log-find-channels)
   (add-hook 'erc-join-hook 'erc-slack-log-post-messages))
  ((remove-hook 'erc-before-connect 'erc-slack-log-find-users)
   (remove-hook 'erc-before-connect 'erc-slack-log-find-channels)
   (remove-hook 'erc-join-hook 'erc-slack-log-post-messages)))

(defcustom erc-slack-log-server-list nil
  "List of slack servers allowed to be used.
Each server will require a slack access token found using auth-source.
If you use ~/.authinfo for your backend then you will use the format:

machine your-server.irc.slack.com user your-server password ojpf-2312203999-23412314-1234122ac"
  :group 'erc-slack-log
  :type '(repeat (cons :tag "Server"
                       (string :tag "token"))))

(defcustom erc-slack-log-api-url "https://slack.com/api"
  "Domain that refers to main slack url."
  :group 'erc-slack-log
  :type 'string)

(defun erc-slack-log-find-users (server port nick)
  "Get Slack users for SERVER and memoize them.
PORT and NICK are not being used."
  (let ((slack-server (erc-slack-log-current-server-data server)))
    (plist-put
     slack-server
     'users
     (erc-slack-log-retrieve-users
      (plist-get slack-server 'token)))))

(defun erc-slack-log-find-channels (server port nick)
  "Get Slack channel information for SERVER and memoize them.
PORT and NICK are not being used"
  (let ((slack-server (erc-slack-log-current-server-data server)))
    (plist-put
     slack-server
     'channels
     (erc-slack-log-retrieve-channels
      (plist-get slack-server 'token)))))

(defun erc-slack-log-post-messages ()
  "Post messages to each Slack buffers.
Using the channel information and user information,
find necessary message information and place in the correct buffer."
  (let ((slack-server (erc-slack-log-current-server-data)))
    (dolist (msg
             (reverse (erc-slack-log-retrieve-messages
                       (erc-slack-log-channel-id slack-server))))
      (erc-slack-log-display-formatted-message msg))))

(defun erc-slack-log-current-server-data (&optional server-name)
  "Get current server information found in memoized server list.
Pass SERVER-NAME to pass along not yet known server buffer."
  (or server-name (setq server-name (buffer-name (erc-server-buffer))))
  (lax-plist-get
   erc-slack-log-server-list
   (car (split-string server-name "\\."))))

(defun erc-slack-log-current-token ()
  "Using server data get current token."
  (plist-get (erc-slack-log-current-server-data) 'token))

(defun erc-slack-log-channel-id (slack-server)
  "Get channel id from SLACK-SERVER alist."
  (assoc-default
   'id (erc-slack-log-find-by-name
        (erc-slack-log-channel-name)
        (lax-plist-get slack-server 'channels))))

(defun erc-slack-log-channel-name ()
  "Return properly formatted name for slack channel.
Used to get a buffer"
  (replace-regexp-in-string
   "\<.*\>$"
   ""
   (replace-regexp-in-string "^\#" "" (buffer-name))))

(defun erc-slack-log-display-formatted-message (msg)
  "Display MSG in proper Slack buffer."
  (erc-display-line
   (format
    "<%s> %s"
    (erc-slack-log-user-name (assoc-default 'user msg))
    (assoc-default 'text msg))(current-buffer)))

(defun erc-slack-log-user-name (user-id)
  "Return username of slack user based on their USER-ID."
  (assoc-default
   'name
   (erc-slack-log-find-by-id
    user-id
    (lax-plist-get (erc-slack-log-current-server-data) 'users))))

(defun erc-slack-log-retrieve-messages (channel-id)
  "Retrieve messages for channel based on CHANNEL-ID."
  (assoc-default
   'messages
   (erc-slack-log-retrieve-json-synchronously
    (erc-slack-log-history-url channel-id (erc-slack-log-current-token)))))

(defun erc-slack-log-retrieve-users (token)
  "Retrieve users of slack server.
Pass in slack TOKEN associated with API"
  (assoc-default
   'members
   (erc-slack-log-retrieve-json-synchronously
    (erc-slack-log-users-url token))))

(defun erc-slack-log-retrieve-channels (token)
  "Retrieve channels of slack server.
Pass in slack TOKEN associated with API"
  (assoc-default
   'channels
  (erc-slack-log-retrieve-json-synchronously
   (erc-slack-log-channels-url token))))

(defun erc-slack-log-retrieve-json-synchronously (url)
  "Synchronous URL request and read results."
  (with-current-buffer (url-retrieve-synchronously url)
    (goto-char (point-min))
    (search-forward "\n\n")
    (delete-region (point-min) (point))
    (let ((json-array-type 'list))
      (json-read))))

(defun erc-slack-log-history-url (channel-id token)
  "Slack history url using CHANNEL-ID and TOKEN."
  (format "%s/channels.history?token=%s&channel=%s"
          erc-slack-log-api-url
          token
          channel-id))

(defun erc-slack-log-users-url (token)
  "Slack users url using TOKEN."
  (format "%s/users.list?token=%s" erc-slack-log-api-url token))

(defun erc-slack-log-channels-url (token)
  "Slack channels url using TOKEN."
  (format "%s/channels.list?token=%s" erc-slack-log-api-url token))

(defun erc-slack-log-find-by-id (id seq)
  "Generic find by ID in SEQ."
  (car (remove-if-not
   (lambda (elem)(equal (assoc-default 'id elem) id))
   seq)))

(defun erc-slack-log-find-by-name (name seq)
  "Generic find by NAME in SEQ."
  (car (remove-if-not
   (lambda (elem)(equal (assoc-default 'name elem) name))
   seq)))

(provide 'erc-slack-log)

;;; erc-slack-log.el ends here
