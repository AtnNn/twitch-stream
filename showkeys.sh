#!/usr/bin/env bash

set -eu
set -o pipefail

threshold=200 # milliseconds
repeat_threshold=500 # milliseconds
too_long=25 # characters
# x_offset=286
x_offset=0

TIMEFORMAT=%R

elapsed=0
accum=
last=
count=0

swipl -F none -s showkeys.pl -t true -g main | \
    while true; do
        if [[ "$count" -gt 1 ]]; then
            timeout_opts="-t 0.$repeat_threshold"
        else
            timeout_opts="-t 0.$(printf "%03d" $((threshold-elapsed)))"
        fi
        if ! out=$({ time { read -r $timeout_opts a && printf "%s\n" "$a"; }; } 2>&1); then
            if [[ "$count" -gt 1 ]]; then
                accum="${accum%.}$last"
            fi
            if [[ -n "$accum" ]]; then
                printf "%s\n" "$accum"
                accum=
            fi
            elapsed=0
            last=
            count=0
            continue
        fi
        set -- $out
        duration=${2:-0}
        duration=${duration/.}
        duration=${duration/#0}
        duration=${duration/#0}
        duration=${duration/#0}
        if [[ -n "$accum" && "$count" -gt 1 ]]; then
            elapsed=$((elapsed+duration)) 
        fi
        if [[ "$last" = "$1" && $duration -le $repeat_threshold ]]; then
            count=$((count+1))
        else
            if [[ "$count" -gt 1 ]]; then
                accum="${accum%.}$last"
            fi
            last=$1
            count=0
        fi
        if [[ "$count" -gt 1 ]]; then
            accum="${accum/%$1 $1/$1.}."
        else
            accum="$accum $1" 
        fi
        # echo "elapsed:$elapsed duration:$duration" >&2
        if [[ $elapsed -gt $threshold  || ${#accum} -gt $too_long ]]; then
            printf "%s\n" "$accum"
            accum=
            elapsed=0
        fi
    done | \
    osd_cat -d 2 --age=1 -p top -A right -f "-*-fixed-*-*-*-*-40-*-*-*-*-*-*-*" -c orange -l 9 -s 2 -i $x_offset
