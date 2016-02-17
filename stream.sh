#!/bin/bash

set -eu -o pipefail

STREAM_KEY=$(cat "$(dirname "$0")/key.secret")

INRES="1366x768" # input resolution
OUTRES="1366x768" # output resolution
FPS="15" # target FPS
GOP="30" # i-frame interval, should be double of FPS, 
GOPMIN="15" # min i-frame interval, should be equal to fps, 
THREADS="0" # max 6
CBR="1000k" # constant bitrate (should be between 1000k - 3000k)
QUALITY="ultrafast"  # one of the many FFMPEG preset
# AUDIO_RATE="44100"
SERVER="live"

#        -f alsa -i pulse -ac 2 -ar $AUDIO_RATE 
#  -acodec libmp3lame
ffmpeg -f x11grab -s "$INRES" -r "$FPS" -i :0.0 \
       -f flv \
       -vcodec libx264 -g $GOP -keyint_min $GOPMIN -b:v $CBR -minrate $CBR -maxrate $CBR -pix_fmt yuv420p\
       -s $OUTRES -preset $QUALITY -tune film -threads $THREADS -strict normal \
       -bufsize $CBR "rtmp://$SERVER.twitch.tv/app/$STREAM_KEY" 2>&1 | sed "s/$STREAM_KEY/**********/"

