#!/bin/bash

set -eu -o pipefail

STREAM_KEY=$(cat "$(dirname "$0")/key.secret")

INRES="1366x768"  # input resolution
OUTRES=$INRES     # output resolution
FPS="15"          # target FPS
THREADS="4"       # max 6
CBR="1000k"       # constant bitrate (should be between 1000k - 3000k)
QUALITY="fast"    # or 'superfast', 'medium', 'slow', ...
AUDIO_RATE="44100"
SERVER="live"

GOP=`expr $FPS \* 2` # i-frame interval, should be double of FPS, 
GOPMIN=$FPS          # min i-frame interval, should be equal to FPS

ffmpeg_opts="-thread_queue_size 512"

screen=0:v
screen_opts="-f x11grab -s $INRES -r $FPS -i :0.0"

webcam=1:v
webcam_opts="-f v4l2 -video_size 320x240 -framerate $FPS -i /dev/video0"

filter="
  [$screen]setpts=PTS-STARTPTS[bg];
  [$webcam]setpts=PTS-STARTPTS,split=2[webcam1][webcam2];
  [webcam1]edgedetect=high=0.3:low=0.2,smartblur[alpha];
  [webcam2][alpha]alphamerge[fg];
  [bg][fg]overlay=W-w:H-h[out]" 



#        -f alsa -i pulse -ac 2 -ar $AUDIO_RATE 
#  -acodec libmp3lame
#        -f alsa -ac 2 -i hw:0 \
#  -map 2:a
# -ac 2 -ar $AUDIO_RATE 

ffmpeg $ffmpeg_opts $screen_opts $webcam_opts $audio_opts -filter_complex "$filter" -map "[out]" \
    "rtmp://$SERVER.twitch.tv/app/$STREAM_KEY" \
  2>&1 | sed "s/$STREAM_KEY/**********/"

