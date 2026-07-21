#!/bin/sh
# Bootstrap doesn't need SSH (externals use HTTPS), but pushing to GitHub does.
# This only prints a reminder — it never fails the apply.

has_ssh_key() {
  for f in "$HOME"/.ssh/id_*.pub; do
    [ -e "$f" ] && return 0
  done
  return 1
}

has_1password_agent() {
  # Mac and Linux socket locations
  [ -S "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ] && return 0
  [ -S "$HOME/.1password/agent.sock" ] && return 0
  return 1
}

if ! has_ssh_key && ! has_1password_agent; then
  echo ""
  echo "==> Reminder: no SSH key or 1Password SSH agent found."
  echo "    You'll need one to push to GitHub. Recommended:"
  echo "    1Password -> Settings -> Developer -> enable SSH agent,"
  echo "    then add the key at https://github.com/settings/keys"
fi

exit 0
