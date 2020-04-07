#!/bin/bash


print_cpuspeed()
{
    grep "cpu MHz" /proc/cpuinfo | awk -F':' '{printf "\033[34mCPU %2d\033[0m %s\033[36m%s Mhz\033[0m\n",NR,"→",$2;}'
}

if [[ $1 == "watch" ]]; then
    watchint=2
    test -n "$2" && watchint=$2
    watch --color -n"$watchint" "$0"
else
    print_cpuspeed
fi