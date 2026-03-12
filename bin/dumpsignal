#!/bin/bash
# Dump Desktop Signal's database. Spits out JSON to stdout
# make sure to use the NEWEST upstream sqlcipher. even minor version are not backwards compatible!
# https://github.com/carderne/signal-export/issues/26#issuecomment-1034198680
# as of 2023-08-06: 4.5.1 fails, 4.5.4 works

if [[ -t 1 ]]; then
	echo "Spits JSON out to stdout. You might wanna redirect it."
	exit 1
fi

key="\"x'$(awk -F'"' '/key/{ print $4}' "$HOME/.config/Signal/config.json")'\""

sqlcipher -list -noheader "$HOME/.config/Signal/sql/db.sqlite" "PRAGMA key = $key; select json from messages;" | tail -n+2
