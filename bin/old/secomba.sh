#!/bin/sh

### Monitor setup NOUVEAU
# Notes:
#   DP-1-2 will not switch on on first attempt - therefore set DP-1-3 to 1080p, then to 1440p
#   Rotated output: cursor shows up fine and rotated, but upper (right) half is garbled mess, lower (left) half shows part of output properly
#   Dell U2515H manages up to 80Hz, but will frameskip horribly ≠60Hz
#     https://www.dell.com/community/Monitors/U2515H-all-preset-75Hz-display-modes-skip-frames/td-p/5027314
xrandr --setprovideroutputsource nouveau Intel
xrandr --setprovideroutputsource nouveau modesetting
xrandr --output LVDS1 --mode 1920x1080 --pos 0x0 --rotate normal
xrandr --output LVDS-1 --mode 1920x1080 --pos 0x0 --rotate normal
xrandr --output DP-1-1 --off --output DP-1-2 --off --output DP-1-3 --off
# Direct mDP
##xrandr --output DP-1-1 --mode 3440x1440 --pos 1920x0 --rotate normal
##xrandr --output DP-1-1 --primary
# Docking Station
xrandr --output DP-1-2 --mode 2560x1440 --pos 1920x0 --rotate normal
xrandr --output DP-1-2 --primary
##xrandr --output DP-1-3 --mode 1920x1080 --pos 4480x0 --rotate normal ##right
xrandr --output DP-1-3 --mode 2560x1440 --pos 4480x0 --rotate normal ##right
sleep 1 # try again after sleeping
xrandr --output DP-1-2 --primary

##### Monitor setup NVIDIA+intel-virtual-output
##xrandr --output LVDS1 --mode 1920x1080 --pos 0x0 --rotate normal \
##       --output VIRTUAL7 --primary --mode VIRTUAL7.741-2560x1440 --pos 1920x0 --rotate normal
##sleep 0.5	# necessary for some reason (?)
##xrandr --output VIRTUAL8 --mode VIRTUAL7.741-2560x1440 --pos 4480x0 --rotate right
##
### Disable compositor when i-v-o is in use for a small performance boost (https://bugs.freedesktop.org/show_bug.cgi?id=96820)
##xfconf-query -c xfwm4 -p /general/use_compositing -s false

### PulseAudio setup
# Set default sink to onboard audio, but mute
sink=$(pacmd list-sinks | grep "name:" | grep -o "alsa_output\.pci.*analog-stereo")
pacmd set-sink-mute "$sink" 1
pacmd set-default-sink "$sink"
# Unload network capabilities to avoid log spam due to different network interfaces
pacmd unload-module module-tunnel-sink-new
pacmd unload-module module-rtp-send
pacmd unload-module module-null-sink
