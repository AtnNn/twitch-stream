#!/usr/bin/env bash

set -eu -o pipefail

STREAM_KEY=$(cat "$(dirname "$0")/key.secret")

INRES=1366x768    # input resolution
OUTRES=1366x768   # output resolution
FPS=10            # target FPS
THREADS=1         # max 6
CBR=2000k         # constant bitrate (should be between 1000k - 3000k)
QUALITY=fast      # or 'ultrafast', 'superfast', 'fast', 'medium', 'slow'
AUDIO_RATE=11025  # 44100
SERVER=live-lhr04 # From https://stream.twitch.tv/ingests/
WEBCAM=on         # on, off or filtered
AUDIO=on          # on or off
AUDIO_MONITOR=    # Leave empty or find the name in pactl list sources
AUDIO_MONITOR=alsa_output.pci-0000_00_1b.0.analog-stereo.monitor

GOP=`expr $FPS \* 2` # i-frame interval, should be double of FPS,
GOPMIN=$FPS          # min i-frame interval, should be equal to FPS

INRES_W=$(echo $INRES | cut -f 1 -d x)
INRES_H=$(echo $INRES | cut -f 2 -d x)
OUTRES_W=$(echo $OUTRES | cut -f 1 -d x)
OUTRES_H=$(echo $OUTRES | cut -f 2 -d x)

stream=0

screen=$((stream++)):v
screen_opts="-f x11grab -thread_queue_size 1024 -s $INRES -r $FPS -i :0.0"

if [[ $WEBCAM = off ]]; then
  webcam_opts=
  filter="[$screen]copy[out]"
elif [[ $WEBCAM = filtered ]]; then
  webcam=$((stream++)):v
  webcam_opts="-f v4l2 -thread_queue_size 1024 -video_size 320x240 -framerate $FPS -i /dev/video0"

  filter="
    [$screen]setpts=PTS-STARTPTS[bg];
    [$webcam]setpts=PTS-STARTPTS,split=2[webcam1][webcam2];
    [webcam1]edgedetect=high=0.3:low=0.2,smartblur[alpha];
    [webcam2][alpha]alphamerge[fg];
    [bg][fg]overlay=W-w:H-h[out]"
else
  webcam=$((stream++)):v
  webcam_opts="-f v4l2 -thread_queue_size 1024 -video_size 320x240 -framerate $FPS -i /dev/video0"

  filter="
    [$screen]
      setpts=PTS-STARTPTS,
      scale=w=$OUTRES_W:h=$OUTRES_H:force_original_aspect_ratio=decrease,
      pad=w=$OUTRES_W:h=$OUTRES_H:y=0:x=(out_w-in_w)/2,
      drawtext=textfile=overlay.txt:reload=1:fontcolor=white:fontsize=24
    [bg];
    [bg][$webcam]overlay=W-w:H-h[out]"
fi

out_opts="
  -f flv
  -vcodec libx264 -g $GOP -keyint_min $GOPMIN -b:v $CBR -minrate $CBR -maxrate $CBR -pix_fmt yuv420p
  -s $OUTRES -preset $QUALITY -tune animation -threads $THREADS
  -bufsize $CBR"

audio=$((stream++)):a
if [[ $AUDIO = off ]]; then
  audio_in="-f lavfi -i anullsrc"
  audio_out="-strict experimental -acodec aac -map $audio"
else
  audio_in="-f pulse -thread_queue_size 1024 -ar $AUDIO_RATE -i default"
  audio_map="-map $audio"
  # audio_out="-af volume=0.8,highpass=f=300,lowpass=f=3000,agate=ratio=9000:threshold=0.02:range=0:release=200:detection=rms -strict experimental -acodec aac -map $audio"

  if [[ -n "${AUDIO_MONITOR:-}" ]]; then
    audio_monitor=$((stream++)):a
    audio_in="$audio_in -f pulse -thread_queue_size 1024 -ar $AUDIO_RATE -i $AUDIO_MONITOR"
    audio_map="-filter_complex [$audio][$audio_monitor]amerge[aout] -map [aout] -ac 4"
  fi

  audio_out="-strict experimental -acodec aac $audio_map"
fi

ffmpeg $screen_opts $webcam_opts $audio_in -filter_complex "$filter" -map "[out]" \
    $out_opts $audio_out "rtmp://$SERVER.twitch.tv/app/$STREAM_KEY" \
  2>&1 | sed "s/$STREAM_KEY/**********/"

