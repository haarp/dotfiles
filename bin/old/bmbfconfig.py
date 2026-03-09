#!/usr/bin/env python3
# Interact with BMBF's config
# FIXME: Album covers go missing?!

# Useful stuff:
## Wake the fucking thing up:	adb shell dumpsys power | grep -q "mWakefulness=Awake" || adb shell input keyevent KEYCODE_POWER
## Start BMBF			adb shell am start com.weloveoculus.BMBF/.MainActivity
## Kill BMBF:			adb shell am force-stop com.weloveoculus.BMBF
## Show installed BS version:	adb shell dumpsys package com.beatgames.beatsaber | grep versionName


import sys
import urllib.request
import json

if len(sys.argv) < 2:
	print( "Gonna need the IP address of your Quest running BMBF..." )
	exit(1)

try:
	data = urllib.request.urlopen("http://" + sys.argv[1] + ":50000/host/beatsaber/config").read()
except:
	print( "Grabbing BMBF JSON failed, is IP correct and BMBF running?" )
	exit(2)
data = json.loads( data )

# isolate Config object (as per https://github.com/ComputerElite/wiki/wiki/BMBF_technical#how-to-alter-the-bmbf-config)
data = data["Config"]

# write back as config.json (human-readable)
open( "config.json", "w" ).write( json.dumps(data, indent=4) )

print( "Done, now edit `config.json`, or replace it with a backup (sdcard/BMBFData/config.json)." )
print( "Then upload: curl -i http://" + sys.argv[1] + ":50000/host/beatsaber/config --upload-file config.json" )
print( "(failure likely means BMBF can't find a song/mod you're trying to add - `Reload Songs Folder` may help)" )
