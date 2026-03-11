#!/bin/bash

## Performance profiling (https://stackoverflow.com/a/5015179/5424487) - also see bottom of file
#PS4='+ $EPOCHREALTIME\011 '
#exec 3>&2 2>/tmp/bashstart.$$.log
#set -x

## Test for non-interactive shell
[[ $- == *i* ]] || return																									#-#
## Don't bother inside mc
[[ $MC_SID ]] && return																										#-#

## Source various files, if they exist, in given order
for _file in /etc/profile /etc/bash/bashrc /etc/bash.bashrc
do
	[[ -f "$_file" ]] && . "$_file"
done; unset _file

## Set PATH to include various dirs, if they exist and are not already included (later = higher priority)
for _dir in /usr/games/bin /opt/bin /sbin /usr/sbin /usr/local/sbin ~/bin ~/.local/bin #/usr/lib/distcc/bin
do
	[[ -d "$_dir" ]] || continue
	[[ -L "$_dir" ]] && continue	# for merged-usr setups
	[[ "$PATH" =~ ":$_dir" ]] && continue
	PATH="$_dir:$PATH"
done; unset _dir

## Set CDPATH (works like $PATH but for `cd`)
## edit: NOPE, this also shows a bazillion tab-completion suggestions (https://unix.stackexchange.com/questions/224310/prevent-path-autocompletion-from-using-cdpath-in-bash)
####CDPATH=".:~:/"

## Turn us into a var suitable for OpenSSH's default AcceptEnv
## also strip leading whitespace, empty lines, comments and lines ending in #-# when creating the variable
## NOTE: Once this variable becomes too large, dropbear will fail! https://github.com/mkj/dropbear/issues/177
## NOTE: https://github.com/cdown/sshrc also exists. didn't know that. huh.
export LC_BASHRC=$(sed -e '/#-#$/d' -e 's/^[\t ]*//' -e '/^$/d' -e 's/\t\+#.*$//' -e '/^#/d' ~/.bashrc)$'\n'				#-#

if true; then																												#-#
	## Master Shell
	# Add certain dotfiles from home for deployment via BASHRC
	_shared_dotfiles=(".config/htop/htoprc" ".config/mc/ini" ".config/mc/panels.ini" ".config/mc/menu" ".config/git/config" ".screenrc")		#-#
	for _file in "${_shared_dotfiles[@]}"; do																				#-#
		[[ -r "$HOME/$_file" ]] || continue																					#-#
##		# Only deploy files that already exist on the target host
##		LC_BASHRC+="if [[ -w \"\$HOME/$_file\" ]]; then"$'\n'																#-#
		# Escape \ (first) and $ and " in files
		LC_BASHRC+="{ "																										#-#
		# FIXME: slow startup here!
		_content="$(< "$HOME/$_file")"
		LC_BASHRC+="echo ${_content@Q} >\"\$HOME/$_file\";"																	#-#
		LC_BASHRC+=" } 2>/dev/null"$'\n'																					#-#
		# Set timestamp to original file's
		LC_BASHRC+="touch -d @$(stat --printf=%Y "$HOME/$_file") \"\$HOME/$_file\" 2>/dev/null"$'\n'						#-#

##		LC_BASHRC+="fi"$'\n'																								#-#
	done; unset _shared_dotfiles _file _content																				#-#

	# If any of above failed, don't pollute exit code
	LC_BASHRC+="true"$'\n'																									#-#

	# Start SSH agent if there isn't one already running (note: xfce4-session usually starts it)
	# try to read it from config if we don't have it but agent is running (e.g. vt, ssh login)
	if [[ $SSH_AUTH_SOCK ]] && kill -0 $SSH_AGENT_PID 2>/dev/null; then														#-#
		:																													#-#
	elif kill -0 $(source "${XDG_CACHE_HOME-/$HOME/.cache}/ssh-agent-info" &>/dev/null && echo $SSH_AGENT_PID) 2>/dev/null; then	#-#
		source "${XDG_CACHE_HOME-/$HOME/.cache}/ssh-agent-info" >/dev/null													#-#
	else																													#-#
		ssh-agent > "${XDG_CACHE_HOME-/$HOME/.cache}/ssh-agent-info"														#-#
		source "${XDG_CACHE_HOME-/$HOME/.cache}/ssh-agent-info"																#-#
	fi																														#-#

	# Make gvfsd aware of ssh-agent by injecting SSH_AUTH_SOCK into its env (won't show up in /proc/$pid/environ, still works)
	# (https://forums.gentoo.org/viewtopic-t-954590-start-0.html, https://bugs.gentoo.org/738244)
	for _pid in $(pgrep -u $USER -x gvfsd); do																				#-#
		gdb -batch -ex "attach $_pid" -ex "call (int) putenv(\"SSH_AUTH_SOCK=$SSH_AUTH_SOCK\")" -ex "detach" &>/dev/null	#-#
	done & disown																											#-#

	## Do some things on a Linux console
	if [[ $TERM == linux ]]; then																							#-#
		setfont ter-v14n	# Terminus (see /usr/share/consolefonts/README.terminus)										#-#
		tput cvvis			# block-shaped cursor																			#-#
		TMOUT=1800			# log out after 30 min inactivity																#-#
	fi																														#-#

else																														#-#
	## Slave Shells
	# Source user bashrc too
	[[ -f ~/.bashrc ]] && . ~/.bashrc

	# Detect if we are an SSH session
	if [[ ! $SSH_CONNECTION ]]; then
		until [[ ${_ppid:-$PPID} == 1 ]]; do
			read _pid _name __x _ppid _y < /proc/${_ppid:-$PPID}/stat
			[[ $_name =~ sshd|dropbear ]] && {
				SSH_CONNECTION=1
				break
			}
		done; unset _pid _name _x _ppid _y
	fi
fi																															#-#


## Reset locales that don't exist on a machine (make perl shut the fuck up, fix mc charset(LANG+LC_NUMERIC))
_locales=$(locale -a 2>/dev/null) ##&& _locales="${_locales//utf8/UTF-8}"
for _fallback in "en_US.utf8" "C.utf8" "C"; do
	[[ "$_locales" =~ "$_fallback" ]] && break
done
[[ "$LANG" && ! "$_locales" =~ "$LANG" ]] && export LANG="$_fallback"
for _cat in LC_ADDRESS LC_COLLATE LC_CTYPE LC_IDENTIFICATION LC_MONETARY LC_MESSAGES \
			LC_MEASUREMENT LC_NAME LC_NUMERIC LC_PAPER LC_TELEPHONE LC_TIME
do
	[[ "${!_cat}" && ! "$_locales" =~ "${!_cat}" ]] && unset "$_cat"
done
unset _locales _fallback _cat

## Colors! Formatting! (https://en.wikipedia.org/wiki/ANSI_escape_code)
# TODO: 58,59 underline color
# formatting
declare -A f=(
	[reset]=$'\e[0m'
	[bold]=$'\e[1m' [dim]=$'\e[2m' [italic]=$'\e[3m' [underline]=$'\e[4m' [blink]=$'\e[5m'
	[Blink]=$'\e[6m' [inverse]=$'\e[7m' [hidden]=$'\e[8m' [strikethrough]=$'\e[9m'
	[unbolddim]=$'\e[22m' [unitalic]=$'\e[23m' [ununderline]=$'\e[24m' [unblink]=$'\e[25m'
	[unBlink]=$'\e[26m' [uninverse]=$'\e[27m' [unhidden]=$'\e[28m' [unstrikethrough]=$'\e[29m'

)
# normal/high-intensity foreground colors
declare -A fg=(
	[black]=$'\e[30m' [red]=$'\e[31m' [green]=$'\e[32m' [yellow]=$'\e[33m'
	[blue]=$'\e[34m' [magenta]=$'\e[35m' [cyan]=$'\e[36m' [white]=$'\e[37m'
	[Black]=$'\e[90m' [Red]=$'\e[91m' [Green]=$'\e[92m' [Yellow]=$'\e[93m'
	[Blue]=$'\e[94m' [Magenta]=$'\e[95m' [Cyan]=$'\e[96m' [White]=$'\e[97m'
	[reset]=$'\e[39m' [BLACK]=$'\e[38;5;232m'
)
# normal/high-intensity background colors
declare -A bg=(
	[black]=$'\e[40m' [red]=$'\e[41m' [green]=$'\e[42m' [yellow]=$'\e[43m'
	[blue]=$'\e[44m' [magenta]=$'\e[45m' [cyan]=$'\e[46m' [white]=$'\e[47m'
	[Black]=$'\e[100m' [Red]=$'\e[101m' [Green]=$'\e[102m' [Yellow]=$'\e[103m'
	[Blue]=$'\e[104m' [Magenta]=$'\e[105m' [Cyan]=$'\e[106m' [White]=$'\e[107m'
	[reset]=$'\e[49m' [BLACK]=$'\e[48;5;232m'
)

## Colorful bash prompt with goodies
## ref: http://misc.flogisoft.com/bash/tip_colors_and_formatting - wrap in \[ \] to prevent char offset
## note: some weird unicode chars only work correctly with terminus-font
# Get started
PROMPT_COMMAND=()
PS1=""
# bottom line status bar (https://mdk.fr/blog/how-apt-does-its-fancy-progress-bar.html, https://tldp.org/HOWTO/Bash-Prompt-HOWTO/x361.html)
###PS1+='\033[s'			# save cursor position
###PS1+="\033[$LINES;0f"		# go to bottom line
###PS1+='\033[0K'			# clear line
###PS1+='\D{%x %X}'			# print stuff
###PS1+="\033[0;$((LINES-1))r"	# reserve bottom line
###PS1+='\033[u'			# restore cursor position
# reset to all bold black text
PS1+='\[${f[reset]}${f[bold]}${fg[BLACK]}\]'
# if exit status >0: exit code (useful symbol: ↯)
PROMPT_COMMAND+=("_RET=\$?")	#this needs to be the first cmd in PROMPT_COMMAND
PS1+='$(
	if [[ $_RET -gt 0 ]]; then
		echo -n "\[${bg[Yellow]}\]$_RET"
	fi
)'
# user/host depending on root or luser, darker color inside ssd ($EUID is bashism)
if [[ $EUID == 0 ]]; then
	if [[ $SSH_CONNECTION ]]; then	PS1+='\[${bg[red]}\]\h'
	else							PS1+='\[${bg[Red]}\]\h'
	fi
else
	if [[ $SSH_CONNECTION ]]; then	PS1+='\[${bg[Green]}\]\u@\[${bg[green]}\]\h'
	else							PS1+='\[${bg[Green]}\]\u@\h'
	fi
fi
# if screen sessions >0: session count
PS1+='$(
	shopt -s nullglob
	sessions=(/tmp/screen/S-$USER/* /run/screen/S-$USER/*)
	if [[ $sessions ]]; then
		echo -n "\[${bg[White]}\]${#sessions[@]}"
	fi
)'
# if jobs >0: job count
PS1+='$(
	if [[ \j -gt 0 ]]; then
		echo -n "\[${bg[Cyan]}\]\j"
	fi
)'
# pwd; darker color if not writable
PS1+='\[$(
	if [[ -w . ]]; then
		echo -n "${bg[Blue]}"
	else
		echo -n "${bg[blue]}"
	fi
)\]\W'
# git prompt Mk.2
for _gp in	/usr/share/git/git-prompt.sh /usr/lib/git-core/git-sh-prompt
do
	if [[ -e "$_gp" ]]; then
		. "$_gp"
		GIT_PS1_SHOWCOLORHINTS=''	# uses 0-code to do resets :(
		GIT_PS1_STATESEPARATOR=''
		GIT_PS1_SHOWDIRTYSTATE=1
		GIT_PS1_SHOWSTASHSTATE=1
		GIT_PS1_SHOWUNTRACKEDFILES=1
		GIT_PS1_SHOWUPSTREAM="auto"
		GIT_PS1_SHOWCONFLICTSTATE="yes"
		PS1+='$(__git_ps1 "\[${bg[Magenta]}\]%s")'
	fi
done; unset _gp

# right-pointing triangle, and reset formatting
# FIXME: can't get transparent background with inverse :<
PS1+='\[${fg[BLACK]}${f[inverse]}\]\[${f[reset]}\]'

# Secondary prompt (e.g. missing closing quotes)
PS2='\[${fg[Yellow]}\]\[${fg[reset]}\]'


# Re-enable echo with each prompt (view term settings with stty -a)
# (very useful when a stupid cmd like patch is ctrl+c'ed while prompting for something)
# TODO: when a terminal running htop inside ssh disconnects, binds are fucked
# FIXME: this breaks RET?
##PROMPT_COMMAND+='stty echo;'

# Add final newline when running command missed it
# https://news.ycombinator.com/item?id=23520240 https://www.vidarholen.net/contents/blog/?p=878
##PROMPT_COMMAND+=('printf "⏎%$((COLUMNS-1))s\\r\\033[K"')
PROMPT_COMMAND+=('printf "\e[100m↵\e[49m%$((COLUMNS-1))s\\r"')


## Readline binds
#	press ctrl+v or run `read`, then the key to see codes
#	"bind -p" to dump current binds, "bind -r" to unbind (might be necessary before adding new compose-style binds)
# unbind Ctrl+s, don't make it freeze terminal
stty -ixon
# page up/down: cycle through history for commands that start with currently entered text
bind '"\e[5~": history-search-backward'
bind '"\e[6~": history-search-forward'
# ctrl + arrow up/down: cycle through history yanking the first argument of the entry
bind '"\e[1;5A": yank-last-arg'
bind '"\e[1;5B": "\e-1\e."'
# ctrl + arrow left/right
bind '"\e[1;5D": backward-word'
bind '"\e[1;5C": forward-word'
# ctrl + backspace
bind '"\b": backward-kill-word'
# ctrl + del
bind '"\e[3;5~": kill-word'
# ctrl + g: expand glob behind cursor
bind '"\C-g":glob-expand-word'
# ctrl + u
bind "set bind-tty-special-chars off"
bind '"\C-u": undo'
# shift + tab: cycle through available completions
bind '"\e[Z": menu-complete'
# F-keys: various nifty things
##bind -x '"\e[15~":" xdg-open . 2>/dev/null"'	# F5, already in Alacritty config
bind '"\e[17~":"cd -\n"'	# F6
# alt + q followed by key ("quick snippets")
bind '"\eq\"": "\"\"\C-b"'		# paired characters
bind "\"\eq\'\": \"\'\'\C-b\""
bind '"\eq[": "[]\C-b"'
bind '"\eq{": "{}\C-b"'
bind '"\eq(": "()\C-b"'
bind '"\eqq": "\eb\"\ef\""'		# quote current word
bind '"\eqn":">/dev/null\C-b\C-b\C-b\C-b\C-b\C-b\C-b\C-b\C-b\C-b"'		# common phrases
bind '"\eqw":"while true; do ; done\C-b\C-b\C-b\C-b\C-b\C-b"'
bind '"\eqf":"for f in *; do  \"$f\"; done\C-b\C-b\C-b\C-b\C-b\C-b\C-b\C-b\C-b\C-b\C-b"'

## Readline options
bind "set enable-bracketed-paste on"		# ignore special editing chars (during paste)
##bind "set echo-control-characters off"	# no ^C spam on Ctrl-C (but prevents useful feedback)
##bind "set bell-style visible"			# turn the bell into visible flash (but blocks shell whilst doing so...)
bind "set bell-style none"
##bind "set show-all-if-ambiguous on"		# only press tab once for a list (this is spammy)
bind "set page-completions off"			# no completion pager and don't ask to display smaller lists
bind "set completion-query-items 1024"
bind "set match-hidden-files off"		# don't show hidden files in completions unless requested by prepending .
bind "set blink-matching-paren on"		# briefly highlight matching bracket on insertion!
bind "set visible-stats on"			# show character denoting file type in completions
bind "set colored-stats on"			# colored completion list (using $LS_COLORS)
bind "set completion-ignore-case on"		# ignore case on completions (but this fucks with already-typed entries!)
##bind "set completion-map-case on"		# equal - and _ on completions (also fucks with typed entries)

## Shell options
shopt -s histappend	# don't overwrite history
shopt -s checkwinsize	# update $LINES and $COLUMNS after each command
##shopt -s autocd	# cd into dirs by just typing their name
shopt -s extglob	# allow some globs like !(foo)
##shopt -s dotglob	# make * match dotfiles too
shopt -s globstar	# make ** work recursively
# don't assume literal * if there's nothing to expand (but breaks bash-completion on old versions)
[[ ( ${BASH_COMPLETION_VERSINFO[0]} -eq 2 && ${BASH_COMPLETION_VERSINFO[1]} -ge 8 ) || ${BASH_COMPLETION_VERSINFO[0]} -ge 3 ]] && \
	shopt -s nullglob
export GLOBIGNORE='-*'	# don't glob potentially dangerous files starting with dashes
shopt -s no_empty_cmd_completion	# TAB with empty prompt does nothing
##set -o noclobber	# don't allow > to clobber files (use >| to force)
shopt -s cdspell	# correct typoes while cding

## Shell history options
# save more history, don't put duplicate lines in history, add timestamps
# also ignore some commands in history (https://gist.github.com/Angles/3273505)
# use export!! subshells, screen sessions, etc. MUST inherit these settings! (https://superuser.com/a/664061/476871)
export HISTCONTROL=ignoreboth
if [[ ( ${BASH_VERSINFO[0]} -eq 4 && ${BASH_VERSINFO[1]} -ge 3 ) || ${BASH_VERSINFO[0]} -ge 5 ]]; then
	export HISTSIZE=-1		# number of commands in memory
else
	export HISTSIZE=999999		# old bash doesn't support -1
fi
export HISTFILESIZE=$HISTSIZE	# in lines
export HISTTIMEFORMAT="%F %T "
export HISTIGNORE="$HISTIGNORE:history*:hgrep*:hs:[bf]g*:jobs*:exit:logout:pwd:clear:reset"
# don't save history if HISTFILE is broken symlink (prevent its creation on unmounted ~/Private)
[[ -L "$HISTFILE" && ! -w "$HISTFILE" ]] && unset HISTFILE
# share history across all open terminals
##PROMPT_COMMAND+=('history -a; history -n')

## HSTR stuff
##export HH_CONFIG=hicolor
##bind '"\C-[[24~": "\C-ahh\C-j"'	# bind to F12
##HISTIGNORE="$HISTIGNORE:hh"

## Empty (not remove!) mc histories/filepos on login
# like setting num_history_items_recorded=0 and filepos_max_saved_entries=0 in ~/.config/mc/ini but without breaking mcedit search
[[ -e ~/.local/share/mc/history ]] && > ~/.local/share/mc/history
[[ -e ~/.local/share/mc/filepos ]] && > ~/.local/share/mc/filepos

## Personal preferences
export EDITOR="mcedit -d"	# see aliases below
export VIEWER=less
export PAGER=less

## Colorful ls
if which dircolors >/dev/null; then
	if [[ -r ~/.dircolors ]]; then	source <(dircolors -b ~/.dircolors)
	else							source <(dircolors -b)
	fi
fi

## Colorful less and manpages
export GROFF_NO_SGR=1
export LESS_TERMCAP_mb=$'\e[5;1;31m'	# begin blinking
export LESS_TERMCAP_md=$'\e[1;34m'		# begin bold
export LESS_TERMCAP_me=$'\e[25;21;39m'	# end mode
export LESS_TERMCAP_so=$'\e[43m'		# begin standout-mode (status line, search terms)
export LESS_TERMCAP_se=$'\e[49m'		# end standout-mode
export LESS_TERMCAP_us=$'\e[4;35m'		# begin underline
export LESS_TERMCAP_ue=$'\e[24;39m'		# end underline

## Some aliasless defaults
export WHOIS_OPTIONS="-H"
export XZ_DEFAULTS="--threads=0"
export ZSTD_NBTHREADS="0"

## Interpet escape sequences, dynamic case on less search, allow signal kills, better prompt
# -Q: don't ring the bell at EOF (edit: nope, it's blocking! fuck.)
export LESS="$LESS -RiKM --follow-name"
# fuck you, Pöttering! use my defaults, also skip pager if it fits on screen
export SYSTEMD_LESS="$LESS -F"
# Don't want less search history (but if I did, it would be in ~/.local/state/!)
export LESSHISTFILE="/dev/null"
# newer/different lesspipe offers syntax highlighting??
###export LESSCOLOR="always"
# different approach to syntax highlighting, needs source-highlight (based on https://unix.stackexchange.com/q/191487/138699)
command -v source-highlight >/dev/null && \
	export LESSOPEN='|f=%s; lp="$(lesspipe "$f")"; if [[ "$lp" ]]; then echo "$lp"; else source-highlight -i "$f" -o STDOUT -f esc 2>/dev/null; fi'
# Security! (http://seclists.org/fulldisclosure/2014/Nov/74)
# but makes it impossible to open compressed files...
###unset LESSOPEN

## sudo prompt includes target username and fancy lock character
export SUDO_PROMPT='[sudo] %p  '

## custom command-not-found handler
function command_not_found_handle {
	echo "What did you think \`$1\` was, dumb meatbag?!" >&2
	return 127
}


## Show stuff on login (this might break pseudo-interactive shells like scp/rcp!)
# Only if we are a direct descendant of ssh (not using $SSH_CONNECTION avoids showing it again when using su/sudo)
if [[ $(< /proc/$PPID/stat) =~ sshd|dropbear ]]; then
	echo -e "\e[46m$(source /etc/os-release && echo "$PRETTY_NAME") $(uname -rn)\e[0m"
	_last=$(last -n 2 --fullnames --time-format iso $USER)
	read _user _tty _addr _start _junk _end _dur <<< "${_last#*$'\n'}"	# skip first line (it's us!)
	echo "Last login: $_start from $_addr on $_tty"
	unset _read _user _tty _addr _start _ _end _dur
	uptime
	ip -o addr show scope global primary | while read _ _iface _ _ip _; do
		[[ "$_iface" =~ ":" ]] && continue	# old `ip` shows wrong ifaces with `scope global primary`
		echo "$_iface $_ip"
	done; unset _ _iface _ip
fi
# Mail notification (regular one [and motd] isn't shown because we aren't considered an "interactive" shell anymore)
[[ "$MAIL" ]] || MAIL="/var/mail/$USER"
[[ -s "$MAIL" ]] && echo "You have mail in $MAIL"


## Source a few bash-completions non-dynamically so we can assign more commands to them later on
# TODO: See if we can recreate /usr/share/bash-completion/completions in home so this works dynamically
# See https://github.com/github/hub/issues/592#issuecomment-48856709 for some details
for _bc in emerge killall make ping scp ssh sudo
do
	[[ -f "/usr/share/bash-completion/completions/$_bc" ]] && . "/usr/share/bash-completion/completions/$_bc"
done; unset _bc
# fix this shit in Debian 8
if [[ ! -f "/usr/share/bash-completion/completions/apt" && -f "/usr/share/bash-completion/completions/apt-get" ]]; then
	. "/usr/share/bash-completion/completions/apt-get" && complete -F _apt_get apt
fi
# misc additions
complete -F _ssh salt-ssh



## Custom aliases
alias ..='cd ../'; alias ...='cd ../../'; alias ....='cd ../../../'
#if cp --help | grep -q '\-\-progress-bar'; then	# progress bars with advcpmv, CoW
#	alias cp='cp --progress-bar --reflink=auto'
#else	# CoW only
	alias cp='cp --reflink=auto'
#fi
alias ls='ls --human --color=auto --classify=auto --group-directories-first'
alias l="ls -la"; alias lt="ls --sort=time"
_GREP_OPTIONS="--color=auto"
alias grep="grep $_GREP_OPTIONS"; alias egrep="egrep $_GREP_OPTIONS"; alias fgrep="fgrep $_GREP_OPTIONS"
unset _GREP_OPTIONS
alias diff='diff -W $COLUMNS'; alias sdiff='sdiff -W $COLUMNS'	# use term columns in side-by-side (-y)
##alias df='df -h'
alias df2='findmnt -D'
alias df3='findmnt -D -t nosquashfs,notmpfs,nodevtmpfs'
alias mount2='findmnt --invert --pseudo'
alias umount.fuse='fusermount -u'
if command -v schedtool >/dev/null && [[ $(</proc/version) =~ '-ck' ]]; then
	# chrt also exists, is part of util-linux, but can't execute commands
	# more info on classes/policies: https://lwn.net/Articles/805317/
	# schedtool -I and -D need -ck kernels
	if [[ $EUID -eq 0 ]]; then	alias hipri='schedtool -I -n-10 -e'
	else				alias hipri='schedtool -I -n-5 -e'	# -5 only works on hellbringer, usually limited to 0
	fi
	alias lopri='ionice -c3 schedtool -D -n15 -e'	# ionice supports -c3 but only as root
elif command -v schedtool >/dev/null; then
	if [[ $EUID -eq 0 ]]; then	alias hipri='nice -n-10'
	else				alias hipri='nice -n-5'
	fi
	alias lopri='ionice -c3 schedtool -B -n15 -e'
else
	if [[ $EUID -eq 0 ]]; then	alias hipri='nice -n-10'
	else				alias hipri='nice -n-5'
	fi
	alias lopri='ionice -c3 nice -n15'
fi
alias drop_caches='echo 3 > /proc/sys/vm/drop_caches'		# flush (drop) fs caches
alias reset='tput reset'	# reset but without pointless sleep (https://unix.stackexchange.com/a/335650/138699)
command -v beep >/dev/null || alias beep='echo -ne "\a"'
alias xemerge='ACCEPT_KEYWORDS=** emerge'; alias demerge='emerge --nodeps'
complete -o filenames -F _emerge xemerge demerge
alias xorgmerge='emerge -av1 --jobs=4 @x11-module-rebuild'
alias ffmpeg='ffmpeg -hide_banner'; alias ffprobe='ffprobe -hide_banner'; alias gdb='gdb -q'
# also check out https://www.reddit.com/r/bash/comments/19839z9/curl_geofindme/
command -v external-ip >/dev/null && alias ipa='external-ip' || alias ipa='ipi'
alias ipi='curl -s https://icanhazip.com'; alias ipi4='curl -s https://ipv4.icanhazip.com'; alias ipi6='curl -s https://ipv6.icanhazip.com'
alias ipg='dig @ns1.google.com o-o.myaddr.l.google.com TXT +short | tr -d \"'; alias ipg4='dig -4 @ns1.google.com o-o.myaddr.l.google.com TXT +short | tr -d \"'; alias ipg6='dig -6 @ns1.google.com o-o.myaddr.l.google.com TXT +short | tr -d \"'
alias iperppc='curl -s https://erppc.net/ip.php'
alias resolve='getent hosts'; alias resolve4='getent ahostsv4'; alias resolve6='getent ahostsv6'	# resolve name like libc
complete -F _ping resolve resolve4 resolve6
##alias nmap='nmap -PE'			# use ICMP ping for host discovery
alias ping='ping -D -O -n'; alias ping4='ping4 -D -O -n'; alias ping6='ping6 -D -O -n'	# show timestamp, show missed replies, don't do (potentially misleadingly slow) reverse DNS lookups on each reply
alias traceroute='traceroute -n'	# also don't do misleading rDNS queries
alias suicide='unset HISTFILE; exit'	# exit without saving history
alias nh='echo "History saving disabled!"; unset HISTFILE'
alias hs='echo "Saving history now!"; history -a'
alias hgrep='history | grep'	# history grep
alias whoops='history -d -1; history -d -1'	# purge last command from history (and whoops itself)
alias stopall='pkill -STOP -f'; alias contall='pkill -CONT -f'
complete -F _comp_cmd_killall stopall contall
alias winedesktop='wine explorer /desktop=Wine,1024x768'
alias wine-purgemenu='rm -rv ~/.config/menus/applications-merged/wine* \
	~/.local/share/applications/wine* \
	~/.local/share/desktop-directories/wine* \
	~/.local/share/icons/????_*.xpm \
	~/.local/share/mime/{application,packages}/x-wine-extension-*'
# wine temp replacer can be found in .profile
alias rng='</dev/urandom tr -dc "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789" | head -c80; echo'		# alphanumeric w/o [lI1O0] ([:alnum:] otherwise)
alias rmg='</dev/urandom tr -dc "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 ~!@#$%^&*()_+-=\[\]{}|;\:,./<>?" | head -c80; echo'	# more chars
alias ssh-add='</dev/null ssh-add'	# "disable" terminal to force ssh-add to use ssh-askpass (https://unix.stackexchange.com/a/352492/138699)
alias sshnokey='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR'
complete -F _comp_cmd_ssh sshnokey
alias scpnokey='scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR'
complete -F _comp_cmd_scp scpnokey
alias scp-resume='rsync --partial --progress --rsh=ssh'
alias glxgears='vblank_mode=0 glxgears'	# no vsync
# mc: set theme, disable annoying mouse
if [[ $EUID -eq 0 ]]; then	_MC_SKIN="modarin256root-defbg"
else						_MC_SKIN="modarin256-defbg"
fi
[[ -f "/usr/share/mc/skins/$_MC_SKIN-thin.ini" ]] && _MC_SKIN+="-thin"
alias mc="mc -S $_MC_SKIN -d"; alias mcdiff="mcdiff -S $_MC_SKIN -d"; alias mcedit="mcedit -S $_MC_SKIN -d"; alias mcview="mcview -S $_MC_SKIN -d"
unset _MC_SKIN
alias less2='LESSOPEN="" less'		# don't open in fucking hex mode
alias hexdump='hexdump -C'	# better display
alias busy='clear; hexdump /dev/urandom | while read line; do echo "$line"; sleep 0.$((RANDOM%6)); done'	# pretend you're busy =D
#####alias pianobar='PULSE_LATENCY_MSEC=60 pianobar'	# fix latency (https://github.com/PromyLOPh/pianobar/issues/550)
if command -v python3.8 >/dev/null; then
	# https://stackoverflow.com/a/55501674/5424487
	# TODO: check for newer python too
	alias httpserver='ip -o addr show scope global primary | awk "{print \$2,\$4}"; python3.8 -m http.server 8000 --bind ::'
else
	alias httpserver='ip -o addr show scope global primary | awk "{print \$2,\$4}"; python3 -m http.server 8000'	## [--bind 127.0.0.1]
fi
alias intercept='strace -ff -e trace=write -e write=1,2 -p'	# show some process' stdout/stderr
alias 7z7='7zr a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on'	# presets to create 7z/zip
alias 7z7ns='7zr a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=off'	# no solid archive
alias 7zz='7za a -mm=Deflate -mx=9'				# needs p7zip-full (otherwise only 7zr is installed)
alias dd='dd status=progress'	# interactively show progress
alias xev2='xev -event keyboard -event button | egrep --line-buffered -o "^ButtonPress|^ButtonRelease|^KeyPress|^KeyRelease|\(keysym.*\)|button [0-9]+" | sed -e "/Press/{N;s/\n/ /;}" -e "/Release/{N;s/\n/ /;}"'	# far less spammy
alias lspci2='lspci -nnk'
alias apt-removeobsolete='aptitude search "~o"'
alias apt-removeobsolete!='aptitude remove "~o"'
alias apt-removeorphans='deborphan --guess-all | xargs dpkg --dry-run -r'
alias apt-removeorphans!='deborphan --guess-all | xargs dpkg -r'
alias apt-purgeremoved="dpkg -l | awk '/^rc/{print \$2}' | xargs dpkg --dry-run --purge"
alias apt-purgeremoved!="dpkg -l | awk '/^rc/{print \$2}' | xargs dpkg --purge"
alias apt-info='COLUMNS=240 dpkg -l'
alias apt-files='dpkg -L'
function apt-belongs() { dpkg -S "$(realpath "$(which "$1")")"; }	# too retarded to resolve actual path itself
alias apt-depgraph='apt-cache depends'
alias apt-depends='apt-cache rdepends --installed'
alias apt-upgrade='apt install --only-upgrade'
alias wget='wget --hsts-file=$HOME/.local/state/wget-hsts -e robots=off'	# put hsts in proper place, never bother with robots (which causes problems when getting prerequisites)
alias dl='wget -t0 --waitretry=5 -c -T5'
alias stripexif='exiftool -all='
alias stripgeo='exiftool -geotag='
alias weather='curl -s https://wttr.in/Augsburg | nowrap'
alias qrterm='qrencode -t UTF8 -o-'	# output to terminal
alias nowrap='less -S -E -X'	# also: setterm --linewrap off, echo -e "\e[?7l"→echo -e "\e[?7h", cut -c 1-$COLUMNS (will fuck up when control chars exist)
alias hexencode='od -A none -t x1'
alias hexencode2='od -A none -t x2'
alias yt-dlp="yt-dlp -o '%(title)s.%(ext)s' --embed-metadata"	# cleaner filename, chapter info and stuff
alias yt-dlp-subs="yt-dlp --all-subs"
alias yt-dlp-audio="yt-dlp -xf	'(bestaudio/best)[ext=m4a][abr>240]/(bestaudio/best)[ext=mp4][abr>240]/
										mp3-320/(bestaudio/best)[ext=mp3][abr=320]/
										aac-hi/22/(bestaudio/best)[ext=m4a]/(bestaudio/best)[ext=mp4]/
										(bestaudio/best)[ext=mp3]/
										(bestaudio/best)[ext!=aiff][ext!=wav][ext!=flac][format_id!=alac]'"
alias yt-dlp-audio-thumb="yt-dlp-audio --embed-thumbnail"	# only use when thumb not already included! (needs atomicparsley for mp4)
alias yt-dlp-audio-index="yt-dlp-audio -o '%(playlist_index)02d - %(title)s.%(ext)s'"	# index albums/playlists
alias yt-dlp-audio-index-thumb="yt-dlp-audio -o '%(playlist_index)02d - %(title)s.%(ext)s' --embed-thumbnail"
alias inodes='{ for i in *; do echo -e "$(find "$i" | wc -l)\t$i"; done | sort -n; } 2>/dev/null; unset i'	# list dirs with most inodes
alias format='echo "\\e[Zmfoo OR \\e[XYmfoo"; echo "Z:"; echo -e "\e[0m0:reset-all \e[1m1:bold/highint\e[0m \e[2m2:dim\e[0m \e[3m3:italic\e[0m \e[4m4:underline\e[0m \e[5m5:slow-blink\e[0m\n\e[6m6:fast-blink\e[0m\e[7m7:flip-fg-bg\e[0m 8:\e[8mhide\e[0m(hide) \e[9m9:cross-out\e[0m\n21: disable bold/dim, 2Z:disable above"; echo "X: 3=fg-normal, 9=fg-highintensity, 4=bg-normal, 10=bg-highintensity"; echo "Y:"; for i in {0..7}; do echo -e "\e[3${i}mnormal-$i\e[0m  \e[4${i}mnormal-$i\e[0m  \e[9${i}mhighint-$i\e[0m  \e[10${i}mhighint-$i\e[0m \e[3${i}m\e[2mdim-$i\e[0m  \e[4${i}m\e[2mdim-$i\e[0m"; done; unset i; echo "9=reset"'	# list standard terminal colors
alias visudol='visudo -f /etc/sudoers.d/local'	# directly edit local sudoers
alias vmware='LD_PRELOAD="" vmware'	# avoid crashes with gtk3-nocsd (https://github.com/PCMan/gtk3-nocsd/issues/22)
alias firejail='firejail --rmenv=LS_COLORS --rmenv=LC_BASHRC'	# make it work (https://github.com/netblue30/firejail/issues/3678)
alias prettyjson='python -m json.tool'	# alternative to `jq`
alias icon-picker='exo-desktop-item-edit -c ~'	# https://gitlab.xfce.org/xfce/exo/-/issues/91#note_55111



## Custom functions

# SU equivalent using sudo and our bashrc, variant 1 (needs in sudoers: targetpw, closefrom_override)
###alias dosu='sudo -i -C 4 bash --rcfile /dev/fd/3 3<<< "$LC_BASHRC"'
# SU equivalent using sudo and our bashrc, variant 2 (needs in sudoers: targetpw, but SPAMS syslog with entire bashrc!!)
###alias dosu="sudo LC_BASHRC=\"\$LC_BASHRC\" -- bash -c 'exec bash --rcfile <(echo \"\$LC_BASHRC\")'"
# SU equivalent using sudo and our bashrc, variant 3 (needs in sudoers: targetpw)
# HINT: use `-EH` to maintain vars such as `$SSH_AUTH_SOCK`
# FIXME: `wall` output shown twice inside here
function dosu() {
	# sudo can't pass $LC_BASHRC in env without spamming logs, so do it in cmdfile
	local cmdfile="$(mktemp --suffix=.$FUNCNAME)"

	echo '#!/bin/bash' > "$cmdfile"
	echo "rm -f \"$cmdfile\" 2>/dev/null" >> "$cmdfile"
	echo "exec bash --rcfile <(cat <<'BASHRC_EOF'" >> "$cmdfile"
	echo "$LC_BASHRC" >> "$cmdfile"
	echo -e "BASHRC_EOF\n)" >> "$cmdfile"
	chmod +x "$cmdfile"
	chmod o+r "$cmdfile"	# make world-readable for sudo -u luser

	sudo "$@" "$cmdfile"

	rm -f "$cmdfile"
}
complete -F _comp_cmd_sudo dosu

# SU using our bashrc, variant 1 (but new shell fails to become controlling terminal: http://serverfault.com/a/605465/315665)
###alias suenv='su root -- --rcfile <(echo "$LC_BASHRC")'
# SU using our bashrc, variant 2
function suenv() {
	local cmdfile="$(mktemp --suffix=.$FUNCNAME)"

	echo '#!/bin/bash' > "$cmdfile"
	echo "rm -f \"$cmdfile\"" >> "$cmdfile"
	# su passes env variables, we can use $LC_BASHRC directly
	# su overrides $SHELL, undo that (or `script` will break)
	echo "exec bash --rcfile <(echo \"\$LC_BASHRC\"; echo \"export SHELL='$SHELL'\")" >> "$cmdfile"
	chmod +x "$cmdfile"

	su -s "$cmdfile" "$@"

	rm -f "$cmdfile"
}

# Activate Yubikey for current shell (note: xfce4-session usually starts gpg-agent, but without ssh support)
# Source: https://florin.myip.org/blog/easy-multifactor-authentication-ssh-using-yubikey-neo-tokens
# also: https://developers.yubico.com/PGP/Importing_keys.html
function yubi() {
	local SSH_AGENT_FILE="${XDG_CACHE_HOME-/$HOME/.cache}/ssh-agent-info"

	if [[ $1 == "off" ]]; then	# Try to switch back to ssh-agent
		source "$SSH_AGENT_FILE" >/dev/null
		return

	elif [[ $1 == "kill" ]]; then	# Restart scdaemon when it fucks up
				# https://bugs.launchpad.net/serverguide/+bug/1569019/comments/6
				# https://dev.gnupg.org/T1081
		if pgrep -u $USER scdaemon >/dev/null; then
			echo "Killing scdaemon..."
			##gpg-connect-agent "SCD KILLSCD" "SCD BYE" /bye
			gpg-connect-agent "SCD RESET" "SCD BYE" /bye
			for i in {3..1}; do echo -n "${i}.."; sleep 1; done; echo ""	# takes a while until it works again
		fi
		return
	fi

	# Remember ssh-agent values in case we want to switch back later
	if [[ ! -e "$SSH_AGENT_FILE" ]]; then
		echo SSH_AGENT_PID=$SSH_AGENT_PID > "$SSH_AGENT_FILE"
		echo SSH_AUTH_SOCK=$SSH_AUTH_SOCK >> "$SSH_AGENT_FILE"
	fi

	grep -q SSH_AUTH_SOCK "${XDG_CACHE_HOME-/$HOME/.cache}/gpg-agent-info" 2>/dev/null || {
		echo "Killing ssh-less gpg-agent..."
		pkill -u $USER gpg-agent
		while pgrep -u $USER gpg-agent >/dev/null; do	# wait until really gone
			sleep 0.1
		done
	}

	pgrep -u $USER gpg-agent >/dev/null || {
		echo "Starting gpg-agent..."
		gpg-agent --daemon --enable-ssh-support > "${XDG_CACHE_HOME-/$HOME/.cache}/gpg-agent-info"
	}
	source "${XDG_CACHE_HOME-/$HOME/.cache}/gpg-agent-info" || return 1

	gpg-connect-agent updatestartuptty /bye	# fix pinentry (see ~/.gnupg/gpg-agent.conf for details)
}

# Schedule one-off tasks that delete themselves from crontab after execution
function schedule() {
	if [[ $# -lt 2 ]]; then
		echo "Schedule one-off task using cron with flexible datestring"
		echo "Usage: $FUNCNAME '<datestring>' <command> [parm]..."
		return 1
	fi

	local schedule
	schedule=$(date "+%s" -d "$1") || return 2
	if [[ $(( $schedule - $EPOCHSECONDS )) -lt 60 ]]; then
		echo "Scheduled date lies less than a minute ahead, aborting!"
		return 3
	fi

	local minute hour day month command random crontab

	minute=$(date "+%M" -d "$1")
	hour=$(date "+%H" -d "$1")
	day=$(date "+%d" -d "$1")
	month=$(date "+%m" -d "$1")
	shift

	command="PATH='$PATH' DISPLAY='$DISPLAY' XAUTHORITY='$XAUTHORITY' DBUS_SESSION_BUS_ADDRESS='$DBUS_SESSION_BUS_ADDRESS' "
	for p in "$@"; do
		command+="'$p' "
	done
	command+="&>/dev/null"

	random=$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM
	crontab=$(crontab -l 2>/dev/null)
	crontab+=$'\n'"$minute $hour $day $month * "
	crontab+="crontab -l 2>/dev/null | grep -v sched-$random | crontab - 2>/dev/null; "
	crontab+="$command"

	echo "$crontab" | crontab -

	echo "*** command scheduled for $(date "+%b %d %H:%M" -d "@$schedule") ***"
}

# Wrapper around screen to make it work with dropped privileges (https://serverfault.com/a/620149/315665)
# FIXME: this does not work with bash -c 'foo bar' due to quoting
function screen() {
	script -q -c "screen ${*}" /dev/null
}

# Make a bash function runnable as a binary (use with nice, screen, etc.)
function asbin() {
	export -f "$1" && \
	echo -e "\e[9m$1\e[29m → bash -c '$1'"
}

# Edit filenames quickly by calling mv with only one arg
function mv() {
	if [[ "$#" -eq 1 && -e "$1" ]]; then
		local newname
		read -ei "$1" newname

		if [[ "$newname" != "$1" ]]; then
			command mv -v -- "$1" "$newname"
		fi
	else
		command mv "$@"
		return
	fi
}

# Edit variables quickly
function editvar() {
	if [[ $# -eq 0 ]]; then
		echo "Usage: $FUNCNAME <variablename>"
		return 1
	fi

	local newvar
	read -e -i "${!1}" newvar

	if export | grep -q "declare -x $1="; then
		export $1="$newvar"	# can't just use 'declare' as it creates function-local vars (??)
	else
		export -n $1="$newvar"	# set and unexport (wasn't exported to begin with)
	fi
}

# Give information about arg command
function wtf() {
	local path="$(which "$1" 2>/dev/null)"
	type "$1"
	if [[ $path ]]; then
		local realpath=$(realpath "$path")
		if [[ "$path" != "$realpath" ]]; then
			echo "$path is symlinked to $realpath"
		fi
		whatis "$1"
		echo -n "package: "
		if command -v equery >/dev/null; then equery belongs "$path"; fi
		if command -v dpkg >/dev/null; then dpkg -S "$path"; fi
		if command -v rpm >/dev/null; then rpm -qf "$path"; fi
	fi
}

# Highlight a phrase, now with multiple parameters/colors!
# FIXME: still buffering a lot before showing
function hilite() {
	local palette=(41 42 43 44 45 46 101 102 103 104 105 106)
	local phrase code cmd
	local i=0
	for phrase in "$@"; do
		code=$'\e['${palette[$i]}m
		cmd="$cmd; s"$'\a'"\($phrase\)"$'\a'"$code\\1"$'\e[49m'$'\a'g	# use $'\a' as separator
		((i++))
	done
	sed -u "$cmd"
	## old version:
	##grep --color=always -E "$1|$"
}

# Curl host override
function curll() {
	if [[ $# -lt 2 || "$1" == -* || "$1" =~ "/" || "$2" == -* ]]; then
		echo "Usage: $FUNCNAME <newhost> <URL> [curl args]" >&2
		return 1
	fi

	local url="$2"
	local oldhost="${url/http?(s):\/\//}"; oldhost="${oldhost%%/*}"
	local newhost="$1"
	shift 2

	local args=""; local port
	for port in 80 443 25 465; do
		args+="--connect-to $oldhost:$port:$newhost:$port "
	done

	curl $args "$url" "$@"
}

# Grab site's cert info
function cert() {
	if [[ ! $# -eq 1 ]]; then
		echo "Show SSL/TLS certificate information for a site. Usage: $FUNCNAME <URL>"
		return 1
	fi
	openssl s_client -connect $1:443 -servername $1 </dev/null | openssl x509 -noout -text -certopt no_sigdump,no_pubkey
}

# Recursively show dirs as tree
function tree() {
	ls -R "${1:-.}" | grep ":$" | sed -e "s/:$//" -e "s/[^-][^\/]*\//  /g"
}

# mkdir and cd in one
function mkcd() {
	if [[ -d "$1" ]]; then	echo "$1 already exists, entering." >&2
	else mkdir -p -- "$1"
	fi
	cd -- "$1"
}

# btrfs attribute set
function btrfs.set.zstd() {
	if [[ $# != 1 ]]; then
		echo "Recursively set dirs to be compressed with zstd on btrfs" >&2
		echo 'Also run `btrfs fi defrag -r -czstd $dir` to actually do the compressing' >&2
		echo '`compsize` is also an useful tool' >&2
		echo "Usage: $FUNCNAME <dir>" >&2
		return 1
	fi
	find "$1" -exec btrfs property set {} compression zstd \;
}

# Re-implement mc-wrapper.sh, but don't cd if we are already in the target dir (to preserve $OLDPWD)
function mc() {
	local pwd_file="${XDG_CACHE_HOME-/$HOME/.cache}/mc/pwd.$$"

	command mc -P "$pwd_file" "$@"
	local exit=$?

	if [[ -r "$pwd_file" ]]; then
		local pwd="$(<"$pwd_file")"
		rm "$pwd_file"
		[[ -d "$pwd" && "$pwd" != "$PWD" ]] && cd "$pwd"
	fi

	return $exit
}

# Process name for lsof
function lsofp() {
	local pids=$(pgrep -d, "$1")
	shift

	[[ "$pids" ]] || {
		echo "No process found!" >&2
		return 1
	}

	lsof -p "$pids" "$@"
}

# Try to reduce ss' whitespace spam (https://bugzilla.kernel.org/show_bug.cgi?id=119311)
function ss() {
	##command ss "$@" | sed -e 's/\(.....\) /\1;/' -e 's/  \+/;/g' | column -t -s ';'
	command ss "$@" | cat
}

# Add colors to diff -u
function diff() {
	# diff-highlight is part of git and generates intra-line highlights
	# we also additionally colorize the entire lines
	# also see git config

	if [[ -e "/usr/bin/diff-highlight" ]]; then	# Gentoo
		local diffhighlight="/usr/bin/diff-highlight"
	elif [[ -e "/usr/share/doc/git/contrib/diff-highlight/diff-highlight" ]]; then		# Debian 9
		local diffhighlight="/usr/share/doc/git/contrib/diff-highlight/diff-highlight"
	elif [[ -e "/usr/share/doc/git/contrib/diff-highlight/diff-highlight.perl" ]] ; then	# Debian 10+
		if (
			cp -r "/usr/share/doc/git/contrib/diff-highlight" "/tmp/diff-highlight-$$" && \
			cd "/tmp/diff-highlight-$$" && make >/dev/null
		); then
			local diffhighlight="/tmp/diff-highlight-$$/diff-highlight"; local builtdh=1;
		fi
	fi

	if [[ -t 1 ]]; then	# stdout a terminal?
		if [[ "$diffhighlight" ]]; then
			command diff "$@" | "$diffhighlight" | sed -e 's/$/\x1b[0m/' \
				-e 's/^@/\x1b[36m&/' -e 's/^-/\x1b[31m&/' -e 's/^+/\x1b[32m&/' \
				-e 's/^[0-9]/\x1b[36m&/' -e 's/^</\x1b[31m&/' -e 's/^>/\x1b[32m&/'
			local _exit=${PIPESTATUS[0]}
			[[ "$builtdh" ]] && rm -r "/tmp/diff-highlight-$$"
			return $_exit
		else
			command diff "$@" | sed -e 's/$/\x1b[0m/' \
				-e 's/^@/\x1b[36m&/' -e 's/^-/\x1b[31m&/' -e 's/^+/\x1b[32m&/' \
				-e 's/^[0-9]/\x1b[36m&/' -e 's/^</\x1b[31m&/' -e 's/^>/\x1b[32m&/'
			return ${PIPESTATUS[0]}
		fi
	else
		command diff "$@"
		return $?
	fi
}

# sort sensor chips
function sensors() {
	local prev_line=""; local sensor_names
	while read line; do
    	[[ $prev_line == "" ]] && sensor_names+="$line"$'\n'
	    prev_line="$line"
	done <<< $(command sensors)
	command sensors "$@" $(sort <<< $sensor_names)
}

# Grep paragraph instead of just line
function grepp() {
	local x="$1"
	shift
	perl -00ne ' print if /'"$x"'/i ' "$*" | highlight "$x"
}

# run iotop with task delay accounting
function iotop {
	if ! command -v iotop >/dev/null; then
		echo "iotop not found!"
		return 1
	fi

	if [[ $(sysctl -n kernel.task_delayacct) == 0 ]]; then
		sysctl -q kernel.task_delayacct=1
		command iotop "$@"
		sysctl -q kernel.task_delayacct=0
	else
		command iotop "$@"
	fi
}

# Interpret compressed Tomato config file
function tomato-config() {
	# Note: sometimes it's gzipped twice!
	gzip -dc "$1" | sort -z | tr '\n\0' '\n\n'
}
# Sort nvram config file (created with 'nvram export --set')
function nvram-config() {
	tr '\n' '\a' <"$1" | sed 's:\anvram set :\nnvram set :g' | sort | tr '\a' '\n'
}

# make make make.conf-aware ;)
# to make autotools shit:
#libtoolize
#autoreconf
#aclocal
#autoconf
#automake --add-missing --copy
#./configure
#make
function make2() { (
	shopt -s extglob
	source /etc/portage/make.conf
	nice -n"$PORTAGE_NICENESS" make ${MAKEOPTS//--load-average=+([0-9])/} "$@"
) }
complete -F _make make2

# Configure kernel with menuconfig
function confkernel() { (
	cd /usr/src/linux
	make menuconfig
) }

# Make and install kernel
function makekernel() { (
	##cd /usr/src/linux && make2 && make modules_install && make install && emerge -av1 --jobs=4 @module-rebuild
	cd /usr/src/linux && make2 && make2 modules_install && {
		mv /efi/EFI/Gentoo/linux.old2.efi /efi/EFI/Gentoo/linux.old3.efi 2>/dev/null
		mv /efi/EFI/Gentoo/linux.old1.efi /efi/EFI/Gentoo/linux.old2.efi 2>/dev/null
		mv /efi/EFI/Gentoo/linux.old.efi /efi/EFI/Gentoo/linux.old1.efi 2>/dev/null
		mv /efi/EFI/Gentoo/linux.efi /efi/EFI/Gentoo/linux.old.efi 2>/dev/null
		cp -v arch/x86_64/boot/bzImage /efi/EFI/Gentoo/linux.efi;
	} && \
	emerge -av1 --jobs=4 @module-rebuild
) }
function makekernel2() {
	cp -v -n $(find /usr/src/linux-*/ -maxdepth 1 -name '.config' -printf '%T@ %p\n' | sort -r | head -n1 | cut -d' ' -f2-) /usr/src/linux/
	makekernel
}

# Crappy make progress meter
function makeprogress() {
	if [[ ! $# -eq 1 ]]; then
		echo "Crappy make progress meter. Usage: $FUNCNAME <dir>"
		return 1
	fi

	local CCOUNT=$(find "${1:-.}" \( -name "*.c" -o -name "*.cc" -o -name "*.cpp" -o -name "*.cxx" \) -print | wc -l)
	if [[ $CCOUNT = 0 ]]; then
		echo "Can't calculate progress, no C files found!"
	else
		local OCOUNT=$(find "${1:-.}" -name *.o | wc -l)
		echo "$[ $OCOUNT * 100 / $CCOUNT ]% ($OCOUNT / $CCOUNT)"
	fi
}

# chmod recursively for dirs and files
# source: http://www.commandlinefu.com/commands/view/1981/recursively-change-permissions-on-files-leave-directories-alone.
function chmoddir() {
	if [[ ! $# -ge 2 ]]; then
		echo "Recursively chmod only dirs. Usage: $FUNCNAME <mode> <dir> [dir]..."
		return 1
	fi
	find "$2" -type d -print0 | xargs -r0 chmod "$1"
}
function chmodfile() {
	if [[ ! $# -ge 2 ]]; then
		echo "Recursively chmod only files. Usage: $FUNCNAME <mode> <file> [file]..."
		return 1
	fi
	find "$2" -type f -print0 | xargs -r0 chmod "$1"
}

# Swap names of two files
function swap() {
	if [[ ! $# -eq 2 ]]; then
		echo "Swap names of two files. Usage: $FUNCNAME <file> <file>"
		return 1
	elif [[ ! -e "$1" || ! -e "$2" ]]; then
		echo "Cannot open $1 or $2!"
		return 1
	fi
	local temp="$(mktemp -p "$(dirname "$1")" -u --suffix=.$FUNCNAME)"
	mv "$1" "$temp" && \
	mv "$2" "$1" && \
	mv "$temp" "$2"
}

# Convert between unix and dos line endings (stdin)
function d2u() {
	sed 's:\r::'
}
function u2d() {
	sed 's:$:\r:'
}

# En-/Decode URL-encoded strings (stdin)
function urlencode() {
	local LANG=C	# also encode umlauts and such
	local line i o out

	while read line; do
		out=""
		for (( i=0; i<${#line}; i++ )); do
			o="${line:$i:1}"
			[[ "$o" =~ ^[a-zA-Z0-9\.\~\_\-]$ ]] || o="$(printf '%%%02x' "'$o")"
			out+="${o}"
		done
		echo "${out}"
	done
}
function urldecode() {
	local line out

	while read line; do
		out="${line//+/ }"
		echo -e "${out//%/\\x}"
	done
}

## Simple benchmark, calculating pi to 4096 digits (or input)
## source: https://tuxshell.blogspot.com/2009/08/bc-as-cpu-benchmark.html
function pibench() {
	time bc -l <<< "scale=${1:-4096}; a(1)*4" >/dev/null
}

# Network throughput testing
# http://speedtest-ams2.digitalocean.com/
# http://cachefly.cachefly.net/100mb.test
alias speedtest='curl --parallel http://speedtest-fra1.digitalocean.com/5gb.test -o /dev/null http://speedtest-ams2.digitalocean.com/5gb.test -o /dev/null http://speedtest-ams3.digitalocean.com/5gb.test -o /dev/null'
alias speedtest.erppc.down='curl https://erppc.net/infinite.php -o /dev/null'
alias speedtest.erppc.down.slow='curl https://erppc.net/infinite.php?slow=1 -o /dev/null'
alias speedtest.erppc.up='dd if=/dev/zero bs=1M status=none | curl -T - https://erppc.net/infinite.php -o /dev/null'

function speedtest.httpserver() {
	ip -o addr show scope global primary | awk "{print \$2,\$4}"
	echo "Port 8000"
	while true; do
		{ echo -e 'HTTP/1.1 200 OK\nContent-Type: application/octet-stream\nContent-Disposition: attachment; filename="foo.bar"\n\n'; yes; } |
		pv -i 1 -W -F "Speed: %r | Total: %b" |
		nc -l -p 8000

		sleep 0.1
	done
}
# source: http://www.commandlinefu.com/commands/view/4434/live-ssh-network-throughput-test
function speedtest.ssh.down() {
	if [[ $# -lt 1 ]]; then
		echo "Measure downstream network throughput over SSH. Usage: $FUNCNAME <[user@]host> [other ssh args]..."
		return 1
	fi
	ssh -o ClearAllForwardings=yes -o ForwardAgent=no -o ForwardX11=no "$@" 'cat /dev/zero' | pv -i 2 -W -F "Cur: %r | Avg: %a | Tot: %b" >/dev/null
}
function speedtest.ssh.up() {
	if [[ $# -lt 1 ]]; then
		echo "Measure upstream network throughput over SSH. Usage: $FUNCNAME <[user@]host> [other ssh args]..."
		return 1
	fi
	pv -i 2 -W -F "Cur: %r | Avg: %a | Tot: %b" /dev/zero | ssh -o ClearAllForwardings=yes -o ForwardAgent=no -o ForwardX11=no "$@" 'cat >/dev/null'
}
complete -F _ssh speedtest.ssh.down speedtest.ssh.up
function speedtest.nc.down() {
	if [[ $# -ne 1 ]]; then
		echo "Measure downstream network throughput with netcat. Usage: $FUNCNAME <host>"
		return 1
	fi
	read -p "Run this on $1 now, then press enter to continue: nc -l -p 44444 </dev/zero"
	nc "$1" 44444 | pv -i 2 -W -F "Cur: %r | Avg: %a | Tot: %b" >/dev/null

}
function speedtest.nc.up() {
	if [[ $# -ne 1 ]]; then
		echo "Measure upstream network throughput with netcat. Usage: $FUNCNAME <host>"
		return 1
	fi
	read -p "Run this on $1 now, then press enter to continue: nc -l -p 44444 >/dev/null"
	pv -i 2 -W -F "Cur: %r | Avg: %a | Tot: %b" /dev/zero | nc "$1" 44444
}
complete -F _ping speedtest.nc.down speedtest.nc.up

# https://unix.stackexchange.com/a/254976/138699
function wasteram() {
	if [[ $# -ne 1 ]]; then
		echo "Waste RAM. May be be Ctrl+Ced once effect achieved. Usage: $FUNCNAME <megs>"
		return 1
	fi

	head -c "${1}m" /dev/zero | tail
}

function remotescreen() {
	if [[ $# -ne 1 ]]; then
		echo "Shows someone's remote X screen locally. Usage: $FUNCNAME <sshhost>"
		return 1
	fi
	ssh -o ClearAllForwardings=yes -o ForwardAgent=no -o ForwardX11=no "$@" 'DISPLAY=:0 xwd -root | convert -resize 50% - -define png:compression-level=9 png:-' | display -
}
complete -F _ssh remotescreen

# Sync portage tree and rebuild, etc.
function sync-portage() {
	lopri emerge --sync || return
	etc-update
	echo "emerge -avDuU -j4 world"
	emerge -avDuU -j4 world #--changed-deps
	etc-update
	emerge -av1 -j4 @preserved-rebuild
	lopri emerge -a --depclean
	echo "eclean-dist -d -f -t3m"
	lopri eclean-dist -d -f -t3m
	echo "portpeek -a -r -z"
	lopri portpeek -a -r -z
}

# Print orphaned files
# FIXME: finds non-orphaned files with merged-usr
# TODO: If lib/ fails, check /lib64 and vice-versa
function orphans() {
	if [[ $# -gt 1 ]]; then
		echo "Print orphaned (not tracked by portage) files in a dir. Usage: $FUNCNAME [dir]"
		return
	fi

##	analyze() {
##		local packages=$(equery -q belongs -ne "$1" | wc -l)
##		[[ $packages -eq 0 ]] && echo "$1"
##	}
##	export -f analyze
##	find "${1:-.}" -print0 | sort -z | xargs -r -0 -n1 -P$(nproc) bash -c 'analyze "$@"' _

	# FIXME: doesn't link symlinks
	# FIXME: fails on spaces in filenames
	# FIXME: reduce argument list to qfile
	local allthethings=$(find "${1:-.}" -print0 | sort -z | tr '\0' ' ')
	qfile -o $allthethings
}

# Make genlop use rotated logfiles automatically
function genlop() {
	local log; for log in /var/log/emerge.log*; do
		local logfiles="${logfiles} -f $log"
	done
	command genlop $logfiles "$@"
}

# Automagically show changelogs of last emerge session
function changelogs() {
	if [[ $# -ge 1 ]]; then
		#read number of merges from command line
		local num=$1
	else
		#get number of merges from last emerge session
		local num=$(grep "completed emerge" /var/log/emerge.log | tail -n1)
		num=${num#*of }; num=${num%) *}
	fi
	[[ $num -gt 0 ]] || return 1
	#determine the packages behind them
	local recent=$(grep "completed emerge" /var/log/emerge.log | tail -n$num | awk '{print $8}')

	local name; for name in $recent; do
		name=${name%-[0-9]*}	# strip version
		purename=${name#*/}	# strip category

		local reply=""; read -p "Show $name? [y/n] " reply
		[[ $reply = [yY] || $reply = [yY][eE][sS] ]] || continue

		# repo git changelog
		local dir; for dir in /var/db/repos/*/; do
			(cd "$dir" && git log "$name" 2>/dev/null)
		done

		# changelog files
		local exists=""
		local file; for file in /var/db/repos/*/$name/ChangeLog \
		                        /usr/share/doc/$purename-[0-9]*/[nN][eE][wW][sS]* \
		                        /usr/share/doc/$purename-[0-9]*/[cC][hH][aA][nN][gG][eE]*
		do
			[[ -f $file ]] && exists="$exists $file"
		done
		for file in $exists; do
			${PAGER:-less} "$file"
		done
	done
}

# Display reason for masked packages
function mask() {
	awk -v "s=$1" '/^#/ && blockend { x = "" } 1 { blockend = 0 } /^#/ { x = x $0 "\n" } !/^#/ && $0 ~ s { print x "\n" $0 "\n" "\n" } /^$/ { blockend++ }' /usr/portage/profiles/package.mask | head -n-2
}

# Manifest multiple files
function manifest() {
	for file in ${@:-*.ebuild};
		do ebuild "$file" manifest;
	done
}

# Ping the current gateway
function pinggw() {
	local default junk gw metric gateway oldmetric=999999
	while read default junk gw junk junk junk junk junk junk junk metric; do
		[[ $default == "default" ]] || continue
		if [[ $metric -lt $oldmetric ]]; then
			gateway="$gw"
			oldmetric=$metric
		fi
	done <<<$(ip route)
	if [[ ! "$gateway" ]]; then
		echo "No internet gateways found!"
		return 1
	fi
	echo "Pinging $gateway..."
	ping $gateway
}

# Stream audio directly to a server
# or use pa: pacmd load-module module-tunnel-sink server=$1
function streamaudio() {
	if [[ $# -ne 2 ]]; then
		echo "Stream audio directly to a machine. Usage: $FUNCNAME <hostname> <audiofile>"
		return
	fi
	ffmpeg -i "$2" -f s16le - | ssh -o ClearAllForwardings=yes -o ForwardAgent=no -o ForwardX11=no -C $1 'aplay -f cd -'
}

# Enhance optirun with overclocking (needs >=nvidia-settings-337.19)
# perf: pgrep/service is super slow, let's check the pidfile instead
if [[ -e /proc/$( {< /run/bumblebee.pid; } &>/dev/null)/exe ]]; then
	function optirun() {																									#-#
		##local GPUOffset=135	# -> 880MHz																					#-#
		##local MemOffset=420	# -> 2220MHz																				#-#

		##( 	command optirun nvidia-settings -c :8 \																		#-#
		##	-a [gpu:0]/GPUGraphicsClockOffset[1]=$GPUOffset \																#-#
		##	-a [gpu:0]/GPUMemoryTransferRateOffset[1]=$MemOffset \															#-#
		##	2>/dev/null &																									#-#
		##)																													#-#
		command optirun "$@"																								#-#
	}																														#-#
	alias nvidia-settings='optirun nvidia-settings -c :8'
fi
# Fix primusrun (https://forums.gentoo.org/viewtopic-p-8380752.html#8380752)
# (might also need __GLVND_DISALLOW_PATCHING=1 in the future: https://github.com/gsgatlin/primus/commit/6ff7b3ee8c38830a72b5fc087d6f4f12cf421920)
alias primusrun='LD_LIBRARY_PATH="/usr/lib/opengl/nvidia/lib:/usr/lib64/opengl/nvidia/lib:$LD_LIBRARY_PATH" primusrun'		#-#
# Modern prime-run for native Nvidia setups (https://github.com/archlinux/svntogit-packages/blob/packages/nvidia-prime/trunk/prime-run https://download.nvidia.com/XFree86/Linux-x86_64/460.67/README/primerenderoffload.html)
prime-run() {																												#-#
	__NV_PRIME_RENDER_OFFLOAD=1 \																							#-#
	__GLX_VENDOR_LIBRARY_NAME=nvidia \																						#-#
	__VK_LAYER_NV_optimus=NVIDIA_only \																						#-#
	"$@"																													#-#
}																															#-#

# Increase ping for a certain IP
function pingpwn() {
	if [[ $# -ne 2 ]]; then
		if [[ ! $1 == "off" ]]; then
			echo "Increase ping for a certain IP (not hostname). Usage: $FUNCNAME <ip> <latency> OR pingpwn off"
			return 1
		fi
	fi
	if [[ $EUID -ne 0 ]]; then
		echo "Needs root rights!"
		return 1
	fi

	if [[ $1 == "off" ]]; then
		tc qdisc del dev eth0 root
	else
		tc qdisc add dev eth0 root handle 1: prio
		tc qdisc add dev eth0 parent 1:3 handle 30: netem delay ${2}ms 10ms distribution normal
		tc filter add dev eth0 protocol ip parent 1:0 prio 3 u32 match ip dst ${1}/32 flowid 1:3
		# global:
		# tc qdisc add dev eth0 root netem delay 100ms
		# tc qdisc replace dev eth0 root netem latency 100ms
		# also packet loss:
		# tc qdisc replace dev eth0 root netem loss 1.5% latency 100ms
	fi
}

# Grab random HTTPS-capable US proxy, for various use cases
function us_proxy() {
	local agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:77.0) Gecko/20100101 Firefox/77.0"
	local blacklist=(38.77.36.35:8080)

	echo "Finding US proxy..." >&2
	local list=()

	## Proxtube (proxies unresponsive as of 2020-06-14)
	## https://proxtube.com/ext/stable/config.php?version=2.2.2&browser=firefox&locale=en&monetization=nope
	list+=(64.251.25.57:3131 64.251.10.192:3131)

	## http://free-proxy.cz/en/proxylist/country/US/http/uptime/all (site needs JS >:( )
	list+=(
50.206.25.105:80
50.206.25.108:80
68.188.59.198:80
144.91.85.29:3128
13.56.212.14:3128
13.56.12.93:3128
50.206.25.104:80
50.206.25.107:80
50.206.25.109:80
68.185.57.66:80
50.206.25.111:80
50.206.25.106:80
50.206.25.110:80
168.169.96.2:8080
67.207.83.225:80
167.71.149.82:80
152.26.66.140:3128
18.144.173.174:3128
54.212.157.49:80
191.96.42.80:3128
52.151.1.92:80
134.122.127.141:3128
71.13.131.142:80
138.68.60.8:3128
167.71.5.83:8080
143.110.187.151:80
70.37.92.236:3128
34.230.61.238:80
104.168.242.252:3128
54.245.154.200:8080
157.230.247.57:3128
40.121.91.147:80
104.168.169.5:3128
20.186.110.157:3128
140.238.84.65:3128
47.57.124.95:80
67.205.142.237:3128
68.183.226.38:3128
52.91.208.44:80
205.202.38.126:8080
96.43.88.52:3128
8.210.88.234:3128
130.68.124.40:80
157.230.87.143:3128
140.238.162.243:80
207.148.27.41:3128
168.119.128.122:3128
143.110.151.242:3128
167.71.249.181:8888
45.79.137.73:80
159.203.82.173:3128
209.159.158.234:8080
74.92.2.70:80
165.22.218.99:3128
13.92.119.142:80
3.134.246.118:80
132.145.146.10:80
157.245.103.89:3128
162.214.92.202:80
3.135.235.206:3128
47.244.3.41:3128
47.244.50.194:8081
52.4.75.26:3128
18.217.106.183:80
129.213.187.47:80
35.246.5.159:3128
131.156.137.114:3128
159.65.189.75:80
161.35.4.201:80
150.136.231.227:80
68.94.189.60:80
193.122.197.154:80
74.126.83.200:80
134.122.34.159:80
168.169.146.12:8080
206.189.184.46:80
35.196.252.185:3128
134.209.200.146:80
167.86.116.198:3128
132.145.130.198:80
38.90.33.62:80
143.110.177.229:8080
54.204.170.204:80
129.213.183.152:80
132.145.177.223:80
107.22.54.141:80
108.165.247.89:4000
165.22.44.54:80
18.234.43.113:80
152.67.48.62:3128
67.73.189.42:999
35.231.210.95:3128
35.214.170.66:3128
206.189.34.18:3126
3.230.109.138:80
198.73.227.147:80
13.66.249.59:3128
157.230.33.78:3128
18.230.83.234:80
12.5.154.153:80
34.86.94.29:3128
40.79.26.139:1080
198.73.227.221:80
03.135.235.206:3128
18.162.50.70:80
34.65.100.197:3128
140.238.229.147:80
168.138.250.242:80
108.165.247.216:4000
157.230.186.112:44331
3.24.64.99:80
206.81.2.180:3128
70.184.13.81:48678
35.153.198.219:80
70.184.181.203:48678
35.228.130.24:3128
157.230.59.29:44331
3.6.220.71:80
50.116.45.212:8000
35.239.155.190:80
69.64.89.135:3128
12.9.239.130:80
136.244.113.206:3128
3.6.251.241:80
162.252.144.229:8181
104.248.155.227:8118
107.151.195.32:8888
185.33.169.1:999
198.211.109.14:80
192.232.196.228:80
107.178.9.186:8080
50.201.51.216:8080
52.14.29.191:80
68.15.31.118:48678
104.196.28.54:8080
138.68.2.224:3128
52.91.116.132:80
68.188.63.149:8080
192.81.219.167:3128
198.23.165.49:3128
)

	## https://www.us-proxy.org/ (hx=yes: use only claimed https-capable ones)
	local ip port junk; while read ip port junk; do
		list+=($ip:$port)
	done <<< $(curl -sS --connect-timeout 4 -A "$agent" 'https://www.us-proxy.org/' \
		| sed -e 's:</thead><tbody><tr>:\n:' -e 's:</tr><tr>:\n:g' -e 's:</tr></tbody><tfoot>:\n:' \
		| grep "<td class='hx'>\(yes\|no\)</td>" | sed -e 's:<td>: :g' -e 's:</td>: :g' )

	## Evaluate
	local joblist goldlist p b
	local p b; for p in "${list[@]}"; do
		for b in ${blacklist[@]}; do
			[[ "$p" == "$b" ]] && continue 2
		done
  		{ https_proxy="http://$p/" curl -f -s --max-time 13 -A "$agent" -i \
			'https://www.gstatic.com/generate_204' & } &>/dev/null
		joblist[$!]=$p
	done
	## Collect
	for p in ${!joblist[@]}; do
		wait $p 2>/dev/null && goldlist+=(${joblist[$p]})
	done

	if [[ "$goldlist" ]]; then
		local proxy=${goldlist[ $(($RANDOM % ${#goldlist[@]})) ]}
		echo "Found ${#goldlist[@]} usable proxies out of ${#list[@]}, using $proxy" >&2
		echo "$proxy"
		return 0
	else
		echo "Couldn't find working proxy out of ${#list[@]}!" >&2
		return 1
	fi
}
function mpvus() {
	# mpv doesn't support SOCKS proxies yet (https://github.com/mpv-player/mpv/issues/3373)
	# but ytdl integration does
##	local us_proxy
##	us_proxy=$(us_proxy) || return 1
##
##	http_proxy="http://$us_proxy/" mpv "$@"
	mpv --ytdl-raw-options-append=proxy=socks5://10.64.0.1:1080/ "$@"
}
function youtube-dl-us() {
##	local us_proxy
##	us_proxy=$(us_proxy) || return 1
##
##	http_proxy="http://$us_proxy/" youtube-dl "$@"
	youtube-dl --proxy socks5://10.64.0.1:1080/ "$@"
}
##function pianobar() {
##	local us_proxy
##	us_proxy=$(us_proxy) || return 1
##
##	sed -i -e "s|control_proxy = http://.*/|control_proxy = http://$us_proxy/|" ~/.config/pianobar/config
##	command pianobar "$@"
##}

# Terminal noise =D
function noise() {
	local P=(' ' '░' '▒' '▓' '█')

	trap 'trap - SIGINT; tput rmcup; tput cvvis; return' SIGINT

	tput civis	# invisible cursor
	tput smcup	# switch to alternate screen (https://unix.stackexchange.com/q/447009)
	while true; do
		echo -ne "\e[$(( RANDOM % (LINES+1) ));$(( RANDOM % (COLUMNS+1) ))f${P[ $RANDOM%5 ]}"
	done
}

# Reverse a patch file (http://stackoverflow.com/a/3902431/5424487)
function reversepatch() {
	if [[ $# -ne 2 ]]; then
		echo "Reverse a patch, saving it into the same file. Usage: $FUNCNAME <patch> <newpatch>"
		echo "FIXME: Assumes only one file to be patched."
		return
	fi
	if [[ ! -e "$1" ]]; then
		echo "'$1' not found/readable!"
		return 1
	fi

	sed -e "s/^+++/PPP${FUNCNAME}PPP/" -e "s/^---/MMM${FUNCNAME}MMM/" \
		-e "s/@@ -\([0-9]\+,[0-9]\+\) +\([0-9]\+,[0-9]\+\) @@/@@ -\2 +\1 @@/" \
		-e "s/^+/P${FUNCNAME}P/" -e "s/^-/+/" -e "s/^P${FUNCNAME}P/-/" \
		-e "s/^PPP${FUNCNAME}PPP/---/" -e "s/^MMM${FUNCNAME}MMM/+++/" "$1" > "$2"
}

# Create new completion wrapper
# Source: http://ubuntuforums.org/showthread.php?t=733397&p=4573310#post4573310
# FIXME: Seems to only use the last char of parameter??
# Make sure dynamic bashcomp are loaded already. Usage:
#	Create new alias:					alias lsl='ls -l'
#	Find old completer (usually starts with _):		complete -p ls → _longopt
#	Create new completer with additional args:		make-completion-wrapper _longopt _longopt_custom ls -l
#	Apply new completer:					complete -F _longopt_custom lsl
# Tip: to create new completions:
# https://github.com/mbrubeck/compleat
# https://github.com/posener/complete
function make-completion-wrapper() {
	local completer_function_name="$1"
	local wrapper_function_name="$2"
	local arg_count=$(($#-3))
	shift 2
	local function="
function $wrapper_function_name {
	((COMP_CWORD+=$arg_count))
	COMP_WORDS=( "$@" \${COMP_WORDS[@]:1} )
	"$completer_function_name"
}"
###	echo "$function"
	eval "$function"
}



## Terminal title
# moved to bottom because other directives impact startup performance and can seriously mess up the DEBUG trap
# Showing prompt: Show info, time and last cmd's runtime
# Running command: show command, hostname, start time
# FIXME: BASH_COMMAND contains inline foo=bar parameters
function settermtitle() {
	[[ "$TERM" == linux ]] && return	# not on vt
	[[ -n "$COMP_LINE" ]] && return		# not when bash-completing

	# we don't want PROMPT_COMMAND-triggered DEBUG traps to mess around here
	# check each component against BASH_COMMAND
	local cmd
	for cmd in "${PROMPT_COMMAND[@]}"; do
		###echo "$_cmd"
		if [[ "$BASH_COMMAND" == "$cmd" ]]; then
			return
		fi
	done
	echo -ne "\e]0;$*\a"
}
function _show_time() {
	(($1<5)) && return		# don't bother below 5s

	local h=$(($1/3600))
	local m=$((($1%3600)/60))
	local s=$(($1%60))

	if ((h>0)); then	echo " (${h}h ${m}m ${s}s)"
	elif ((m>0)); then	echo " (${m}m ${s}s)"
	else			echo " (${s}s)"
	fi
}
function _clean_command() {
	local cmd p start=''

	read -a cmd <<< "$BASH_COMMAND"
	for c in "${cmd[@]}"; do
		[[ "$c" =~ '=' ]] || break
	done
	echo "$c"
}
PROMPT_COMMAND+=('settermtitle "[$USER@$HOSTNAME]:$DIRSTACK $(printf "%(%H:%M:%S)T" -1)$(_show_time $(($SECONDS - $_timer)) )"')
PROMPT_COMMAND+=('unset _timer')
trap '_timer=${_timer:-$SECONDS}; settermtitle "$(_clean_command) [@$HOSTNAME] ($(printf "%(%H:%M:%S)T" -1))";' DEBUG



## Performance profiling tail
#set +x
#exec 2>&3 3>&-

# vim: set filetype=sh noexpandtab tabstop=4 shiftwidth=4 wrap
