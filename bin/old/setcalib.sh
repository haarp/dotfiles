#!/bin/bash
## Set the ICC profiel calibration, optionally redshift at evenings too
##
# Some color tools: https://news.ycombinator.com/item?id=10575921
# When xrandr --setprovideroutputsource is active, argyll-dispwin and xcalib trigger X microfreezes during their run
# xcalib is worse


# List all screens, empty if unknown
CALFILE[0]="$HOME/.local/share/icc/dispcalGUI ThinkPad Display 1920 2012-04-30 D6500 L HQ 3xCurve+MTX.icm"
CALFILE[1]=""
CALFILE[2]=""

# Minimum percentage of blue in redshift mode
MINBLUE=45
# Location code for redshift mode (use https://weather.codes/search/)
LOCATION=GMXX1002	# Munich


# Initial calibration, including _ICC_PROFILE atom
##for i in ${!CALFILE[@]}; do
##	[[ ${CALFILE[$i]} ]] || CALFILE[$i]="/usr/share/DisplayCAL/presets/default.icc"
##	argyll-dispwin -d $(($i+1)) -I "${CALFILE[$i]}" &	# counts displays from 1
##								# and doesn't necessarily have the same order as xcalib! >:(
##	# work through intel-virtual-output:
##	##argyll-dispwin -display :8 -d 1 -I "$CALFILE"
##done 2>/dev/null

# $1: blue (percentage of), 1 - 100, optional
# also reduces green somewhat
calibrate() {
	[[ $1 ]] && parm="-blue 1.0 1.0 $1 -green 1.0 1.0 $(( 100 - (100-$1)/2 ))"

	# xcalib does something that prevents xscreensaver from resetting the color profile on fade/unfade (using XF86VidMode{Get,Set}GammaRamp)
	# xcalib does not handle multimonitor well (https://github.com/zoltanp/xrandr-invert-colors#alternatives)

	for i in ${!CALFILE[@]}; do
		[[ ${CALFILE[$i]} ]] || CALFILE[$i]="/usr/share/DisplayCAL/presets/default.icc"
		xcalib -output $i $parm "${CALFILE[$i]}"
	done 2>/dev/null
}

findblue() {
	local current=$(date +%k%M)

	if (( $current > $sunset )); then
		blue=$(( 100 - ($current-$sunset)/2 ))
		(( $blue < MINBLUE )) && blue=$MINBLUE
	elif (( $current < $sunrise )); then
		blue=$(( 100 - ($sunrise-$current) ))
		(( $blue < MINBLUE )) && blue=$MINBLUE
	else
		blue=100
	fi

	echo $blue
}

restoremouse() {
	# Also do this here while we're on it.
	# motherfucking doom3 dares to fuck with my mouse settings!
	for mouse in SynPS2_Synaptics_TouchPad TPPS2_IBM_TrackPoint
	do
		xfconf-query -c pointers -p /$mouse/Acceleration -s 1
		xfconf-query -c pointers -p /$mouse/Acceleration -s 4
		xfconf-query -c pointers -p /$mouse/Threshold -s 1
		xfconf-query -c pointers -p /$mouse/Threshold -s 4
	done
}

if [[ "$1" == "force" ]]; then
	while true; do
		calibrate
##		restoremouse
		sleep 3
	done
elif [[ "$1" == "redshift" ]]; then
	locinfo=$(curl -s https://weather.com/weather/today/l/$LOCATION\
		| grep -oE 'dp0-details-sun(rise|set)">[0-9:]*'\
		| sed 's/dp0-details-sun.*">//')
	sunrise=$(head -n1 <<< "$locinfo")
	sunset=$(tail -n1 <<< "$locinfo")
	sunrise=${sunrise/:}			# remove :
	sunset=${sunset/:}
	sunrise=${sunrise##*(0)}		# remove leading 0
	sunset=${sunset##*(0)}
	((sunset+=1200))			# fucking murkans

	[[ $sunrise && $sunset ]] || exit 66

	oldblue=100
	while true; do
		newblue=$(findblue)
		[[ $? -eq 0 ]] || newblue=$oldblue
		[[ $newblue == $oldblue ]] || {
			echo "blue: $oldblue -> $newblue"
			calibrate $newblue
			oldblue=$newblue
		}
		sleep 300
	done
else
	calibrate "$@"
fi

