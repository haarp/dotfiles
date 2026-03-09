#!/bin/sh
## Toggle mouse cursor between the Thinkpad W700ds's displays

Y_OFFSET=-40	# Y offset of 2nd display to line up with main display (-80 to 0)
X_OFFSET=120	# X offset of 2nd display (void between displays) (any value)

state=$(switchscreen -p | awk '{print $4}')
x=$(echo $state | awk -F, '{print $1}')
y=$(echo $state | awk -F, '{print $2}')

if [ $x -le $[1920+($X_OFFSET/2)] ]; then
	switchscreen -c $[ 1920+$X_OFFSET+(768/2) ],$[ $y+$Y_OFFSET ]
else
	switchscreen -c $[ 1920/2 ],$[ $y-$Y_OFFSET ]
fi
