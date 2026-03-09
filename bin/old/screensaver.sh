#!/bin/sh
#
# NOTE: Lock with `xset s activate` instead of `xflock4`
#
# xset s <n> <m>:
#	xss-lock -l -- xsecurelock:
#		both screens immediately blank after `n` secs, `m` doesn't do anything
#	xss-lock -n /usr/libexec/xsecurelock/dimmer -l -- xsecurelock
#		intel:
#			dim after `n` secs, blank after `m` additional secs
#		nvidia+i-v-o:
#			blank after `n` secs, unblank, dim, blank >:(
#			→ can be avoided w/ `DISPLAY=:8 xset s noblank` but breaks DPMS
#			→ don't use dimmer, immediate locking hides this issue
#	i-v-o bug:
#		auth prompt blanks away on nvidia screen `n` secs after last keypress
#		→ `xset s` delay > XSECURELOCK_AUTH_TIMEOUT
#	X11 bug:
#		blanking doesn't hold if screensaver inhibitor is active after locking
#	xsecurelock bug:
#		intel will blank twice while moving mouse immediately after locking with XSECURELOCK_BLANK_TIMEOUT=0
#		→ set to 1
#	xsecurelock bug:
#		grabs fall all around all the time
#		→ force grabs

pkill xss-lock && sleep 0.1

XSECURELOCK_AUTH_TIMEOUT=30 \
XSECURELOCK_BLANK_TIMEOUT=1 \
XSECURELOCK_PASSWORD_PROMPT=time_hex \
XSECURELOCK_SHOW_DATETIME=1 \
XSECURELOCK_DATETIME_FORMAT="%Y-%m-%d %H:%M:%S" \
XSECURELOCK_SHOW_HOSTNAME=0 \
XSECURELOCK_SHOW_USERNAME=0 \
XSECURELOCK_FONT="Input Mono Thin" \
XSECURELOCK_AUTH_BACKGROUND_COLOR="rgb:00/42/25" \
XSECURELOCK_FORCE_GRAB=1 \
xss-lock -n /usr/libexec/xsecurelock/dimmer -l -- xsecurelock & disown

# keep current timeout value, but change cycle to 3
timeout="$(xset q)"
timeout="${timeout##*timeout:  }"
timeout="${timeout%% *}"
xset s $timeout 3

echo "Set timeouts with xfce4-power-manager's \"Blank after x\" slider."
echo "the other timeouts (DPMS) will also trigger the screensaver tho."
