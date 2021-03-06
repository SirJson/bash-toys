#!/bin/bash

# Syncs all given Hosts with the time from a working RTC.
# This is because I just couldn't get any RTC to work on my Tinkerboard and everytime
# that thing lost power I had to set the time manually.

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
_MSGVICTORY="🏆"

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


_info() {
    printf '\e[0m'
    printf '\e[38;2;200;200;200m %s %s\e[0m\n' "$_MSGPRE" "$1"
}

_ok() {
    printf '\e[0m'
    printf '\e[38;2;0;200;0m %s %s\e[0m\n' "$_MSGPRE" "$1"
}


_bad() {
    printf '\e[0m'
    printf '\e[38;2;200;0;0m %s %s\e[0m\n' "$_MSGPRE" "$1"
}

_downmsg() {
    printf '\e[0m'
    printf '\t\e[38;2;200;0;0m %s %s\e[0m\n' "$_ESOS" "$1"
}

_upmsg() {
    printf '\e[0m'
    printf '\t\e[38;2;0;200;0m %s %s\e[0m\n' "$_EUP" "$1"
}

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

IPLIST=$1
NAMES=$(awk -F '=' '{ print $1 }' < "$IPLIST")


_ip()
{
    grep "$1" < "$IPLIST" | awk -F '=' '{ print $2 }'
}

_sendtime() {
    # We just assume that the system that will run this is actually syncronized.
    goodtime="$(sudo timedatectl | awk '{print $4,$5}' | head -n1)"
    encoded=$(echo "$goodtime" | tr ' ' '#')
    ssh timekeeper@"$1" "CMD;DTU;$encoded"
}

_reachable() {
    ping -c 1 "$1"
}


_online_check() {
    local ip
    _info "Is $1 online?"
    ip=$(_ip "$1")
    if _reachable "$ip"; then
        _upmsg "$1 is online! Sending current datetime..."
        if _sendtime "$1"; then
            _ok "$1 should now have the correct date and time! $_MSGVICTORY"
        else
            _bad "Setting time for $1 failed. Continue with the next candidate..."
        fi
    else
        _downmsg "$1 is down or can not be reached"
    fi
}

for unit in $NAMES; do
    _online_check "$unit" || true
done
