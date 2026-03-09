#!/usr/bin/python3
# Display stuff in Xfce4's generic monitor plugin, by haarp
# cpufreq-aperf.c is helpful
# <txt>Text to display</txt>
# <img>Path to the image to display</img>
# <tool>Tooltip text</tool>
# <bar>Percentage to display in the bar</bar>
# <click>The command to be executed when clicking on the image</click>
# <txtclick>The command to be executed when clicking on the text</txtclick>
#
# TODO: top 3 most active processes in popup?


from glob import glob
from subprocess import Popen, PIPE

# steal these from thinkfan.py
def is_module_loaded( name ):
	for line in open( "/proc/modules" ):
		if line.startswith(name):
			return True
	return False
def get_cpu_temp():
	"""Return CPU temp in °C, -100 on failure"""

	try:
		# (sometimes) nicely averaged
		return int( open( glob("/sys/devices/platform/thinkpad_hwmon/hwmon/*/temp1_input")[0] ).read() )//1000
	except Exception as err:
		print( str(err), file=sys.stderr )

		# sometimes thinkpad_acpi screws up. fall back to module. this one's not averaged and spiky tho :(
		for dir in glob("/sys/class/hwmon/hwmon*"):
			if( "coretemp" in open( dir + "/name" ).read() ) or ( "k10temp" in open( dir + "/name" ).read() ):
				try:
					return int( open( dir + "/temp1_input" ).read() )//1000
				except Exception as err:
					print( str(err), file=sys.stderr )
					return -100

def cpu_collection():
	statsfile = "/dev/shm/genmon-haarp"

	# do first
	# TODO: get some averaging in here? otherwise it fluctuates wildly under load of ourselves
	speeds = []
	for file in glob("/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"):
		speeds.append( int( open(file).read() )/1000 )

	try:
		# needs root access starting with https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/commit/?id=19f6d91bdad42200aac557a683c17b1f65ee6c94
		joules = Popen( ["sudo", "/bin/cat", "/sys/devices/virtual/powercap/intel-rapl/intel-rapl:0/energy_uj"], stdout=PIPE )
		joules = int( joules.stdout.read() )/1000000
	except:
		joules = 0

	# retrieve old stats
	try:
		oldjoules = float( open( statsfile ).readline() )
		##interval = time.time() - os.path.getmtime( statsfile )
		interval = 4	# HACK: increase accuracy
	except:	# initial state
		oldjoules = 0
		interval = -1

	# store current stats, and do so early
	open( statsfile, "w" ).write(
		str(joules) + "\n"
	)

	# calculations
	watts = (joules-oldjoules) / interval
	if watts < 0:	# wraps around on occasion
		watts = 0

	return ( watts, max(speeds) )

def gpu_collection():
	flavor = ""; state = False; temp = -1; watts = -1

	if is_module_loaded("bbswitch"):
		try:
			state = "ON" in open("/proc/acpi/bbswitch").read()
			# TODO: temp, watts?
		except:
			pass
	elif is_module_loaded("nvidia"):
		flavor = "nvidia"
		for pci in glob( "/sys/bus/pci/devices/*" ):
			# could be 0x030200 too
			if "0x10de" in open(pci + "/vendor").read() and "0x030000" in open(pci + "/class").read():
				try:
					state = "active" in open(pci + "/power/runtime_status").read()
				except:
					pass
				if state:
					# continuously querying the gpu prevents it from sleeping in the first place
					# so only query it when external monitors are enabled (= definitely not trying to sleep)
					xrandr = Popen( ["xrandr", "--current"], stdout=PIPE )
					xrandr = str( xrandr.stdout.read() )
					if not "DP-1-0 connected" in xrandr \
					and not "DP-1-1 connected" in xrandr \
					and not "HDMI-1-0 connected" in xrandr:
						break

					try:
						# `nvidia-settings -q '[gpu:0]/GPUCoreTemp' -t` also works, but is slower
						temp = Popen( ["nvidia-smi", "--format=csv,noheader,nounits", "--query-gpu=temperature.gpu"], stdout=PIPE )
						watts = Popen( ["nvidia-smi", "--format=csv,noheader,nounits", "--query-gpu=power.draw"], stdout=PIPE )
						temp = int( temp.stdout.read() )
						watts = float( watts.stdout.read() )
					except:
						temp = -1
						watts = -1
				break
	elif is_module_loaded("nouveau"):
		flavor = "nvidia"
		try:
			state = "Pwr" in open("/sys/kernel/debug/vgaswitcheroo/switch").readlines()[1]
		except:
			pass
		if state:
			try:
				for dir in glob("/sys/class/hwmon/hwmon*"):
					if "nouveau" in open( dir + "/name" ).read():
						temp = int( open( dir + "/temp1_input" ).read() )/1000
						break
			except:
				pass
	elif is_module_loaded("amdgpu"):
		flavor = "amd"
		try:
			state = True	# TODO
		except:
			pass
		if state:
			try:
				for dir in glob("/sys/class/hwmon/hwmon*"):
					if "amdgpu" in open( dir + "/name" ).read():
						temp = int( open( dir + "/temp1_input" ).read() )/1000
						# wtf, path changes on each boot
						if glob( dir + "/power1_input" ):
							watts = int( open( dir + "/power1_input" ).read() )/1000000
						else:
							watts = int( open( dir + "/power1_average" ).read() )/1000000
						break
			except:
				pass
	return ( state, temp, watts, flavor )

def battery_collection():
	percent = int( open( "/sys/class/power_supply/BAT0/capacity" ).read() )
	watts = int( open( "/sys/class/power_supply/BAT0/power_now" ).read() )/1000000
	status = open("/sys/class/power_supply/BAT0/status").read()

	if (status == "Discharging\n"):
		state=True
		watts=-watts

	elif (status == "Charging\n"):
		state=True
	else:
		state=False

	return ( state, percent, watts )

# returns tenth of arg as unicode subscript character
# "subscript" chars suck, triggers font substituton and makes text jump around
def tenth(arg):
	switcher = {
		0: "₀", 1: "₁", 2: "₂", 3: "₃", 4: "₄", 5: "₅", 6: "₆", 7: "₇", 8: "₈", 9: "₉"
		##0: " ", 1: "➊", 2: "➋", 3: "➌", 4: "➍", 5: "➎", 6: "➏", 7: "➐", 8: "➑", 9: "➒"
	}
	rest = int( (arg % 1)*10 )
	##return switcher.get(rest)
	return " "


##### Collection #####
cputemp = get_cpu_temp()	# do first as following will heat up the chip
cpuwatts, cpuspeed = cpu_collection()
gpustate, gputemp, gpuwatts, gpuflavor = gpu_collection()
battstate, battpercent, battwatts = battery_collection()

cpucolor=" fgcolor='MediumSeaGreen'"	# TODO
if gpuflavor == "nvidia":
	gpucolor = " fgcolor='YellowGreen'"
elif gpuflavor == "amd":
	gpucolor = " fgcolor='FireBrick'"
else:
	gpucolor = ""

if cpuwatts > 9.9:
	cpu = "<span"+cpucolor+">{:2.0f}°C {:2.0f}{:s}W</span>".format( cputemp, cpuwatts, tenth(cpuwatts) )
else:
	cpu = "<span"+cpucolor+">{:2.0f}°C {:2.1f}W</span>".format( cputemp, cpuwatts )
cpuspeedF = "{:.0f}".format(cpuspeed)

if gpuwatts > 9.9:
	gpu = "\n<span"+gpucolor+">{:2.0f}°C {:2.0f}{:s}W</span>".format( gputemp, gpuwatts, tenth(gpuwatts) )
elif gpuwatts > 0:
	gpu = "\n<span"+gpucolor+">{:2.0f}°C {:2.1f}W</span>".format( gputemp, gpuwatts )
elif gputemp > 0:
	gpu = "\n<span"+gpucolor+">{:2.0f} °C</span>".format( gputemp )
elif gpustate:
	gpu = "\n<span"+gpucolor+"> GPU ON</span>"
else:
	gpu = ""

if battstate:
	if battpercent < 20:
		bcolor = " fgcolor='Tomato'"
	else:
		bcolor = ""
	if battwatts >= 10 or battwatts <= -10:
		batt = "\n<span" + bcolor + ">{:2}%</span> {:2.1f}W".format( battpercent, battwatts )
	else:
		batt = "\n<span" + bcolor + ">{:2}%</span> {:2.2f}W".format( battpercent, battwatts )
else:
	batt= ""

loadavg = open( "/proc/loadavg" ).read().split(" ")
loadavg = loadavg[0] + "  " + loadavg[1] + "  " + loadavg[2]

fanspeed = open( glob("/sys/devices/platform/thinkpad_hwmon/hwmon/*/fan1_input")[0] ).read().rstrip()
fanpwmenable = int( open( glob("/sys/devices/platform/thinkpad_hwmon/hwmon/*/pwm1_enable")[0] ).read() )
if fanpwmenable == -1 or fanpwmenable == 2:
	fanpwm = "auto"
elif fanpwmenable == 0:
	fanpwm = "disengaged"
else:
	fanpwm = open( glob("/sys/devices/platform/thinkpad_hwmon/hwmon/*/pwm1")[0] ).read().rstrip()

##### Output #####
print( "<txt>" + cpu + gpu + batt + "</txt>" )
print( "<tool>" + "Load(1,5,15m): " + loadavg + "\n" + "CPU: max " + cpuspeedF + "MHz\nFan: " + fanspeed + "rpm (" + fanpwm + ")</tool>" )
