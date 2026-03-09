#!/bin/bash
# TODO: Implement the super resolution trick here: http://www.blitzcode.net/rust.shtml#term_gfx

# https://github.com/blitzcode/term-gfx/blob/master/src/main.rs

if [[ $# != 1 || "$1" == "--help" ]]; then
	echo "Image viewer for terminals that support true colors. Usage: $(basename "$0") imagefile" >&2
	exit 1
elif ! command -v convert >/dev/null; then
	echo "Please install ImageMagick!" >&2
	exit 1
fi

print_line() {
	local line code prevcode char

	local i=0; while (( $i < $width )); do
		if [[ -z ${upper[$i]} ]]; then	# check for alpha
			if [[ -z ${lower[$i]} ]]; then code="\e[49m"; char=' '
			else                           code="\e[38;2;${lower[$i]};49m"; char='▄'
			fi
		elif [[ -z ${lower[$i]} ]]; then
			code="\e[38;2;${upper[$i]};49m"; char='▀'
		else
			code="\e[38;2;${upper[$i]};48;2;${lower[$i]}m"; char='▀'
		fi

		# Avoid unnecessary code repetitions
		if [[ "$code" == "$prevcode" ]]; then line+="$char"
		else                                  line+="$code$char"
		fi
		prevcode="$code"

		i=$((i+1))
	done

	# print assembled line, also reset bg for following line break
	echo -e "$line\e[49m"
}


shopt -s lastpipe # Keep "upper" visible after exiting the loop
export LC_ALL=C # Performance
declare -i width width1 col row red green blue alpha i	# Performance?

COLUMNS=$(tput cols)
width=$(identify -ping -format "%w" "$1") || exit 1
[[ $width -gt $COLUMNS ]] && { width=$COLUMNS; }
width1=$((width-1))	# Pre-compute (performance)

# We can double the vertical resolution by splitting a row into upper and lower halves
# and using foreground/background colors together to draw two colors in one char
upper=(); lower=()

# Start
# FIXME: Some versions of ImageMagick need the color values (`/1`) divided by 256 instead!
# NOTE: We expect RGBA channels. Use `-colorpsace RGB` to prevent grayscale images from messing this up
convert -thumbnail $width -background transparent -colorspace RGB -depth 8 -channel A -threshold 50% +channel "$1" txt:- \
| tail -n+2 | tr -cs '0-9\n' ' ' \
| while read col row red green blue alpha junk; do
	if (( row%2 == 0 )); then
		if (( 10#$alpha == 0 )); then upper[$col]=""
		else                       upper[$col]="$((red/1));$((green/1));$((blue/1))"
		fi
	else
		if (( 10#$alpha == 0 )); then lower[$col]=""
		else                       lower[$col]="$((red/1));$((green/1));$((blue/1))"
		fi

		# After finishing the lower half, print the row
		if (( $col == $width1 )); then
			print_line
			upper=()	# mark this row as done
		fi
	fi
done

# Print the last row if an upper half remains from the loop
if [[ -n "$upper" ]]; then
	lower=()
	print_line
fi

echo -ne "\e[0m\e[K"	# \e[K is useful when the terminal is resized while this script is still running
