#!/bin/bash

# Fucking stop truncating the motherfucking history!
export HISTSIZE=-1
export HISTFILESIZE=$HISTSIZE


# Create cache/temp dirs
# NOTE: some early starters (gnome-keyring) need ~/.cache earlier → handled by /etc/local.d
# don't forget correct \ at end of lines that need it
mkdir -p -m 700 \
/tmp/cache-$USER \
/tmp/.wine-$UID \
/tmp/.wine-$UID/temp \
$HOME/.cache/gvfs-metadata
# Wine temp
for _temp in \
	$HOME/.wine*/drive_c/windows/temp \
	$HOME/.wine*/drive_c/users/*/Temp \
	$HOME/.wine*/drive_c/users/*/Local\ Settings/Temporary\ Internet\ Files
do
	if [[ ! -L "$_temp" && -d "$_temp" ]]; then
		rm -rf "$_temp"
		ln -s /tmp/.wine-$UID/temp/ "$_temp"
	fi
done
# Electron cache (https://github.com/electron/electron/issues/8124)
# steal list from https://github.com/danisztls/ephemeral/blob/main/ephemeral
# FIXME: doesn't create dirs in cache?
# FIXME: firejailed apps can't access destination
for _app in \
	discord \
	Signal \
	SideQuest
do
	for _temp in \
		Cache \
		CachedData \
		CachedExtensions \
		"Code Cache" \
		GPUCache
	do
		if [[ "$_app" && "$_temp" && ( -d "$HOME/.config/$_app/$_temp" || -L "$HOME/.config/$_app/$_temp" )  ]]; then
			echo "$HOME/.cache/$_app/$_temp"
			mkdir -p -m 700 "$HOME/.cache/$_app/$_temp"
			rm -rf "$HOME/.config/$_app/$_temp"
			ln -s "$HOME/.cache/$_app/$_temp/" "$HOME/.config/$_app/$_temp"
		fi
	done
done
# Steam Electron cache
mkdir -p -m 700 "$HOME/.cache/Steam"
for _app in \
	$HOME/.local/share/Steam/config/htmlcache\
	$HOME/.wine*/drive_c/users/*/Local\ Settings/Application\ Data/Steam/htmlcache
do
	for _temp in Cache "Code Cache" GPUCache; do
		if [[ ! -L "$_app/$_temp" && -d "$_app/$_temp" ]]; then
			rm -rf "$_app/$_temp"
			ln -s $HOME/.cache/Steam/ "$_app/$_temp"
		fi
	done
done

unset _app _temp

# Video setup
# FIXME: runs too late for xfce4-display-settings to pick up on login?
if [[ $DISPLAY ]]; then
##	xrandr | awk '/connected/{print $1}' | while read display; do
##		xrandr --output $display --set TearFree on
##	done
	# amdgpu
##	$HOME/bin/custom_mode.sh eDP 2560 1600 67.5
##	$HOME/bin/custom_mode.sh DisplayPort-1 3840 1600 82
	# modesetting
##	$HOME/bin/custom_mode.sh eDP-1 2560 1600 67.5
##	$HOME/bin/custom_mode.sh DP-2 3840 1600 82
	# new thinkpad
	$HOME/bin/custom_mode.sh eDP-1 1920 1080 82.5
	$HOME/bin/custom_mode.sh DP-1 3840 1600 82
fi
# Input setup
xinput map-to-output "ELAN Touchscreen" eDP-1

# Nvidia video setup
# Underclock to save power when Nvidia goes to higher P-states (which is all the fucking time)
# NOTE: Core below -515 (15MHz bins) will lock GPU into highest P-state
# NOTE: Memory can't go below that of second-highest P-state, attempts will lock out the highest P-state
# NOTE: to edit specific P-states: [gpu:0]/GPUGraphicsClockOffset[$level]=$offset, [gpu:0]/GPUMemoryTransferRateOffset[$level]=$offset
###nvidia-settings \
###	-a [gpu:0]/GPUGraphicsClockOffsetAllPerformanceLevels=-500 \
###	-a [gpu:0]/GPUMemoryTransferRateOffsetAllPerformanceLevels=-199 \
###	2>/dev/null &
# Enable ForceCompositionPipeline to prevent tearing, disable Flipping to recover some input lag due to that
# EDIT: nope, prevents GPU from dropping to lowest P-state
###nvidia-settings --assign CurrentMetaMode="nvidia-auto-select +0+0 { ForceCompositionPipeline = On }" --assign AllowFlipping=0 &


# LD_PRELOAD
# Disable Cripple-AMD CPU dispatcher in Intel Math Kernel Library (https://danieldk.eu/Intel-MKL-on-AMD-Zen)
# FIXME: these break Steam games launching, unless they're given launch options `LD_PRELOAD="libpthread.so.0 libGL.so.1" %command%`
# outdated, doesn't work any longer
###export MKL_DEBUG_CPU_TYPE=5
# try this
###if [[ -e "$HOME/bogusintel.so" ]]; then
###	export LD_PRELOAD=""$HOME/bogusintel.so" $LD_PRELOAD"
###fi

# Use my ssh-askpass, force it for consistency (see https://bugzilla.mindrot.org/show_bug.cgi?id=69)
export SSH_ASKPASS="$HOME/bin/ssh-askpass-wrapper"
export SSH_ASKPASS_REQUIRE="force"

# Move some stuff to their proper XDG places
# also see https://github.com/b3nj5m1n/xdg-ninja/tree/main/programs
###export SCREENRC="$HOME/.config/screen/screenrc"	# skip for now, due to bashrc delivering this
export SQLITE_HISTORY="$HOME/.local/state/sqlite_history"
###export XCOMPOSEFILE="$HOME/.config/X11/XCompose"	# doesn't work! (at least in xed 3.4.3)

# Use X input method so ~/.XCompose is parsed
# FIXME: but causes jumps with smooth scrolling... https://github.com/linuxmint/mintlocale/issues/41
# TODO: Try again in newer GTK (3.20+), try "gtk-im-context-simple", try "uim" (with app-i18n/uim)
###export GTK_IM_MODULE=xim
###export QT_IM_MODULE=$GTK_IM_MODULE

# Disable GTK+-3 CSD with gtk3-nocsd
# EDIT: not needed anymore, recent Xfce allows disabling CSD
###if [[ -e /usr/lib64/libgtk3-nocsd.so.0 ]]; then
###	export GTK_CSD=0
###	export LD_PRELOAD="/usr/lib64/libgtk3-nocsd.so.0 $LD_PRELOAD"
###fi

# gtk3-classic settings (https://github.com/lah7/gtk3-classic#patches)
###export GTK_BACKDROP=1
export GTKM_INSERT_EMOJI=1

# Make QT not scan Wifi all the fucking time (https://www.lesswrong.com/posts/8hxvfZiqH24oqyr6y/wireless-is-a-trap https://apple.stackexchange.com/a/312388)
export QT_BEARER_POLL_TIMEOUT=-1
# Make GTK+ apps stop trying to contact non-existent accessibility bus and complaining about it
export NO_AT_BRIDGE=1

# Make QT copy GTK's style (needs dev-qt/qtstyleplugins)
# https://wiki.archlinux.org/title/Uniform_look_for_Qt_and_GTK_applications#QGtkStyle
# mostly doesn't work, very few themes supply compatible GTK2 settings
export QT_QPA_PLATFORMTHEME="gtk2"
# Make Java's GTK+ style work. Maybe.
# NOPE, enables some awkward DPI scaling
export _JAVA_OPTIONS="-Dawt.useSystemAAFontSettings=on" # -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel"

# Make QT apps not scale horribly
# https://wiki.archlinux.org/title/HiDPI#Qt_5
# also consider `QT_FONT_DPI=96` to override font DPI scaling
# KeePassXC: https://github.com/keepassxreboot/keepassxc/issues/2815
# KeePassXC: looks about right on 1.25
# OpenSCAD looks too big w/ 1.25, breaks w/ <1.0
# VirtualBox looks too big w/ 1.25, breaks w/ <1.0
export QT_AUTO_SCREEN_SCALE_FACTOR=0	# replaced by QT_ENABLE_HIGHDPI_SCALING in Qt-5.14
export QT_SCREEN_SCALE_FACTORS=1.0

# Make Chromium not scale horribly
# source system-wide settings too
for f in /etc/chromium/*; do [[ -f "$f" ]] && source "$f"; done
export CHROMIUM_USER_FLAGS="$CHROMIUM_FLAGS"
CHROMIUM_USER_FLAGS+=" --force-device-scale-factor=1.33333"

# Firefox: Fix stuck tooltips (https://bugzilla.mozilla.org/show_bug.cgi?id=1569439#c25)
export MOZ_GTK_TITLEBAR_DECORATION=system

# Disable winemenubuilder
export WINEDLLOVERRIDES=winemenubuilder.exe=d

# Make Nextcloud client STOP FUCKING LOGGING EVERY MOVED BIT
# https://github.com/nextcloud/desktop/issues/5302#issuecomment-2139805467
# it even motherfucking moves log archives from the log/ dir to the CONFIG DIR (on restart?) WHAT THE FUCK
# also chattr +i the fucking Nextcloud_sync.log, QT_LOGGING_RULES doesn't affect it
export QT_LOGGING_RULES='*=false'

# vim: set filetype=sh: noexpandtab tabstop=4 shiftwidth=4
