#!/usr/bin/env python3
"""Retrieve GTK-3 theme accent color in #RRGGBB format"""
# also see https://discourse.gnome.org/t/replacement-for-gtk-style-context-get-color/23026

import gi, sys
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk

def rgba_to_hex(color):
	"""Convert Gdk.RGBA to #RRGGBB string"""
	r = int(color.red * 255)
	g = int(color.green * 255)
	b = int(color.blue * 255)
	return f"#{r:02X}{g:02X}{b:02X}"

def print_with_bg_color(color, *args, **kwargs):
	"""Print with 24-bit Gdk.RGBA background color if output is terminal"""
	if not 'file' in kwargs:
		file = sys.stdout
	if file.isatty():
		r = int(color.red * 255)
		g = int(color.green * 255)
		b = int(color.blue * 255)
		print( f"\033[48;2;{r};{g};{b}m", **kwargs, end="" )
		print( *args, **kwargs, end="" )
		print( "\033[49m", **kwargs )
	else:
		print( *args, **kwargs )

widget = Gtk.Button(label="dummy")
success, color = widget.get_style_context().lookup_color("theme_selected_bg_color")

if success:
	print_with_bg_color( color, rgba_to_hex(color) )
	sys.exit(0)
else:
	print( "couldn't get color!", file=sys.stderr )
	sys.exit(1)

# vim: set noexpandtab tabstop=4 shiftwidth=4:
