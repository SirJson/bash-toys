#!/bin/bash
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

_SCRIPTNAME=$(basename "$0")
_SCRIPTVER="1.0.0"

_PREAMBLE="$_SCRIPTNAME $_SCRIPTVER
$_SCRIPTNAME is an easy to use network port audit tool.
"

_HELP="
ACTIONS:
    Defines the audit mode. If no action is selected $_SCRIPTNAME will default to 'all'

    all: Show all ports regardless of state or protocol
    listen: Show all ports that listen for incomming connections
    connect: Show all ports that are in use and connected

OPTIONS:
    -p: Filter output for port
    -a: Don't filter unique bound addresses
    -r: Disable ANSI control character in output
    -4: Show only IPv4 output
    -6: Show only IPv6 output
    -h: Prints this output

EXAMPLES:
     $_SCRIPTNAME
     $_SCRIPTNAME -a connect
     $_SCRIPTNAME -p80 listen
     $_SCRIPTNAME -ar4 all
"

_SHOW_ALL=0
_PORT=
_ACTIONS=("all" "listen" "connect")
_IPVER=

_DISP_HSTYLE='\033[36m'
_DISP_UDPSTYLE='\033[35m'
_DISP_TCPSTYLE='\033[32m'
_DISP_RESET='\033[0m'

# shellcheck disable=SC2016
format_output() {
    local tcols
    local input
    input=$(</dev/stdin)
    tcols="$(tput cols)"

    local disp_awkscr='BEGIN{format="%-16s\t%s\t%10s\t%8s\t%s";header=sprintf(format,"Command","PID","Transport","Protocol","Outbound");hlen=length(header)+34 <= colc ? length(header)+34 : colc;printf("\n%s%s%s\n",hstyle,header,reset);for (i = 0; i < hlen; ++i) {printf("-");}printf("\n")}'
    local disp_echo='prow=sprintf(format,$1,$2,$5,$8,$9);'
    local disp_echo_unique='if (a[$9]++ == 0){ prow=sprintf(format,$1,$2,$5,$8,$9);}else{ prow="";}'
    local disp_pparse='if (length(prow) > 0) { styl=""; switch ($8) { case "TCP": styl=tstyle; break; case "UDP": styl=ustyle; break; default: styl="\033[33m"; break; } printf("%s%s%s\n",styl,prow,reset); }'
    local disp_end='END { printf "\n" }'

    disp_awkscr+='{'
    if [[ $_SHOW_ALL == 1 ]]; then
        disp_awkscr+=$disp_echo
    else
        disp_awkscr+=$disp_echo_unique
    fi
    disp_awkscr+=$disp_pparse
    disp_awkscr+='}'
    disp_awkscr+=$disp_end

    if [[ -z $input ]]; then
        printf "> No ports found"
        if [[ $EUID != 0 ]]; then
            printf " or insufficent permissions"
        fi
        printf "\n"
    else
        echo "$input" | awk -v colc="$tcols" -v hstyle="$_DISP_HSTYLE" -v ustyle="$_DISP_UDPSTYLE" -v tstyle="$_DISP_TCPSTYLE" -v reset="$_DISP_RESET" "$disp_awkscr"
    fi
}

all_table() {
    lsof -i"$_IPVER" -P -n | tail +2 | sort | grep "$_PORT" | format_output || true
}

listen_table() {
    lsof -i"$_IPVER" -P -n | grep LISTEN | tail +2 | grep "$_PORT" | sort | format_output || true
}

connect_table() {
    lsof -i"$_IPVER" -P -n | grep ESTABLISHED | tail +2 | grep "$_PORT" | sort | format_output || true
}

_usage() {
    echo "USAGE: " >&2
    echo "  $_SCRIPTNAME [-p PORT] [-a] [-r] [-4] [-6] (all|listen|connect)" >&2
}

_show_help() {
    echo "$_PREAMBLE"  >&2
    _usage
    echo "$_HELP" >&2
}

while getopts 'p:ahr46' OPTION; do
    case "$OPTION" in
    a)
        _SHOW_ALL=1
        ;;
    p)
        _PORT=":$OPTARG"
        ;;
    r)
        _DISP_HSTYLE=''
        _DISP_UDPSTYLE=''
        _DISP_TCPSTYLE=''
        _DISP_RESET=''
        ;;
    4)
        _IPVER=4
        ;;
    6)
        _IPVER=6
        ;;
    h)
        _show_help
        exit 0
        ;;
    *)
        _usage
        exit 1
        ;;
    esac
done
shift "$((OPTIND - 1))"

ACT=${1:-'all'}

for a in "${_ACTIONS[@]}"; do
    if [ "$a" == "$ACT" ]; then
        "${a}_table"
        exit 0
    fi
done


echo "Invalid Action: $ACT"
_usage # You should not be here
exit 1
