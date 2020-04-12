
$srv = $env:BACKUPSRV
if (-not $srv) {
    Write-Error "Missing enviorment variable: BACKUPSRV"
    exit 1
}

$snapshotdir = "keepassxc-snapshots"
$awkscript = '{print $9}'
$latestremote = "ls --full-time -c $snapshotdir | tail -n 1 | awk '$awkscript'"
Write-Host "Query for the latest kbdbx backup from $srv"
$remotefile = $(ssh $srv $latestremote)
Write-Host "Latest Snapshot is $remotefile"
scp "${srv}:$snapshotdir/${remotefile}" "$PWD"
tar xvzf "$PWD/$remotefile"
Remove-Item "$PWD/$remotefile"
Write-Host "===> Done!"
