#!/usr/bin/env bash

### Manual settings ###

# Stream source
INRES=1366x768    # Screen resolution
WEBCAM=on         # on, off or filtered
MICROPHONE=on     # on or off
AUDIO_MONITOR=    # Leave empty to disable. To enable, find the name in 'pactl list sources' that corresponds to the monitor
# AUDIO_MONITOR=alsa_output.pci-0000_00_1b.0.analog-stereo.monitor # For example, this is the name of "Monitor of Built-in Audio Analog Stereo" on my computer

# Stream destination
OUTPUT=screen     # 'screen' or 'twitch'
SERVER=live-lhr04 # Select a server from https://stream.twitch.tv/ingests/
                  # Place your twitch key in the 'key.secret' file

# Stream quality
OUTRES=1366x768   # output resolution
FPS=10            # target FPS
THREADS=1         # max 6
CBR=2000k         # constant bitrate (should be between 1000k - 3000k)
QUALITY=fast      # or 'ultrafast', 'superfast', 'fast', 'medium', 'slow'
AUDIO_RATE=11025  # 44100

### End of manual settings ###

set -eu -o pipefail

touch key.secret overlay.txt

STREAM_KEY=$(cat "$(dirname "$0")/key.secret")

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
      drawtext=textfile=overlay.txt:reload=1:fontcolor=orange:font=fixed:fontsize=24:shadowx=2:shadowy=2:shadowcolor=black
    [bg];
    [bg][$webcam]overlay=W-w:H-h[out]"
fi

out_opts="
  -f flv
  -vcodec libx264 -g $GOP -keyint_min $GOPMIN -b:v $CBR -minrate $CBR -maxrate $CBR -pix_fmt yuv420p
  -s $OUTRES -preset $QUALITY -tune animation -threads $THREADS
  -bufsize $CBR"

audio_streams=
audio_in=
if [[ "$MICROPHONE" = on ]]; then
  audio=$((stream++)):a
  audio_streams=$audio_streams[$audio]
  audio_in="$audio_in -f pulse -thread_queue_size 1026 -ar $AUDIO_RATE -i default"
  # Optional filter for bad microphones
  # -af volume=0.8,highpass=f=300,lowpass=f=3000,agate=ratio=9000:threshold=0.02:range=0:release=200:detection=rms
fi
if [[ -n "${AUDIO_MONITOR:-}" ]]; then
  audio_monitor=$((stream++)):a
  audio_streams=$audio_streams[$audio_monitor]
  audio_in="$audio_in -f pulse -thread_queue_size 1024 -ar $AUDIO_RATE -i $AUDIO_MONITOR"
fi
if [[ -z "${audio_streams##*][*}" ]]; then
  audio_map="-filter_complex ${audio_streams}amerge[aout] -map [aout] -ac 4"
elif [[ -n "${audio_streams}" ]]; then
  audio_map="-map $audio_streams"
else
  silence=$((stream++)):a
  audio_in="-f lavfi -i anullsrc"
  audio_map="-map $silence"
fi
audio_out="-strict experimental -acodec aac $audio_map"

command=(ffmpeg $screen_opts $webcam_opts $audio_in -filter_complex "$filter" -map "[out]" $out_opts $audio_out)

if [[ "$OUTPUT" = twitch ]]; then
  "${command[@]}" rtmp://$SERVER.twitch.tv/app/$STREAM_KEY 2>&1 | sed 's/$STREAM_KEY/**********/'
elif [[ "$OUTPUT" = screen ]]; then
  "${command[@]}" - | ffplay -i -
else
  echo "NO OUTPUT!"
  exit 1
fi

