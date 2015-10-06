;;; erc-slack-log-test.el --- Test suite for erc-slack-log

;; Author: Eric J. Collins <eric@tabfugni.cc>
;; Keywords: irc, test
;; URL: https://github.com/tabfugnic/erc-slack-log/erc-slack-log-test.el

;; This file is NOT part of GNU Emacs.

;;; Commentary:

;; simple unit test suite for the erc-slack-log ERC plugin

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

(load-file "./erc-slack-log.el")
(require 'erc-slack-log)
(require 'ert)

(ert-deftest erc-slack-log-history-url-test ()
    (should
     (equal
      (erc-slack-log-history-url 5 "foo")
      "https://slack.com/api/channels.history?token=foo&channel=5")))

(ert-deftest erc-slack-log-users-url-test ()
    (should
     (equal
      (erc-slack-log-users-url "foo")
      "https://slack.com/api/users.list?token=foo")))

(ert-deftest erc-slack-log-channels-url-test ()
  (should
   (equal
    (erc-slack-log-channels-url "foo")
    "https://slack.com/api/channels.list?token=foo")))

(ert-deftest erc-slack-log-find-users-test ()
  (setq erc-slack-log-server-list '("server" (token "foo")))
  (flet
      ((erc-slack-log-retrieve-users (token) (erc-slack-log-users-stub)))
    (erc-slack-log-find-users "server.slack.irc" 2000 "gnu")
    (message "%s" (car erc-slack-log-server-list))
    (should
     (equal
      erc-slack-log-server-list
      '("server"
        (token "foo"
         users (((name . "Person") (id . "100"))
                ((name . "Another Person") (id . "200")))))))))

(ert-deftest erc-slack-log-find-channels-test ()
  (setq erc-slack-log-server-list '("server" (token "foo")))
  (flet
      ((erc-slack-log-retrieve-channels (token) (erc-slack-log-channels-stub)))
    (erc-slack-log-find-channels "server.slack.irc" 2000 "gnu")
    (message "%s" (car erc-slack-log-server-list))
    (should
     (equal
      erc-slack-log-server-list
      '("server"
        (token "foo"
         channels (((name . "emacs") (id . "100"))
                   ((name . "general") (id . "200")))))))))

(ert-deftest erc-slack-log-post-messages-test ()
  (setq erc-server-process "erc-server-6667")
  (flet
      ((erc-slack-log-current-server-data ()
        '(token "foo"
           users (((name . "Person") (id . "100")))
           channels (((name . "emacs") (id . "100")))))
       (erc-slack-log-retrieve-messages (unparsed-json)
                                        (erc-slack-log-messages-stub))
       (erc-display-line (string buffer-name)
                         (setq last-message
                               (format "%s on %s" string buffer-name))))
    (erc-slack-log-post-messages)
    (should
     (equal
      last-message
      "<Person> what a great editor on  *temp*"))))

(ert-deftest erc-slack-log-channel-id-test ()
  (setq erc-server-process "erc-server-6667")
  (cl-letf
      (((symbol-function 'buffer-name) #'(lambda () "#emacs<2>")))
    (message "%s" (buffer-name))
    (should
     (equal
      (erc-slack-log-channel-id
       '(channels
         (((name . "emacs") (id . "100"))
          ((name . "general")(id . "200")))))
      "100"))))

(defun erc-slack-log-users-stub ()
  '(((name . "Person") (id . "100")) ((name . "Another Person")(id . "200"))))

(defun erc-slack-log-channels-stub ()
  '(((name . "emacs") (id . "100")) ((name . "general")(id . "200"))))

(defun erc-slack-log-user-stub()
  '((name . "Person") (id . "100")))

(defun erc-slack-log-messages-stub ()
  '(((user . "100") (text . "what a great editor"))
    ((user . "100") (subtype . "does not matter") (text . "hey hey!"))))

;;; erc-slack-log-test.el ends here
