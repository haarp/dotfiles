#!/bin/bash

# Check if docked
# can also be handled by udev! executes a script with ACTION env var set accordingly:
# SUBSYSTEM=="usb", ACTION=="add|remove", ENV{ID_VENDOR}=="17ef", ENV{ID_MODEL}=="100a", RUN+="/etc/sbin/thinkpad-dock.sh
function is_docked() {
	# 17ef:100a Lenovo ThinkPad Mini Dock Plus Series 3
	local idVendor="17ef"
	local idProduct="100a"

	for usb in /sys/bus/usb/devices/*/; do
		grep -q "$idVendor" "$usb/idVendor" 2>/dev/null && grep -q "$idProduct" "$usb/idProduct" && {
			notify-send "docked"
			return 0
		}
	done
	notify-send "undocked"
	return 1
}

# Add a custom xrandr mode to an output and print its name
# arguments: output, x, y, refresh
function custom_mode() {
	[[ $# == 4 ]] || {
		echo "$FUNCNAME called incorrectly!" >&2
		return 127
	}
	command -v cvt12 >/dev/null || {
		echo "cvt12 not installed!" >&2
		return 127
	}

	# generate modeline (always with CVT 1.2 "Reduced Blanking")
	local modeline=$(cvt12 $2 $3 $4 --rb-v2 | sed -e '1d' -e 's/Modeline //' -e 's/"//g')
	local modename=$(awk '{print $1}' <<< "$modeline")

	[[ "$modeline" ]] || return 1

	# create mode in mode pool if it doesn't already exist
	xrandr --current | grep -q "^  $modename" || {
		xrandr --newmode $modeline || return 2
	}

	# add mode to output
	xrandr --addmode "$1" "$modename" || return 3

	echo "$modename"
	return 0
}

# Transfer all active PulseAudio streams to another sink
function transfer_sink() {
	pacmd list-sink-inputs | grep -A4 index | while read line; do
		grep -q '^index:' <<< "$line" && {
			sinkinput=$(awk '{print $2}' <<< "$line")
			continue
		}
		grep -q '^driver:' <<< "$line" && {
			driver=$(awk -F'<|>' '{print $2}' <<< "$line")
			continue
		}
		grep -q '^sink:' <<< "$line" && {
			sink=$(awk -F'<|>' '{print $2}' <<< "$line")
			if [ ! $sink = $1 -a $driver = "protocol-native.c" ]; then
				pacmd move-sink-input $sinkinput $1
			fi
			continue
		}
	done
}



### Start
# Set proper microphone amplification
pactl set-source-volume alsa_input.pci-0000_00_1b.0.analog-stereo 0x6000

# Load monitor calibration profile
{
	$HOME/bin/setcalib.sh
} &

# Fix mouse speed after login
{
	xfconf-query -c pointers -p /TPPS2_IBM_TrackPoint/Acceleration -s 0
	xfconf-query -c pointers -p /SynPS2_Synaptics_TouchPad/Acceleration -s 0
	sleep 0.5
	xfconf-query -c pointers -p /TPPS2_IBM_TrackPoint/Acceleration -s 2
	xfconf-query -c pointers -p /SynPS2_Synaptics_TouchPad/Acceleration -s 7
}
# Fix window titles shifted too low after login
{
	xfconf-query -c xfwm4 -p /general/title_font -s "Arial Black, 8.0"
	sleep 0.5
	xfconf-query -c xfwm4 -p /general/title_font -s "Arial Black, 8.5"
}
# Fix cursor size after login by toggling theme (https://bugzilla.xfce.org/show_bug.cgi?id=7415)
{
	xfconf-query -c xsettings -p /Gtk/CursorThemeName -s default
	sleep 0.5
	xfconf-query -c xsettings -p /Gtk/CursorThemeName -s Adwaita #Vanilla-DMZ-AA
}

# Fix blueman after suspend (https://github.com/blueman-project/blueman/issues/571)
###killall blueman-applet
###blueman-applet &>/dev/null & disown

# Restart devilspie if it crashed yet again
pgrep devilspie2 >/dev/null || {
	devilspie2 & disown
}

if is_docked; then
	### Monitor setup NOUVEAU
	# Enable nvidia outputs (note: discrete gpu will never sleep while this is on)
	# BUG: often we can't switch to a mode (https://bugs.freedesktop.org/show_bug.cgi?id=107919)
#	xrandr --setprovideroutputsource nouveau Intel
#	xrandr --setprovideroutputsource nouveau modesetting
	# Laptop
##	xrandr --output LVDS1 --mode 1920x1080 --pos 0x0 --rotate normal
##	xrandr --output LVDS-1 --mode 1920x1080 --pos 0x0 --rotate normal
	# LG via mDP
##	xrandr --output DP-1-1 --primary --mode 3440x1440 --rate 75 --pos 1920x0 --rotate normal
##	xrandr --output DP-1-1 --primary --mode 3440x1440 "$(custom_mode DP-1-1 3440 1440 79)" --pos 1920x0 --rotate normal
	# LG via dock DP (max pixel clock = 288MHz - more works, badly, but only if *monitor* was off before switching the output on??)
##	xrandr --output DP-1-2 --primary --mode "$(custom_mode DP-1-2 3440 1440 55)" --pos 1920x0 --rotate normal
	# LG via dock DP + DP-to-HDMI adapter (max pixel clock = 360.10MHz)
##	xrandr --output DP-1-2 --mode 3440x1440 --rate 49.99 --pos 1920x0 --rotate normal
#	xrandr --output DP-1-2 --mode "$(custom_mode DP-1-2 3440 1440 68)" --pos 1920x0 --rotate normal
#	xrandr --output DP-1-2 --primary


##	### Monitor setup NVIDIA + intel-virtual-output
####	# Add custom mode for LG screen via dock (max pixel clock = 165MHz - unless mode in EDID: https://devtalk.nvidia.com/default/topic/541455/)
####	mode="$(DISPLAY=:8 custom_mode DP-1 2576 1080 56)"
####	# Have Intel X pick up new mode (restart i-v-o without shutting down Nvidia X)
####	{ optirun sleep 5; } &
####	killall intel-virtual-output && intel-virtual-output
####	# get name of new mode on Intel X
####	intelmode=$(xrandr | awk "/$mode/{print \$1}")
##	# Laptop
##	xrandr --output LVDS1 --mode 1920x1080 --pos 0x0 --rotate normal
##	# LG via mDP
##	xrandr --output VIRTUAL6 --primary --mode VIRTUAL6.741-3440x1440 --pos 1920x0 --rotate normal
####	# LG via dock
####	xrandr --output VIRTUAL4 --primary --mode "$intelmode" --pos 1920x0 --rotate normal
##	# Disable compositor when i-v-o runs for a small performance boost (https://bugs.freedesktop.org/show_bug.cgi?id=96820)
##	xfconf-query -c xfwm4 -p /general/use_compositing -s false


	### PulseAudio setup
	# Restart daemon because it sometimes is too retarded to notice the Aureon Dual USB
##	pulseaudio -k && pulseaudio --start
	# Set default sink to Aureon Dual USB and transfer streams to it
	# (hint: default sink can be referred to as @DEFAULT_SINK@)
	sink=$(pacmd list-sinks | grep "name:" | grep -o "alsa_output\.usb[a-zA-Z0-9\._-]*")
	[ "$sink" ] && {
		pacmd set-default-sink "$sink"
		transfer_sink "$sink"
	}
	# Unload network capabilities
	pacmd unload-module module-tunnel-sink-new
	pacmd unload-module module-rtp-send
	pacmd unload-module module-null-sink

	# Load dynamic compressor (https://askubuntu.com/a/44012)
	pacmd unload-module module-ladspa-sink
	pacmd load-module module-ladspa-sink plugin=sc4m_1916 label=sc4m control=1,1.5,401,-30,20,5,12 \
		sink_name=Compressor sink_properties=device.description=Dynamic_Compressor

### undocked
else
	### Monitor setup NOUVEAU
	# Disable nvidia outputs
#	xrandr --setprovideroutputsource nouveau 0x0


##	### Monitor setup NVIDIA + intel-virtual-output
##	# Set modes
##	xrandr --output LVDS1 --primary --mode 1920x1080 --pos 0x0 --rotate normal
##	# Re-enable compositor
##	xfconf-query -c xfwm4 -p /general/use_compositing -s true


	### PulseAudio setup
	# Unmute PulseAudio onboard audio, set as default, transfer streams to it
	sink=$(pacmd list-sinks | grep "name:" | grep -o "alsa_output\.pci.*analog-stereo")
	[ "$sink" ] && {
		pacmd set-sink-mute "$sink" 0
		pacmd set-default-sink "$sink"
		transfer_sink "$sink"
	}

##	# Load optional PulseAudio network capabilities
##	HOST=jenner
##	pactl unload-module module-tunnel-sink-new
##	pactl load-module module-tunnel-sink-new \
##		server=$(getent hosts "$HOST" | awk '{print $1}') \
##		sink_name="Tunnel"
##		sink_properties=device.description="Tunnel_to_$HOST"
##	# and set as default (if it still exists after 5s)
##	sleep 5; pacmd set-default-sink "Tunnel"

##	# Load optional PulseAudio network capabilities (RTP variant)
##	pacmd unload-module module-rtp-send
##	pacmd unload-module module-null-sink
##	pacmd load-module module-null-sink \
##		sink_name=RTP sink_properties=device.description="RTP_Multicast"
##	pacmd load-module module-rtp-send source=RTP.monitor port=46000 mtu=400		# default-mtu=1280

fi


# Restart notifyd so it shows notifications at the correct position
##pkill xfce4-notifyd
