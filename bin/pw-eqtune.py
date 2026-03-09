#!/usr/bin/python3

import sys, subprocess, json
import curses, curses.textpad

def main(stdscr):
	# name (eq_bank0)
	#	key (Freq)
	#		value (120)
	#		default (0)
	#		min (0)
	#		max (48000)
	props = dict()

	# value in here
	for e in dump[0]['info']['params']['Props']:
		if 'params' in e:
			# omg, it's flat! turn it into sensible data format
			for i,v in enumerate(e['params']):
				if i%2 == 0:
					name = v.split(':')[0]
					if not name in props: props[name] = dict()
					key = v.split(':')[1]
					if not key in props[name]: props[name][key] = dict()
				elif i%2 == 1:
					props[name][key]["value"] = v
	# default, min, max in here
	for e in dump[0]['info']['params']['PropInfo']:
		name = e['name'].split(':')[0]
		if not name in props:
			continue
		key = e['name'].split(':')[1]
		props[name][key]['default'] = e['type']['default']
		props[name][key]['min'] = e['type']['min']
		props[name][key]['max'] = e['type']['max']


	# start looping
	k = 0
	while k != ord('q'):

		for i,(k,v) in enumerate( props.items() ):

			stdscr.addstr(i*2, 0, str( k ) )

			for j,(l,w) in enumerate( v.items() ):
				stdscr.addstr( i*2+1, 8+j*16, str( l ) )
				stdscr.addstr( i*2+1, 8+j*16+5, str( w['value'] ) )

		win = curses.newwin(5, 60, 5, 10)
		tb = curses.textpad.Textbox(win)
		text = tb.edit()

		stdscr.refresh()

		k = stdscr.getch()



if len(sys.argv) <2:
	print("Need equalizer name as argument!")
	exit(1)
eq_name = sys.argv[1]

# get node id
nodelist = str( subprocess.check_output(["pw-cli", "ls", "Node"]).decode("utf-8") )

candidate = False; found = False
for line in nodelist.splitlines():
	if line.startswith("\tid "):
		node = line.split("id ")[1].split(",")[0]
	if ' \t\tnode.name = "' + eq_name + '"' in line:
		candidate = True
	if ' \t\tmedia.class = "Audio/Sink"' in line and candidate == True:
		found = True
		break
if not found:
	print("Node '" + eq_name + "' not found!")
	exit(1)

# get node info
dump = json.loads( subprocess.check_output(["pw-dump", node]) )

# showtime
curses.wrapper(main)
