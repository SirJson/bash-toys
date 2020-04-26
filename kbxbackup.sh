#!/bin/bash
# shellcheck disable=SC2016
set -Euo pipefail
_DEBUGPIPE=''

if [[ -f "$HOME/.bashdebug" ]]; then
    _DEBUGPIPE=$(mktemp)
    echo "Started in Debug mode!"
    echo "Debug pipe: $_DEBUGPIPE"
    _trace_handler() {
        if [[ ! -p $_DEBUGPIPE ]]; then
            mkfifo "$_DEBUGPIPE"
        fi
        echo -e "\n[DBG]\t$BASH_COMMAND" &>"$_DEBUGPIPE"
    }
    set -o functrace
    trap '_trace_handler' DEBUG
fi

_fail() {
    printf '\e[0m'
    printf '\n\e[31m%s\e[0m\n' "FAIL: $1"
    exit 1
}

_terminate_handler() {
    _fail "Caught terminate signal"
}

_error_handler() {
    ORIGIN=$1
    ERRNO=$2
    _fail "Command '$ORIGIN' failed. ($ERRNO)"
}

trap '_terminate_handler' SIGINT SIGTERM
trap '_error_handler $BASH_COMMAND $?' ERR

if [[ -z $BACKUPSRV ]]; then
    echo "Can't backup KeePassXC database without BACKUPSRV set"
fi

reset() {
    printf '\e[0m'
}

info() {
    printf '\e[35m%s\e[0m\n' "- $1"
}

execinfo() {
    printf '\t\e[33m%s\e[0m\n' "> $1"
}

pok() {
    printf '\t\e[32m%s\e[0m\n' "+ OK"
}

line() {
    printf '\e[35m%s\e[0m\n' "-----"
}

_tmpdir=$(mktemp -d)
_defaultkbxpath=${1:-"$HOME/Documents/Passwords.kdbx"}
_snapshotpath="./keepassxc-snapshots"
_tstmp=$(date +%s)
_arc="kbxc-snapshot-$_tstmp.tar.gz"

desc=('Copy database to temporary work path' 'Building upload archive' 'Ensure target directory exists' 'Copy database to backup server')
step=("cp -v $_defaultkbxpath $_tmpdir/Passwords.kdbx" "tar -czvf $_arc -C $_tmpdir ." "ssh $BACKUPSRV -- mkdir -pv $_snapshotpath" "scp $_arc $BACKUPSRV:$_snapshotpath")

startmsg="$(basename "$0")
    > Creating backup of '$_defaultkbxpath'
    > Backup path: '$BACKUPSRV:$_snapshotpath'"
line
echo "$startmsg"
line

total=${#step[*]}
info "Total steps: $total"
#
for (( i=0; i<=$(( total -1 )); i++ ))
do
    line
    info "${desc[$i]}"
    sc=${step[$i]}
    execinfo "$sc"
    $sc
    pok
done
