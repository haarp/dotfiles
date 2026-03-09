#!/bin/sh
## Enable/Disable the Thinkpad W700ds's second display

Y_OFFSET=0	# Y offset of 2nd display to line up with main display (-80 to 0)
X_OFFSET=120	# X offset of 2nd display (void between displays) (any value)
X_HURDLE=80	# strength of the hurdle making it harder for the pointer to reach the 2nd display (0 to X_OFFSET)


if [ $Y_OFFSET -lt -80 -o $Y_OFFSET -gt 0 -o $X_HURDLE -gt $X_OFFSET ]; then
	echo "You dun goofed! These settings are invalid..."
	exit 1
fi

xrandr=$(xrandr)

if echo "$xrandr" | grep -E "VGA-0|DVI-D-0|DP-0|DP-1" | grep -q " connected"; then
	##xfce4-display-settings --minimal
	arandr
elif echo "$xrandr" | grep -A1 "DVI-D-1" | grep -q "\*"; then
	notify-send -i display "Disabling 2nd display..."
	xrandr --output DVI-D-1 --off
	killall XCreateMouseVoid &>/dev/null
	"$HOME/bin/setinput.sh" tablet newrandr								# reset wacom output mappings
else
	notify-send -i display "Enabling 2nd display..."
	xrandr --output LVDS-0 --pos 0x$[-$Y_OFFSET] --output DVI-D-1 --mode 1280x768 --rotate left --pos $[1920+$X_OFFSET]x0 && {
		# XCreateMouseVoid x y w h [mode]
		[ $Y_OFFSET -gt -80 ] && XCreateMouseVoid 0 $[-$Y_OFFSET+1200] 1920 $[80+$Y_OFFSET] u &	# prevent mouse from entering void at the bottom
		[ $Y_OFFSET -lt 0 ] && XCreateMouseVoid 0 0 1920 $[-$Y_OFFSET] d &			# prevent mouse from entering void at the top
		[ $X_HURDLE -gt 0 ] && XCreateMouseVoid 1920 0 $X_HURDLE 1280 l &			# mouse hurdle

		"$HOME/bin/seticc.sh"									# adjust color profile on 2nd display
		"$HOME/bin/setinput.sh" tablet newrandr							# reset wacom output mappings
	}
fi
