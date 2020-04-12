
$BACKUPSRV = $env:BACKUPSRV
$ostemp = [string] [IO.Path]::GetTempPath().ToString()
if (-not $BACKUPSRV) {
    Write-Error "Missing enviorment variable: BACKUPSRV"
    exit 1
}
$utime = Get-Date -UFormat %s -Millisecond 0
$basename = "kbxc-snapshot-$utime"
$tmpdir = New-Item -ItemType 'directory' -Name $basename -Path $ostemp
$archive = "$basename.tar.gz"
$defaultkbxpath = "$HOME/Documents/Passwords.kdbx"
$snapshotpath = "./keepassxc-snapshots"

Write-Host "Building $archive and uploading it to $BACKUPSRV @ $snapshotpath"
Copy-Item "$defaultkbxpath" "$tmpdir/Passwords.kdbx" && tar -czvf "$archive" -C "$tmpdir" . && ssh "$BACKUPSRV" mkdir -p "$snapshotpath" && scp "$archive" "${BACKUPSRV}:${snapshotpath}"
Write-Host "===> Done!"
