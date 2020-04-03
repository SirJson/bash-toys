#!/bin/bash
# shellcheck disable=SC2068
set -Euo pipefail
_DEBUGPIPE=''

# https://stackoverflow.com/questions/59895/how-to-get-the-source-directory-of-a-bash-script-from-within-the-script-itself
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

_EUP="🆙"
_ESOS="🆘"
_ESPEAK="🗩"
_ENOMOBILE="📵"
_ESATELITE="📡"
_MSGPRE="⮞"

if [[ -f "/tmp/.bashdbg" ]]; then
    _DEBUGPIPE=$(mktemp)
    echo "Started in Debug mode!"
    echo "Reason: .bashdbg exists in /tmp"
    echo "Debug pipe: $_DEBUGPIPE"
    _trace_handler() {
        if [[ ! -p $_DEBUGPIPE ]]; then
            mkfifo "$_DEBUGPIPE"
        fi
        echo -e "\n[DBG]➜\t$BASH_COMMAND" &>"$_DEBUGPIPE"
    }
    set -o functrace
    trap '_trace_handler' DEBUG
fi

_fail() {
    printf '\e[0m'
    printf '\n\e[38;2;200;0;0m%s\e[0m\n' "FAIL: $1"
    exit 1
}

_info() {
    printf '\e[0m'
    printf '\e[38;2;0;200;0m %s %s  %s\e[0m\n' "$_MSGPRE" "$_ESPEAK" "$1"
}

_warn() {
    printf '\e[0m'
    printf '\e[38;2;200;0;0m %s %s %s\e[0m\n' "$_MSGPRE" "$_ESOS" "$1"
}

_satelite() {
    printf '\e[0m'
    printf '\e[38;2;200;200;200m %s %s %s\e[0m\n' "$_MSGPRE" "$_ESATELITE" "$1"
}

_safe() {
    printf '\e[0m'
    printf '\e[38;2;125;17;114m %s %s %s\e[0m\n' "$_MSGPRE" "$_ENOMOBILE" "$1"
}

_upmsg() {
    printf '\e[0m'
    printf '\e[38;2;0;200;0m %s %s %s\e[0m\n' "$_MSGPRE" "$_EUP" "$1"
}

_important() {
    local epower="🗲"
    printf '\e[0m'
    printf '\e[38;2;239;220;5m %s %s %s\e[0m\n' "$epower" "$1" "$epower"
}

_terminate_handler() {
    _fail "Caught terminate signal"
}

_error_handler() {
    ORIGIN=$1
    ERRNO=$2
    printf '\e[0m'
    printf '\n\e[1m\e[48;2;236;240;241m\e[38;2;200;0;0m %s \e[0m' "!! > Internal failure. Command '$ORIGIN' failed with $ERRNO"
    printf '\n'
    exit 1
}

trap '_terminate_handler' SIGINT SIGTERM
trap '_error_handler $BASH_COMMAND $?' ERR

OPTIND=1 # Reset in case getopts has been used previously in the shell.
HOST_NAMES=$(awk -F '=' '{ print $1 }' < sbc.list)

_sbcip()
{
    grep $1 < sbc.list | awk -F '=' '{ print $2 }'
}

_online() {
    _satelite "Check if $1 can be reached..."
    local ip=$(_sbcip "$1")
    if ping -q -c2 "$ip"; then
        _upmsg "$1 is online!"
        return 0
    else
        _warn "$1 is down or can not be reached"
        return 1
    fi
}

_info "Sending shutdown to all hosts"
for unit in $HOST_NAMES; do
    if _online "$unit"; then
        _safe "Shutdown $unit..."
        ssh "$unit" sudo shutdown -h now || true
    fi
done
_important "Shutdown list completed!"
