#!/usr/bin/python3

import sys, socket

if len( sys.argv ) == 2:
	dscp=int( sys.argv[1], base=16 )
else:
	print( "Gimme a DSCP hex number!" )
	sys.exit()

sock = socket.socket( socket.AF_INET, socket.SOCK_STREAM )
sock.setsockopt( socket.IPPROTO_IP, socket.IP_TOS, dscp<<2 )
sock.connect( ("icanhazip.com", 80) )
sock.send( b"GET / HTTP/1.1\r\nHost:icanhazip.com\r\n\r\n" )
response = sock.recv(4096)
print( response.decode("utf-8") )
