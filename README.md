# Helper scripts for live coding on Twitch

- Show all keys being pressed
- Webcam inset with optional filtering
- Can capture both microphone and audio out
- Dynamic text overlay
- Video settings tuned for code

![Screen grab of my stream](sample.png)

Watch me on https://www.twitch.tv/choongmoo

# Requirements

* Linux
* FFmpeg
* osd\_cat
* SWI-Prolog
* Xnee

On Ubuntu:

```
apt-get install ffmpeg xosd-bin swi-prolog xnee
```

# Usage

Place your Twitch stream key in the `key.secret` file.

* Adjust the settings in `stream.sh`.
* Run `./stream.sh` to start streaming.
* Run `./showkeys.sh` to display the keys being pressed.
