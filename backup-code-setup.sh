#!/bin/bash

tmpdir=$(mktemp -d)
utime=$(date +%s)
archive="vscode-setup-$utime.tar.gz"

echo "Writing extension list to $tmpdir/vscode-extensions.list"
code --list-extensions | xargs -L 1 echo code --install-extension > "$tmpdir/vscode-extensions.list"
cp -v ~/.config/Code/User/settings.json "$tmpdir/settings.json"
tar -czvf "$archive" -C "$tmpdir" .
scp "$archive" "$BACKUPSRV":./vscode-setups