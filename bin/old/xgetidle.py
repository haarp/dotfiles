#!/usr/bin/python3

import ctypes, os, subprocess

class XScreenSaverInfo( ctypes.Structure ):
	_fields_ = [
		("window",	ctypes.c_ulong),
		("state",	ctypes.c_int),
		("kind",	ctypes.c_int),
		("since",	ctypes.c_ulong),
		("idle",	ctypes.c_ulong),
		("event_mask",	ctypes.c_ulong)
]

xlib = ctypes.cdll.LoadLibrary("libX11.so.6")
xss = ctypes.cdll.LoadLibrary("libXss.so.1")

display = xlib.XOpenDisplay(os.environ["DISPLAY"], 'ascii')

xss.XScreenSaverAllocInfo.restype = ctypes.POINTER(XScreenSaverInfo)
xssinfo = xss.XScreenSaverAllocInfo()
# this segfaults
xss.XScreenSaverQueryInfo(display, xlib.XDefaultRootWindow(display), xssinfo)

print(xssinfo.contents.idle)
