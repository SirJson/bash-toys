#!/usr/bin/env python3

# Pseudo shell that can only do one thing. Set the time.
# This is ment to be used over ssh or serial connections
# Also this script depends on systemd and sudo,
# in particular a system user that can only execute the needed time correction command


import os
import argparse
import sys
import subprocess

CTRL_HELLO = f'UP'
CTRL_BYE = f'BYE'
CTRL_ACKDT = f'ACKDT'
CTRL_NOTACKDT = f'ERRDT'
CTRL_INVALID = f'GERR'
SEPERATOR = ';'
CTRL_CMD = "CMD"
CMDTAG_DT = "DT"


def dtupdate(arg: str):
    datetime = arg.split("#")
    subprocess.run(['sudo', 'timedatectl', 'set-time',
                   f'{datetime[0]} {datetime[1]}'], check=True, capture_output=True)


def invalidcmd(_arg=None):
    print(CTRL_INVALID)


def parsecmd(cmd: str):
    commandmap = {
        'DTU': lambda pkg: dtupdate(pkg)
    }
    recv = cmd.strip().replace('\n', '')
    if recv.startswith(CTRL_CMD):
         record = recv.split(SEPERATOR)
         if len(record) != 3:
             print(CTRL_NOTACKDT)
             return 0
         cmd = commandmap.get(record[1], invalidcmd)
         try:
             cmd(record[2])
         except Exception as e:
             print(CTRL_NOTACKDT)
             print(str(e))
             return 1
         print(CTRL_ACKDT)
         running = False
    else:
         print(CTRL_INVALID)
         return 1


def timeshell(args):
    stdin = sys.stdin
    stdout = sys.stdout
    print(CTRL_HELLO)
    running = True
    while running:
        recv = stdin.readline()
        rt = parsecmd(recv)
        if rt == 0:
            running = False
            break
    print(CTRL_BYE)


def main(args=None):
    scriptname = os.path.basename(__file__)
    parser = argparse.ArgumentParser(scriptname)
    parser.add_argument(
        "-d", "--debug", help="Opens a fifo pipe for debug messages", action="store_true")
    parser.add_argument("-c", "--command")
    options = parser.parse_args()
    DEBUG = options.debug
    if options.command:
        parsecmd(options.command)
    else:
        timeshell(options)


if __name__ == '__main__':
    sys.exit(main())
