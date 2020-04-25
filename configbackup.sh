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

utime=$(date +%s)
kname=$(uname -s | tr '[:upper:]' '[:lower:]')
krelease=$(uname -r | tr '[:upper:]' '[:lower:]')
tmpdir=$(mktemp -d)
tarname="config-$utime-$kname-$krelease.tar"
remotedir="./linuxconf-backups"

_box_out_ml "User config backup", "", "for .config, zsh tmux etc.."


_box_out "Build tarball"
tar --exclude-vcs --exclude-backups --acls -v -p -f "$tmpdir/$tarname" -c ~/.config ~/.z* ~/.zsh/* ~/.profile ~/.tmux* ~/.tmux/* ~/.ssh
_box_out "Compress tarball"
xz -zev --threads=0 "$tmpdir/$tarname"
_box_out "Send tarball to backup server tarball"
ssh "$BACKUPSRV" -- mkdir -pv "$remotedir"
scp "$tmpdir/$tarname.xz" "$BACKUPSRV:$remotedir"
_box_out "Cleanup"
rm "$tmpdir/$tarname.xz"