#!/bin/bash
## Implement equalizer for Thinkpad T/W520/530 onboard speakers (uses slightly more CPU power)
## EQ values approximated from http://yohng.com/software/speakerfix.html

## FIXME: Don't use on headphones (only when "active port: <analog-output-speaker>")

# all units in dB
# Hz: 50, 100, 156, 220, 311, 440, 622, 880, 1.25k, 1.75k, 2.5k, 3.5k, 5.0k, 10k, 20k
###EQ=7,13,21,26,10,11,6,-4,-10,-1,-2,-1,-2,2,0
###PREAMP=-24
# halve values to avoid needing massive preamp (which makes it too quiet)
EQ=3.5,6.5,10.5,13,5,5.5,3,-2,-5,-0.5,-1,-0.5,-1,1,0
PREAMP=-12


if [[ $1 ]]; then
	echo "Unloading EQ..."
	pacmd unload-module module-ladspa-sink
	exit 0
fi

pluginlist=$(listplugins)
for plugin in mbeq_1197 amp_1181; do
	grep -q $plugin <<< "$pluginlist" || {
		echo "Error: $plugin not found, is swh-plugins installed?"
		exit 1
	}
done

defaultsink="$(pacmd stat | awk '/Default sink name:/{print $4}')"
onboardsink="$(pacmd list-sinks | grep "name:" | grep -o "alsa_output.pci.*analog-stereo")"
[[ "$onboardsink" ]] || {
	echo "Error: Onboard audio device not found!"
	exit 1
}

# unload old instance if loaded
pacmd list-modules | grep -q module-ladspa-sink && pacmd unload-module module-ladspa-sink

echo "Loading EQ..."

# load equalizer module
pacmd load-module module-ladspa-sink \
sink_name=equalizer  sink_properties=device.description="(Equalizer_no_preamp)" \
master="$onboardsink" \
plugin=mbeq_1197  label=mbeq \
control="$EQ"

# load preamp module
pacmd load-module module-ladspa-sink \
sink_name=equalizer_preamp  sink_properties=device.description="Equalizer_on_Built-in_Audio" \
master=equalizer \
plugin=amp_1181  label=amp \
control="$PREAMP"

# if onboard sound was default sink, set eq as default sink instead
if [[ $defaultsink == $onboardsink ]]; then
	pacmd set-default-sink equalizer_preamp
fi

# transfer currently running onboard audio streams to eq
pacmd list-sink-inputs | grep -A4 index | while read line; do
	grep -q "^index:" <<< "$line" && {
		sinkinput=$(awk '{print $2}' <<< "$line")
		continue
	}
	grep -q "^driver:" <<< "$line" && {
		driver=$(awk -F'<|>' '{print $2}' <<< "$line")
		continue
	}
	grep -q "^sink:" <<< "$line" && {
		sink=$(awk -F'<|>' '{print $2}' <<< "$line")
		if [[ $sink == $onboardsink && $driver == "protocol-native.c" ]]; then
			pacmd move-sink-input $sinkinput equalizer_preamp
		fi
		continue
	}
done
