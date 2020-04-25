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

_box_out_ml() {
    local s=("$@")
    local b=''
    local w=''
    local boxcolor=73
    for l in "${s[@]}"; do
        ((w < ${#l})) && {
            b="$l"
            w="${#l}"
        }
    done
    tput setaf $boxcolor
    echo "┏━${b//?/━}━┓
┃ ${b//?/ } ┃"
    for l in "${s[@]}"; do
        printf '┃ %s%*s%s ┃\n' "$(tput setaf 7)" "$w" "$l" "$(tput setaf $boxcolor)"
    done
    echo "┃ ${b//?/ } ┃
┗━${b//?/━}━┛"
    tput sgr 0
}

_box_out() {
    local boxcolor=11
    local s="$*"
    tput setaf $boxcolor
    printf "%s\n" "┏━${s//?/━}━┓
┃ $(tput setaf 7)$s$(tput setaf $boxcolor) ┃
┗━${s//?/━}━┛"
}

mkbackup() {
    tmpdir=$(mktemp -d)
    extlist=$(mktemp)
    utime=$(date +%s)
    kname=$(uname -s | tr '[:upper:]' '[:lower:]')
    krelease=$(uname -r | tr '[:upper:]' '[:lower:]')
    archive="vscode-config-$kname-$krelease-$utime.tar.gz"
    snapshotpath="./vscode-configs"
    settingssrc="$HOME/.config/Code/User/settings.json"
    keybindingssrc="$HOME/.config/Code/User/keybindings.json"

    desc=('-> Copy extensions' '-> Copy settings' '-> Copy keybindings' '-> Create upload archive' '-> Ensure target directory exists' '-> Move archive to backup server' '-> Cleanup')
    step=("cp -v $extlist $tmpdir/extensions.list" "cp -v $keybindingssrc $tmpdir/settings.json" "cp -v $settingssrc $tmpdir/keybindings.json" "tar -czvf $archive -C $tmpdir ." "ssh $BACKUPSRV -- mkdir -pv $snapshotpath" "scp $archive $BACKUPSRV:$snapshotpath" "rm $archive")
    code --list-extensions &>"$extlist"
    _box_out_ml "VSCode Backup" " " " => Backup path: '$BACKUPSRV:$snapshotpath'"

    total=${#step[*]}
    info "Total steps: $total"
    #
    for ((i = 0; i <= $((total - 1)); i++)); do
        _box_out "${desc[$i]}"
        sc=${step[$i]}
        execinfo "$sc"
        reset
        $sc
        pok
    done
}


mkbackup

#TODO: Allgemeines backupscript