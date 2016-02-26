#!/bin/bash

swipl -F none -s showkeys.pl -t true -g main | \
    osd_cat --age=3 -p top -A right -f "-*-fixed-*-*-*-*-40-*-*-*-*-*-*-*" -c orange -l 15 -s 2
