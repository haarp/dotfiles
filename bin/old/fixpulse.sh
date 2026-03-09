#!/bin/sh

# re-read the custom config, adding sinks whose master didn't exist yet at start
pacmd .include /home/haarp/.config/pulse/default.pa
