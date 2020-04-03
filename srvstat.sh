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
    printf '\e[38;2;200;200;200m %s %s\e[0m\n' "$_MSGPRE" "$1"
}

_downmsg() {
    printf '\e[0m'
    printf '\t\e[38;2;200;0;0m %s %s\e[0m\n' "$_ESOS" "$1"
}

_upmsg() {
    printf '\e[0m'
    printf '\t\e[38;2;0;200;0m %s %s\e[0m\n' "$_EUP" "$1"
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

IPLIST=$1
NAMES=$(awk -F '=' '{ print $1 }' < "$IPLIST")


_ip()
{
    grep "$1" < sbc.list | awk -F '=' '{ print $2 }'
}

_online_check() {
    local ip
    _info "Is $1 online?"
    ip=$(_ip "$1")
    if ping -q -c 1 "$ip" > /dev/null 2>&1; then
        _upmsg "$1 is online!"
        return 0
    else
        _warn "$1 is down or can not be reached"
        return 1
    fi
}

for unit in $NAMES; do
    _online_check "$unit"
done