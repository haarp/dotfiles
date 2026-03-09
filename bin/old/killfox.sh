#!/bin/sh

# Content Process fuck up and won't display properly. KILL THEM
###pkill -f "firefox -contentproc"

# Firefox FUCKS UP ENTIRELY with hw acceleration under certain conditions
# (https://bugzilla.mozilla.org/show_bug.cgi?id=1376176)
# only solution is to DESTROY and restart
# possible candidates:
### user_pref("gfx.webrender.all", true);
### user_pref("layers.acceleration.force-enabled", true);

# don't kill work profile processes, as they're weirdly immune to fucking up (??)
save=$(pgrep -f 'firefox .* -P work.*')
save="$save $(pgrep -P $save)"	# add contentprocs

foxes=$(pgrep 'firefox')
for f in $foxes; do
	[[ "$save" =~ "$f" ]] && continue
	kill "$f"
done

sleep 1
##firefox & disown
