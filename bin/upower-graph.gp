#!/usr/bin/gnuplot -c
# Visualize Laptop battery charge and rate
# run as: `upower-graph.gp <battname> [time in s]` with battname from /var/lib/upower

if (ARGC == 0) {
	print "Need a battery name!"
	exit
}

battery = ARG1
cfile = "/var/lib/upower/history-charge-" . battery . ".dat"
rfile = "/var/lib/upower/history-rate-" . battery . ".dat"

if (ARGC == 2) {
	HISTORY = real(ARG2)
} else {
	HISTORY = 32*3600
}

set datafile missing "0.000"

set xdata time
set timefmt "%s"
set format x "%H:%M"

set xrange [time(0)-HISTORY:]
set yrange [0:100]
set y2range [0:]
set xtics rotate by -30
set ytics 10 nomirror
set y2tics

set key left

plot \
cfile using ($1+(`date +%z`*36)):($2) with lines title "← charge (%)    " axes x1y1, \
rfile using ($1+(`date +%z`*36)):(stringcolumn(3) ne "discharging"? ($2>0.1? $2 : NaN) : NaN ) with lines title "charge rate (W) →" axes x1y2, \
rfile using ($1+(`date +%z`*36)):(stringcolumn(3) eq "discharging"? ($2>0.1? $2 : NaN) : NaN ) with lines title "dischrg rate (W) →" axes x1y2

# pause until mouse1 is pressed, then exit
# so we don't need -p anymore and can manipulate the graph
pause mouse button1
