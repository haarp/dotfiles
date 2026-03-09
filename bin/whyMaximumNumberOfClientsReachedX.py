#!/usr/bin/python2

# https://lists.fedoraproject.org/pipermail/test/2009-May/081959.html
# from http://askubuntu.com/questions/4499/how-can-i-diagnose-debug-maximum-number-of-clients-reached-x-errors/6639#6639

from subprocess import Popen, PIPE

client_sockets = []
match = 0

ns = Popen(["netstat", "-an", "--unix"], stdout=PIPE)
output = ns.communicate()[0]
for line in output.split('\n'):
	if line.find("X11-unix") != -1:
		match = 1
	elif match:
		match = 0
		print line
		lineSplit = line.split()
		lineLen = len(lineSplit)
		print lineLen
		if lineLen == 6:
			inode = lineSplit[5] 
		elif lineLen == 9:
			inode = lineSplit[7]
		else:
			inode = line.split()[6]
		print inode
		client_sockets.append(inode)

lsof = Popen(["lsof", "-U", "+c0", "-w"], stdout=PIPE)
output = lsof.communicate()[0]
for line in output.split('\n'):
	try:
		inode = line.split()[7]
		if inode in client_sockets:
			print line
	except:
		pass
