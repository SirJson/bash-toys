#!/bin/bash

tmpdir=$(mktemp -d)
utime=$(date +%s)
archive="vscode-setup-$utime.tar.gz"
extlist="$tmpdir/vscode-extensions.list"
backuppath="./vscode-setups"
settingssrc="$HOME/.config/Code/User/settings.json"

echo "Writing extension list to $extlist" && code --list-extensions | xargs -L 1 echo code --install-extension >"$extlist" && cp -v "$settingssrc" "$tmpdir/settings.json" && tar -czvf "$archive" -C "$tmpdir" . && scp "$archive" "$BACKUPSRV":"$backuppath"
