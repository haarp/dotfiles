#!/usr/bin/python

###	# Command-line tool for querying ETQW servers
	# Not anymore. Modified by HAARP to give Fullname and Username

import sys, socket, time, os, urllib, sqlite3
from struct import *

strip_map = lambda mapname: mapname[mapname.rfind("/")+1:mapname.rfind(".entities")]

def remove_colour(string):
	""" sed "s/\^.//g" - so much easier :("""
	out = string
	while 1:
		i = out.find("^")
		if (i == -1): # No colour codes
			break
		elif (i == 0): # Colour code at start of string
			out = out[2:]
		elif (i == len(out) - 2): # Colour code at end of string
			out = out[:i]
		elif (i == len(out) - 1): # ^ at end of string
			out = out[:i]
		else: # Colour code somewhere in the string
			out = out[:i] + out[i + 2:]
	return out

def getInfoEx(IP, port = 27733):
	# Get data from the server
	blocksize = 2048
###	serverinfo = {"ip":IP, "port":port}
	serverinfo = {}
	sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
	ping1 = time.time()
	infostring = "\xff\xffgetInfoEx\x00"
	sock.settimeout(5)
	if (sock.sendto(infostring, (IP, port)) < len(infostring)): return 1 # Return an error if the data coult not be sent
	try:
		dat = sock.recv(blocksize)
	except socket.timeout:
		return 1
	ping2 = time.time()
#	serverinfo["ping"] = int(round((ping2 - ping1) * 1000)) # time.time() is in seconds, we want it in milliseconds for the ping
	data = dat
	sock.settimeout(5)
	while len(dat) >= blocksize:
		try:
			dat = sock.recv(blocksize)
			data += dat
		except:
			break

	f = open("getinfoex.bin", "wb")
	f.write(data)
	f.close()

	# Turn data into useful output
	# Add the information from the keys/values into the serverinfo dictionary
	headerlength = 33 # 33 bytes of header before anything useful
	pairs = data[headerlength:data.find("\x00\x00", headerlength)]

###	pairs = pairs.split("\x00")
###	for key in range(0, len(pairs), 2):
###		if (key == len(pairs) - 1): break
###		serverinfo[pairs[key].lower()] = pairs[key + 1]

	# Now for players
	playerdata = data[data.find("\x00\x00\x00", headerlength) + 3:] # Offset the beginning by 3 bytes to account for null bytes and go to the end of the data string since we can check for player 32 later

	offset = 0
	serverinfo["players"] = []

	for i in range(32):
		#short ping;
		#char name[32]; // NULL-terminated
		#byte clanTagPosition; // 0: prefix, 1: suffix
		#char clanTag[32]; // NULL-terminated
		#byte isBot;
		if (playerdata[offset] == "\x20"): break # Last player / no players on server
		ping = unpack("h", playerdata[offset + 1: offset + 3])[0]
		nameoffset = playerdata.find("\x00", offset + 4)
		name = playerdata[offset + 3:nameoffset]
		clantagpos = unpack("b", playerdata[nameoffset + 1])[0]
		clantagoffset = playerdata.find("\x00", nameoffset + 2)
		clantag = playerdata[nameoffset + 2:clantagoffset]
		isbot = unpack("b", playerdata[clantagoffset + 1])[0]
		offset = clantagoffset + 2
		serverinfo["players"].append({"ping":ping, "name":name, "clantagpos":clantagpos, "clantag":clantag, "isbot":isbot})

###	serverinfo["numplayers"] = i

	playersend = offset + 1

	# Misc. info after the players
	#int osMask;
	#byte isRanked;
	#int timeLeft;
	#byte gameState;
	#byte serverType; // 0 for regular server, 1 for tv server
###	serverinfo["osmask"], \
###	serverinfo["isranked"], \
###	serverinfo["timeleft"], \
###	serverinfo["gamestate"], \
###	serverinfo["tvserver"] = unpack("=ibibb", playerdata[playersend:playersend + 11])
	
	offset = playersend + 11

###	if (serverinfo["tvserver"] == 0):
###		#byte numInterestedClients; // number of clients considering joining this server
###		serverinfo["interestedclients"] = unpack("=b", playerdata[offset:offset + 1])[0]
###		offset += 1
###	else:
###		# Not tested
###		#int numConnectedClients; // number of clients on the tv server
###		#int maxClients; // max clients that the tv server supports
###		serverinfo["connectedtvclients"], \
###		serverinfo["maxtvclients"] = unpack("=ii", playerdata[offset:offset + 8])
###		offset += 8

	# Extra player info - only works if mods don't change it (even then, this is broken)

	#for i in range(32):
		##byte clientIndex; // 32 for end of list
		##float xp; // total xp
		##string teamName; // empty for spectator
		##int totalKills; // total players killed
		##int totalDeaths; // total times died
		#if (playerdata[offset] == "\x20"): break # Last player / no players on server
		#offset += 1
		#xp = unpack("f", playerdata[offset:offset + 4])[0]
		#offset += 4
		#team = playerdata[offset:playerdata.find("\x00", offset + 1)]
		#offset = playerdata.find("\x00", offset + 1)
		#kills, deaths = unpack("<ff", playerdata[offset:offset + 8])
		#offset += 9
		#if (team == ""):team = "spectator"
		#serverinfo["players"][i]["xp"] = int(round(xp))
		#serverinfo["players"][i]["team"] = team
		#serverinfo["players"][i]["kills"] = kills
		#serverinfo["players"][i]["deaths"] = deaths

	return serverinfo

def players(playerinfo):
###	print("\nName\tPing\tIs bot?")
		
	for player in playerinfo:
		out = ""
		if (player["clantagpos"] == 1):
###			out += "%s%s" % (remove_colour(player["name"]), remove_colour(player["clantag"]))
			out += "%s%s\t%s" % (remove_colour(player["name"]), remove_colour(player["clantag"]), remove_colour(player["name"]))
		else:
###			out += "%s%s" % (remove_colour(player["clantag"]), remove_colour(player["name"]))
			out += "%s%s\t%s" % (remove_colour(player["clantag"]), remove_colour(player["name"]), remove_colour(player["name"]))
###		out += "\t%i\t%i" % (player["ping"], player["isbot"])

		#if (player.has_key("team") & player.has_key("xp") & player.has_key("kills") & player.has_key("deaths")):
			#out += "\t%s\t%i\t%i\t%i" % (player["team"], player["xp"], player["kills"], player["deaths"])
		print(out)

def simple_output(response):
	for key in response.keys():
		if (key != "players"):
			print("%s = %s" % (key, response[key]))
	players(response["players"])

def pretty_output(response):
	print("%s\nIP:Port: %s:%s\nPlayers: %s/%s\nMap: %s\nPing: %s" % (
		remove_colour(response["si_name"]), \
		response["ip"], \
		response["port"], \
		response["numplayers"], \
		response["si_maxplayers"], \
		response["si_map"][5:response["si_map"].find(".entities")], \
		response["ping"]))

	try:
		print("Gametype: %s" % {\
		"sdGameRulesCampaign"		:"Campaign", \
		"sdGameRulesObjective"		:"Objective", \
		"sdGameRulesStopWatch"		:"Stopwatch", \
		"sdGameRulesCompetition"	:"Competition"}[response["si_rules"]])
	except KeyError:
		print("Gametype: %s" % (response["si_rules"]))

	players(response["players"])

def irc_output(response):
	print("%s (connect %s:%s), %s / %s players, %s" % (\
		      remove_colour(response["si_name"]), \
		      response["ip"], \
		      response["port"], \
		      response["numplayers"], \
		      response["si_maxplayers"], \
		      strip_map(response["si_map"])))
	names = ""
	for player in response["players"]:
		names += "%s " % remove_colour(player["name"])
	print(names)

def simple(argv):
	IP, port = argv[-1].split(":")
	port = int(port)
	response = getInfoEx(IP, port)
	if (response == 1):
		print("Connection timed out.")
		return None
	elif (response == 2):
		print("Server returned invalid data.")
		return None
	else:
		simple_output(response)
		#pretty_output(response)
		#irc_output(response)
		return response

if (__name__ == "__main__"):
	response = simple(sys.argv)
