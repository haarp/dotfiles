#!/bin/bash
## Set the volume on all output device simulatenously
## Parameter: see 'man pactl', e.g "+10%"

# FIXME: goes overe 100%

for device in $(pactl list short sinks | cut -c1); do
	pactl set-sink-volume $device "$1"
done
