#!/bin/bash

set -eu
set -o pipefail

threshold=200 # milliseconds
too_long=25 # characters

TIMEFORMAT=%R

elapsed=0
accum=

swipl -F none -s showkeys.pl -t true -g main | \
    while true; do
        if ! out=$({ time { read -r -t 0.$(printf "%03d" $((threshold-elapsed))) a && printf "%s\n" "$a"; }; } 2>&1); then
            if [[ -n "$accum" ]]; then
                printf "%s\n" "$accum"
                accum=
            fi
            elapsed=0
            continue
        fi
        set -- $out
        duration=$2
        duration=${duration/.}
        duration=${duration/#0}
        duration=${duration/#0}
        duration=${duration/#0}
        if [[ -n "$accum" ]]; then
            elapsed=$((elapsed+duration)) 
        fi
        # echo "elapsed:$elapsed duration:$duration" >&2
        if [[ $elapsed -gt $threshold  || ${#accum} -gt $too_long ]]; then
            if [[ -n "$accum" ]]; then
                printf "%s\n" "$accum"
                accum=
            fi
            elapsed=0
        else
            accum="$accum $1"
        fi
    done | \
    osd_cat -d 2 --age=1 -p top -A right -f "-*-fixed-*-*-*-*-40-*-*-*-*-*-*-*" -c orange -l 12 -s 2
