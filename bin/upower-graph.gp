#!/usr/bin/gnuplot

CFILE = "/var/lib/upower/history-charge-5B10W139-50-3464.dat"
RFILE = "/var/lib/upower/history-rate-5B10W139-50-3464.dat"
HISTORY = 32*3600

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
CFILE using ($1+(`date +%z`*36)):($2) with lines title "← charge (%)    " axes x1y1, \
RFILE using ($1+(`date +%z`*36)):(stringcolumn(3) ne "discharging"? ($2>0.1? $2 : NaN) : NaN ) with lines title "charge rate (W) →" axes x1y2, \
RFILE using ($1+(`date +%z`*36)):(stringcolumn(3) eq "discharging"? ($2>0.1? $2 : NaN) : NaN ) with lines title "dischrg rate (W) →" axes x1y2

# pause until mouse1 is pressed, then exit
# so we don't need -p anymore and can manipulate the graph
pause mouse button1
