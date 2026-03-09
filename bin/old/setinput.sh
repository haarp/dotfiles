#!/bin/bash
## Set various input settings

##notify-send "$(basename "$0")" "running now..."

keyboard() {
	:
	## Yubikey Nano
	# disable it to avoid random garbage when I accidently touch it
	# Alternatives: https://support.yubico.com/hc/en-us/articles/360013714379-Accidentally-Triggering-OTP-Codes-with-Your-Nano-YubiKey
##	xinput disable "Yubico Yubikey 4 OTP+U2F+CCID"
}

mouse() {
	:
##	## Thinkpad evdev Trackpoint
##	# Evdev Wheel Emulation:		enable autoscrolling (default: 0)
##	# Evdev Wheel Emulation Button:		button to use for autoscrolling (default: 4)
##	# Evdev Wheel Emulation Axes:		axes to use for autoscrolling (default: 0 0 4 5)
##	# Evdev Wheel Emulation Inertia (old):	travel distance for one scroll event (default: 10)
##	# Evdev Scrolling Distance (new):	travel distance on X, Y, dial for one traditional scroll event (default: 1 1 1)
##	xinput set-prop "TPPS/2 IBM TrackPoint" "Evdev Wheel Emulation" 1
##	xinput set-prop "TPPS/2 IBM TrackPoint" "Evdev Wheel Emulation Button" 2
##	xinput set-prop "TPPS/2 IBM TrackPoint" "Evdev Wheel Emulation Axes" 6 7 4 5
##	xinput set-prop "TPPS/2 IBM TrackPoint" "Evdev Wheel Emulation Inertia" 25
##	xinput set-prop "TPPS/2 IBM TrackPoint" "Evdev Scrolling Distance" 30 60 1

##	## Thinkpad Touchpad
##	# EmulateTwoFingerMinZ:	pressure needed for two-finger scrolling (W700 default: >100, broken)
##	# FooScrollDelta:	travel distance for one scroll event (W520 default: 101)
##	# TapAndDragGesture:	annoying gesture (default: 1)
##	# SingleTapTimeout:	minimum time a tap is recognized (and delay between tap and reaction) (default: 180)
##	# ConstantDeceleration:	no idea, but 7.5 slows the touchpad to the correct speed again (default: 2.5)
####	synclient EmulateTwoFingerMinZ=0libinput Accel Profile
##	synclient VertScrollDelta=80
##	synclient HorizScrollDelta=120
##	synclient TapAndDragGesture=0
##	synclient SingleTapTimeout=45
##	xinput set-prop "SynPS/2 Synaptics TouchPad" "libinput Tapping Drag Enabled" 0

##	## Thinkpad Clickpad
####	synclient TapButton2=3
####	synclient TapButton3=2
####	synclient ClickFinger2=3
####	synclient ClickFinger3=2
####	synclient AreaTopEdge=2500		# disable top edge to prevent jitter when using the trackpoint
####	synclient RightButtonAreaLeft=3700
####	synclient RightButtonAreaRight=0
####	synclient RightButtonAreaTop=0
####	synclient RightButtonAreaBottom=2300
####	synclient MiddleButtonAreaRight=3500
####	synclient MiddleButtonAreaLeft=2900
####	synclient MiddleButtonAreaTop=0
####	synclient MiddleButtonAreaBottom=2300

	## Thinkpad modern touchpad
	# disable middle-click because it tends to be triggered when trying to do gestures
	xinput set-button-map 'SynPS/2 Synaptics TouchPad' 1 0 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32
	# (hopefully) disable this fucking annoying drag lock thing (https://gist.github.com/cob16/852fe51373cf9511323bf3fa9322bd22)
	xinput --set-prop "SynPS/2 Synaptics TouchPad" "libinput Drag Lock Buttons" 0

	## Thinkpad modern touchpad w/ synaptics_intertouch=1
	# same as above
	xinput --set-prop "Synaptics TM3512-010" "libinput Drag Lock Buttons" 0
	# fix clickpad right-click
	xinput --set-prop "Synaptics TM3512-010" "libinput Click Method Enabled" 0 1

	## Thinkpad modern trackpoint
	# switch between adaptive and flat. flat is normal, adaptive is hyperspeed
####	xinput set-prop 'TPPS/2 Elan TrackPoint' 'libinput Accel Profile Enabled' 0 1
	# reduce speed (https://unix.stackexchange.com/a/177640/138699)
####	factor=1
####	xinput set-prop 'TPPS/2 Elan TrackPoint' 'Coordinate Transformation Matrix' $factor 0.0 0.0 0.0 $factor 0.0 0.0 0.0 1.0


	## Logitech MX1100
	# disable twitchy side scrolling buttons (note: this doesn't work with XINPUT2 apps!)
####	for device in $(xinput list | grep "⎜.*Logitech USB Receiver" | awk -F'=|\t' '{print $3}'); do
####		xinput set-button-map "$device" 1 2 3 4 5 0 0 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32
####	done

	## Logitech MX Master
	# invert horizontal wheel (note: this doesn't work with XINPUT2 apps!)
####	for device in $(xinput list | grep "⎜.*MX Master" | awk -F'=|\t' '{print $3}'); do
####		xinput set-button-map "$device" 1 2 3 4 5 7 6 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32
####	done
}

tablet() {
	:
##	OUTPUT="HEAD-0"
	OUTPUT="LVDS1"
	xsetwacom list | awk -F'\t' '{print $1}' | while read line; do
		xsetwacom set "$line" MapToOutput $OUTPUT
	done
	[[ "$1" == "newrandr" ]] && return	# return if all we needed was to reset the output mapping

	## Wacom ISD-V4 Pen (W700 palmrest)
	# MapToOutput		restrict area to given RandR 1.2 OR Nvidia TwinView ("HEAD-x") output
	# Area:			calibrate, use 'xinput test "device name"' or xinput_calibrator (W700 default: 0 0 12800 8000)
	# PressureCurve:	see http://linuxwacom.sourceforge.net/misc/bezier.html (default: 0 0 100 100)
	# Suppress:		minimum position delta to transmit coordinates (default: 2)
	# RawSample:		samples to average position for; works like SAI's stabilizer (default: 4)
	# TabletPCButton:	stylus buttons only work when tip is pressed (W700 default: off, X200T default: on)
	# Button:		map buttons (Button 3 is side button on Thinkpad stylus) (default: 1-on-1)
	# more with 'man wacom' and 'man xsetwacom'
##	xsetwacom set "ISD-V4 Pen stylus" Area "400 400 12400 7600"
##	xsetwacom set "ISD-V4 Pen eraser" Area "400 400 12400 7600"
##	xsetwacom set "ISD-V4 Pen stylus" PressureCurve "100 0 50 100"
##	xsetwacom set "ISD-V4 Pen stylus" Button 1 1
##	xsetwacom set "ISD-V4 Pen stylus" Button 2 3
##	xsetwacom set "ISD-V4 Pen stylus" Button 3 2
##	xsetwacom set "ISD-V4 Pen stylus" TabletPCButton on


	## Wacom Bamboo Pen&Touch
	# Touch:		enable/disable touch (touch device needs to be enabled for buttons)
	# Button X:		bind tablet button to keyboard button (use xev for button names)
	xsetwacom set "Wacom Bamboo Craft Finger touch" Touch off
	xsetwacom set "Wacom Bamboo Craft Finger pad" Button 3 "key +ctrl y -ctrl"	# outer upper (redo)
	xsetwacom set "Wacom Bamboo Craft Finger pad" Button 8 "key Prior"		# inner upper (pgup)
	xsetwacom set "Wacom Bamboo Craft Finger pad" Button 9 "key Next"		# inner lower (pgdn)
	xsetwacom set "Wacom Bamboo Craft Finger pad" Button 1 "key +ctrl z -ctrl"	# outer lower (undo)
}

case "$1" in
	keyboard)	keyboard "$2"
			mouse "$2";;	# because some mice advertise themselves as keyboards only
	mouse)		mouse "$2";;
	tablet)		tablet "$2";;

	*)		keyboard
			mouse
			tablet;;
esac
