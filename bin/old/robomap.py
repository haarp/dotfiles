#!/usr/bin/python
# https://www.rapidtables.com/code/text/ascii-table.html
# https://github.com/Hypfer/Valetudo/discussions/1544
# byte->char: chr(), char->byte: ord()

import sys, os

term_format = [ "\033[1m", "\033[4m", "\033[9m", "\033[0m" ]	# bold, underline, strikeout, reset all
term_fg = [ "\033[90m", "\033[91m", "\033[92m", "\033[93m", "\033[94m", "\033[95m", "\033[96m", "\033[97m", "\033[39m"]
term_bg = [ "\033[40m", "\033[41m", "\033[42m", "\033[43m", "\033[44m", "\033[45m", "\033[46m", "\033[47m", "\033[49m"]


f = open(sys.argv[1], "rb")

f.read(0x16)	# discard some header bytes
width = f.read(2)
width = int.from_bytes( width, byteorder="little" )
f.read(6)	# discard some header bytes

print( "Width: " + str(width) + " pixels" )

input = f.read()

map = list()	# one string per row
y=-1
for i, b in enumerate(input):
	if i % width == 0:
		y += 1
		map.append(str())


	if b <= 0x06:
		# floor
		map[y] += term_bg[2] + f"{b:02x}" + term_bg[-1]

	elif b<0x80 and b>=0x70:
		# newly seen/low confidence?
		# 79: appearing door, still white
		map[y] += term_bg[4] + f"{b:02x}" + term_bg[-1]

	elif b == 0x80:
		# uncharted
		map[y] += term_fg[0] + f"{b:02x}" + term_fg[-1]

	elif b == 0x82:
		# ??
		map[y] += term_bg[6] + f"{b:02x}" + term_bg[-1]
	elif b == 0x84:
		# staging? sometimes?
		map[y] += term_bg[1] + f"{b:02x}" + term_bg[-1]

	elif b >= 0xf0:
		# wall
		# f7: appearing door, black already
		# f8: random pixel near charger
		map[y] += term_bg[5] + f"{b:02x}" + term_bg[-1]

	else:
		# bb: random black pixel near charger
		map[y] += term_format[-1] + f"{b:02x}" + term_format[-1]


os.system("bash -c 'tput rmam'")

for line in reversed(map):
	print(line[1200:])	# skip uninteresting chars on each

os.system("bash -c 'tput smam'")





quit()



















f = open(sys.argv[1], "rb")

f.read(0x2c)	# discard some header bytes
width = f.read(2)
width = int.from_bytes( width, byteorder="little" )

input=f.read()

map = list()	# one string per row
y=-1
for i, b in enumerate(input):
	if i % width == 0:
		y += 1
		map.append(str())

	segment_offset = b - b%8
	segment = int(segment_offset/8) % 7 + 1		# let's support 7 segments for now, skip 0 (≘ black)

	if b <= 0x01:	# uncharted
		map[y] += term_fg[0] + f"{b:02x}" + term_fg[-1]

	elif b <= 0x07:	# staged (anonymous) walls
		map[y] += term_fg[1] + f"{b:02x}" + term_fg[-1]

	elif b%8 == 0:	# almost-wall
		map[y] += term_bg[0] + f"{b:02x}" + term_bg[-1]

	elif b%8 == 1:	# wall (bold)
		map[y] += term_format[0] + term_bg[segment] + f"{b:02x}" + term_format[-1]

	elif b%8 == 7:	# floor
		map[y] += term_bg[segment] + f"{b:02x}" + term_bg[-1]

	else:
		map[y] += term_format[2] + f"{b:02x}" + term_format[-1]


os.system("bash -c 'tput rmam'")

for line in map:
	print(line[1200:])	# skip uninteresting chars on each

os.system("bash -c 'tput smam'")
