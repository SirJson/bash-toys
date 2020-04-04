#!/bin/bash

tmpdir=$(mktemp -d)
utime=$(date +%s)
archive="kbxc-snapshot-$utime.tar.gz"
defaultkbxpath="$HOME/Documents/Passwords.kdbx"
snapshotpath="./keepassxc-snapshots"

cp -v "$defaultkbxpath" "$tmpdir/Passwords.kdbx" && tar -czvf "$archive" -C "$tmpdir" . && ssh "$BACKUPSRV" mkdir -p "$snapshotpath" && scp "$archive" "$BACKUPSRV":"$snapshotpath"
