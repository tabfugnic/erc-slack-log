`erc-slack-log` is an [ERC](https://www.gnu.org/software/emacs/manual/html_mono/erc.html) plugin that allows [Slack](https://slack.com/) users to retrieve the history of the channels they subscribe to and give them context.

It connects via the [Slack API](https://api.slack.com/) and retrieves the last 100 lines written in that slack channel.

## Installation

Add `erc-slack-log.el` to your load path and enable it.

```emacs
(require 'erc-slack-log)
(erc-slack-log-enable)
```
That's it!

## Configuration

In order to use this you will need to specify the correct Slack organization and provide a web token.

You can get a web token by going to [Slack Web](https://api.slack.com/web) and issuing a token for that organization. You will need a different token for each organization.

Currently the only way to configure this is by adding your token directly to the `erc-slack-log-server-list`. It is a simple plist structure. For example:

```emacs
(setq erc-slack-log-server-list
      '("org-subdomain1" (token "org-subdomain1-token")
        "org-subdomain2" (token "org-subdomain2-token")))
```

__NOTE:__ This will be able to be setup using authsource soon.
