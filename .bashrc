#!/bin/bash
### Aut inveniam viam aut faciam

## Performance profiling (https://stackoverflow.com/a/5015179/5424487) - also see bottom of file
#PS4='+ $EPOCHREALTIME\011 '
#exec 3>&2 2>/tmp/bashstart.$$.log
#set -x

## Test for non-interactive shell
# NOPE! we allow non-interactive shells now
#[[ $- == *i* ]] || return
## Don't bother inside mc
[[ $MC_SID ]] && return

## Source various files, if they exist, in given order
for _file in	/etc/profile /etc/bash/bashrc /etc/bash.bashrc \
				/usr/share/bash-completion/bash_completion
do
	[[ -f "$_file" ]] && source "$_file"
done
unset _file

## XDG locations
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

## Make CLI appplications use XDG paths (partial duplicate from .profile, for use in master and slave shells)
export ANDROID_USER_HOME="${ANDROID_USER_HOME:-$XDG_DATA_HOME/android}"
export GNUPGHOME="${GNUPGHOME:-$XDG_DATA_HOME/gnupg}"
export LESSHISTFILE="${LESSHISTFILE:-/dev/null}" # want no search history (but if I did: $XDG_STATE_HOME/lesshst)
export MYSQL_HISTFILE="${MYSQL_HISTFILE:-$XDG_STATE_HOME/mysql_history}"
export PSQL_HISTORY="${PSQL_HISTORY:-$XDG_STATE_HOME/psql_history}"
export PYTHON_HISTORY="${PYTHON_HISTORY:-$XDG_STATE_HOME/python_history}"
export RANDFILE="${RANDFILE:-$XDG_CACHE_HOME/rnd}"
export RBENV_ROOT="${RBENV_ROOT:-$XDG_DATA_HOME/rbenv}"
export REDISCLI_HISTFILE="${REDISCLI_HISTFILE:-$XDG_STATE_HOME/rediscli_history}"
export SCREENRC="${SCREENRC:-$XDG_CONFIG_HOME/screen/screenrc}"
export SQLITE_HISTORY="${SQLITE_HISTORY:-$XDG_STATE_HOME/sqlite_history}"
export VAGRANT_HOME="${VAGRANT_HOME:-$XDG_DATA_HOME/vagrant}"
export W3M_DIR="${W3M_DIR:-$XDG_DATA_HOME/w3m}"

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

## Source rbenv after setting RBENV_ROOT and PATH
if [[ -x "$RBENV_ROOT/bin/rbenv" ]]; then
	source <("$RBENV_ROOT/bin/rbenv" init - --no-rehash bash)
fi


## Colors! Formatting!
# https://en.wikipedia.org/wiki/ANSI_escape_code
# https://misc.flogisoft.com/bash/tip_colors_and_formatting
# https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
# also useful: x11-apps/rgb or x11-server-utils
declare -A f=(	# formatting
	# reset everything
	[x]=$'\e[0m'
	# bold, italic, underline, strikethrough
	[b]=$'\e[1m' [i]=$'\e[3m' [u]=$'\e[4m' [s]=$'\e[9m'
	# underlines: double, curly, dotted, dashed (https://sw.kovidgoyal.net/kitty/underlines/)
	[u2]=$'\e[4:2m' [u~]=$'\e[4:3m' [u.]=$'\e[4:4m' [u-]=$'\e[4:5m'
	# dim, blinking, inverse, hidden
	[dim]=$'\e[2m' [bl]=$'\e[5m' [inv]=$'\e[7m' [hid]=$'\e[8m'
	# switch off above (`~bd` does both `~b` and `~dim`)
	[~bd]=$'\e[22m' [~i]=$'\e[23m' [~u]=$'\e[24m' [~s]=$'\e[29m'
					[~bl]=$'\e[25m' [~inv]=$'\e[27m' [~hid]=$'\e[28m'
)
declare -A fg=(	# foreground colors
	# black, red, green, yellow
	[k]=$'\e[30m' [r]=$'\e[31m' [g]=$'\e[32m' [y]=$'\e[33m'
	# blue, magenta, cyan, white
	[b]=$'\e[34m' [m]=$'\e[35m' [c]=$'\e[36m' [w]=$'\e[37m'
	# high-intensity versions
	[K]=$'\e[90m' [R]=$'\e[91m' [G]=$'\e[92m' [Y]=$'\e[93m'
	[B]=$'\e[94m' [M]=$'\e[95m' [C]=$'\e[96m' [W]=$'\e[97m'
	# pure black
	[KK]=$'\e[38;5;232m'
	# reset
	[x]=$'\e[39m'
)
declare -A bg=( # background colors
	[k]=$'\e[40m' [r]=$'\e[41m' [g]=$'\e[42m' [y]=$'\e[43m'
	[b]=$'\e[44m' [m]=$'\e[45m' [c]=$'\e[46m' [w]=$'\e[47m'
	[K]=$'\e[100m' [R]=$'\e[101m' [G]=$'\e[102m' [Y]=$'\e[103m'
	[B]=$'\e[104m' [M]=$'\e[105m' [C]=$'\e[106m' [W]=$'\e[107m'
	[KK]=$'\e[48;5;232m'
	[x]=$'\e[49m'
)
declare -A u=(	# underline colors for use w/ f[u*]
	[k]=$'\e[58;5;0m' [r]=$'\e[58;5;1m' [g]=$'\e[58;5;2m' [y]=$'\e[58;5;3m'
	[b]=$'\e[58;5;4m' [m]=$'\e[58;5;5m' [c]=$'\e[58;5;6m' [w]=$'\e[58;5;7m'
	[K]=$'\e[58;5;8m' [R]=$'\e[58;5;9m' [G]=$'\e[58;5;10m' [Y]=$'\e[58;5;11m'
	[B]=$'\e[58;5;12m' [M]=$'\e[58;5;13m' [C]=$'\e[58;5;14m' [W]=$'\e[58;5;15m'
	[x]=$'\e[59m'
)
declare -A c=(	# cursor styles
	# block blink, block, underline blink, underline, I-beam blink, I-beam
	[bb]=$'\e[1 q' [b]=$'\e[2 q' [ub]=$'\e[3 q' [u]=$'\e[4 q' [ib]=$'\e[5 q' [i]=$'\e[6 q'
	[x]=$'\e[0 q'
)
# Set the cursor color. $1: `#rrbbgg` OR `rgb:rr/gg/bb` (man xparsecolor)
function setcursorcolor() { echo -ne "\e]12;${1:?missing arg}\a"; }


if [[ ! "$ENV_HOME" ]]; then
	## Master Shell

	# Start SSH agent if there isn't one already running (note: xfce4-session usually starts it)
	# try to read it from config if we don't have it but agent is running (e.g. vt, ssh login)
	if [[ "$SSH_AUTH_SOCK" ]] && kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
		:
	elif kill -0 "$(source "$XDG_CACHE_HOME/ssh-agent-info" &>/dev/null && echo $SSH_AGENT_PID)" 2>/dev/null; then
		source "$XDG_CACHE_HOME/ssh-agent-info" >/dev/null
	else
		ssh-agent > "$XDG_CACHE_HOME/ssh-agent-info"
		source "$XDG_CACHE_HOME/ssh-agent-info"
	fi

	# Make gvfsd aware of ssh-agent by injecting SSH_AUTH_SOCK into its env (won't show up in /proc/$pid/environ, still works)
	# (https://forums.gentoo.org/viewtopic-t-954590-start-0.html, https://bugs.gentoo.org/738244)
	( for pid in $(pgrep -u "$USER" -x gvfsd); do
		gdb -batch	-ex "attach $pid" \
					-ex "call (int) putenv(\"SSH_AUTH_SOCK=$SSH_AUTH_SOCK\")" \
					-ex "detach" &>/dev/null
	done & disown )

	## Do some things on a Linux console
	if [[ $TERM == linux ]]; then
		setfont ter-v14n	# Terminus (see /usr/share/consolefonts/README.terminus)
		tput cvvis			# block-shaped cursor
		TMOUT=1800			# log out after 30 min inactivity
	fi

	## Empty (not remove!) mc histories/filepos on login
	# like setting num_history_items_recorded=0 and filepos_max_saved_entries=0 in ~/.config/mc/ini but without breaking mcedit search
	[[ -e "$XDG_DATA_HOME/mc/history" ]] && : > "$XDG_DATA_HOME/mc/history"
	[[ -e "$XDG_DATA_HOME/mc/filepos" ]] && : > "$XDG_DATA_HOME/mc/filepos"

else
	## Slave Shells
	# Source user bashrc too, if it isn't the same as us (loops!)
	[[ -f ~/.bashrc ]] && { grep -q 'Aut inveniam viam aut faciam' ~/.bashrc || source ~/.bashrc; }

	# Include ENV_HOME bins in PATH
	for _dir in "$ENV_HOME/bin" "$ENV_HOME/.local/bin"
	do
		[[ -d "$_dir" ]] || continue
		PATH="$_dir:$PATH"
	done; unset _dir

	# Detect if we are an SSH session
	if [[ ! $SSH_CONNECTION ]]; then
		until [[ ${_ppid:-$PPID} == 1 ]]; do
			read -r _pid _name _junk _ppid _junk < "/proc/${_ppid:-$PPID}/stat"
			[[ $_name =~ sshd|dropbear ]] && {
				export SSH_CONNECTION=1
				break
			}
		done; unset _pid _name _ppid _junk
	fi

	if [[ $- == *i* ]]; then
		# Show stuff on login (which isn't shown because we aren't considered a login shell anymore)
		# only if we are a direct descendant of ssh (not using $SSH_CONNECTION avoids showing it again when using su/sudo)
		( if [[ $(< /proc/$PPID/stat) =~ sshd|dropbear ]]; then
			echo "${bg[m]}$(hostname -f)${bg[x]}"
			echo "$(source /etc/os-release && echo "$PRETTY_NAME") - $(uname -sr)"
			last=$(last -n 2 --fullnames --time-format iso "$USER")
			read -r user tty addr start junk end dur <<< "${last#*$'\n'}"	# skip first line (it's us!)
			echo "Last login: $start from $addr on $tty"
			uptime
			ip -o addr show scope global primary | while read -r num iface type ip junk; do
				[[ "$iface" =~ ":" ]] && continue	# old `ip` shows wrong ifaces with `scope global primary`
				echo "$iface $ip"
			done;
		fi )
		# and mail
		[[ "$MAILPATH" ]] || MAILPATH="/var/mail/$USER"
		[[ -s "$MAILPATH" ]] && echo "You have mail in $MAILPATH"
	fi
fi


## Reset locales that don't exist on a machine (make perl shut the fuck up, fix mc charset(LANG+LC_NUMERIC))
_locales=$(locale -a 2>/dev/null) && _locales="${_locales//utf8/UTF-8}"
for _fallback in "en_US.UTF-8" "C.UTF-8" "C"; do
	[[ "$_locales" =~ "$_fallback" ]] && break
done
[[ "$LANG" && ! "$_locales" =~ "$LANG" ]] && export LANG="$_fallback"
for _cat in	LC_ADDRESS LC_COLLATE LC_CTYPE LC_IDENTIFICATION LC_MONETARY LC_MESSAGES \
			LC_MEASUREMENT LC_NAME LC_NUMERIC LC_PAPER LC_TELEPHONE LC_TIME
do
	[[ "${!_cat}" && ! "$_locales" =~ "${!_cat}" ]] && unset "$_cat"
done
unset _locales _fallback _cat


## Colorful bash prompt with goodies
## wrap in \[ \] to prevent char offset
## NOTE: some weird unicode chars only work correctly with terminus-font or nerd-fonts
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
PS1+='\[${f[x]}${f[b]}${fg[KK]}\]'
# if exit status >0: exit code (useful symbol: ↯)
PROMPT_COMMAND+=('_exit=$?')	# this needs to be the first cmd in PROMPT_COMMAND
PS1+='$( [[ $_exit -gt 0 ]] && echo -n "\[${bg[Y]}\]$_exit" )'
# user/host depending on root or luser, darker color inside ssh ($EUID is bashism)
if [[ $EUID == 0 ]]; then
	if [[ $SSH_CONNECTION ]]
		then PS1+='\[${bg[r]}\]\h'
		else PS1+='\[${bg[R]}\]\h'
	fi
else
	if [[ $SSH_CONNECTION ]]
		then PS1+='\[${bg[G]}\]\u\[${bg[g]}\]@\h'
		else PS1+='\[${bg[G]}\]\u@\h'
	fi
fi
# if screen sessions >0: session count
PS1+='$( shopt -s nullglob;
	sess=("${TMPDIR:-/tmp}/screen/S-$USER"/* "/run/screen/S-$USER"/*);
	[[ $sess ]] && echo -n "\[${bg[W]}\]${#sess[@]}" )'
# if jobs >0: job count
PS1+='$( [[ \j -gt 0 ]] && echo -n "\[${bg[C]}\]\j" )'
# pwd; darker color if not writable
PS1+='\[$( [[ -w . ]] && echo -n "${bg[B]}" || echo -n "${bg[b]}" )\]\W'
# git prompt Mk.2
for _gp in	/usr/share/git/git-prompt.sh /usr/lib/git-core/git-sh-prompt
do
	if [[ -e "$_gp" ]]; then
		source "$_gp"
		GIT_PS1_SHOWCOLORHINTS=''	# uses 0-code to do resets :(
		GIT_PS1_STATESEPARATOR=''
		GIT_PS1_SHOWDIRTYSTATE=1
		GIT_PS1_SHOWUNTRACKEDFILES=1
		GIT_PS1_SHOWSTASHSTATE=1
		GIT_PS1_SHOWUPSTREAM="verbose"
		GIT_PS1_SHOWCONFLICTSTATE="yes"
		tosub() {
			local char result tosub=(₀ ₁ ₂ ₃ ₄ ₅ ₆ ₇ ₈ ₉)
			for ((i=0; i<${#1}; i++)); do
				char="${1:i:1}"
				case "$char" in
					[0-9]) result+="${tosub[$char]}";;
					*) result+="$char";;
				esac
			done
			echo "$result"
		}
		PROMPT_COMMAND+=('
			# 0=branch 1=state
			_git_prompt="$(__git_ps1 "%s")"

			# ahead and behind upstream (Terminus has: ↑ ↓)
			if [[ "$_git_prompt" =~ \|u=?\+?([0-9]+)?-?([0-9]+)?$ ]]; then
				_git_prompt=${_git_prompt%|u*}
				_git_prompt+="${BASH_REMATCH[1]:+⇡}$(tosub ${BASH_REMATCH[1]})${BASH_REMATCH[2]:+⇣}$(tosub ${BASH_REMATCH[2]})"
			fi

			_git_prompt=${_git_prompt/\*/±}	# unstaged changes
			_git_prompt=${_git_prompt/+/‡}	# staged changes
			_git_prompt=${_git_prompt/\%/…}	# untracked files
			_git_prompt=${_git_prompt/\$/■}	# stashed changes
		')
		break
	fi
done; unset _gp
# show git prompt and adapt final triangle color
PS1+='$( [[ "${_git_prompt[@]}" ]] &&
	printf "%s" "\[${bg[M]}\]${_git_prompt[@]}\[${bg[x]}${fg[M]}\]" ||
	echo "\[${bg[x]}${fg[B]}\]" )'
# right-pointing triangle, and reset formatting
PS1+='\[${f[x]}\]'

# Secondary prompt (e.g. missing closing quotes)
PS2='\[${fg[Y]}\]\[${fg[x]}\]'

# Terminal title used while idle (prompt-like)
PST1='[\u@\h]: \w $( _format_seconds $(($SECONDS - ${_timer:-0})) )(\t) {$BASHPID}'
# Terminal title used while running command (prompt-like)
PST2='\c [@\h] (\t) {$BASHPID}'


# Re-enable echo with each prompt (view term settings with stty -a)
# (very useful when a stupid cmd like patch is ctrl+c'ed while prompting for something)
# TODO: when a terminal running htop inside ssh disconnects, binds are fucked
# FIXME: this breaks RET?
##PROMPT_COMMAND+='stty echo;'

# Add final newline when running command missed it (if you don't change terminal width afterwards)
# https://news.ycombinator.com/item?id=23520240 https://www.vidarholen.net/contents/blog/?p=878
##PROMPT_COMMAND+=('printf "⏎%$((COLUMNS-1))s\\r\\033[K"')
PROMPT_COMMAND+=('printf "${bg[K]}↵${bg[x]}%$((COLUMNS-1))s\\r"')

# Trim dirs displayed with `\w`
PROMPT_DIRTRIM=3


## Version compare (returns 0 if $1 ≥ $2 )
function vercmp() {	<<< "$2"$'\n'"$1" sort --check=quiet --version-sort && return 0 || return 1; }

## Shell flags
set +o histexpand		# get rid off the fucking annoying `!!` expansion
##set -o noclobber		# don't allow > to clobber files (use >| to force)

## Shell options
##shopt -s autocd		# cd into dirs by just typing their name
shopt -s cdspell		# correct typoes while cding
shopt -s checkwinsize	# update $LINES and $COLUMNS after each command
##shopt -s dotglob		# make * match dotfiles too
shopt -s extglob		# allow some globs like !(foo)
shopt -s globstar		# make ** work recursively
shopt -s histappend		# don't overwrite history
shopt -s no_empty_cmd_completion	# TAB with empty prompt does nothing
# don't assume literal * if there's nothing to expand (but breaks bash-completion on old versions)
vercmp "${BASH_COMPLETION_VERSINFO[*]}" '2 8' && shopt -s nullglob

## Shell variables
export GLOBIGNORE='-*'	# don't glob potentially dangerous files starting with dashes


## Readline binds
# press ctrl+v or run `read`, then the key to see codes
if [[ $- == *i* ]]; then
	stty -ixon								# unbind Ctrl+[sq], don't make it freeze/thaw buffer
	bind "set bind-tty-special-chars off"	# unbind some other defaults (see `stty -a`)
	# page up/down: cycle through history for commands that start with currently entered text
	bind	' "\e[5~":		history-search-backward '
	bind	' "\e[6~":		history-search-forward '
	# ctrl + arrow up/down: cycle through history yanking the last argument of the entry
	bind	' "\e[1;5A":	yank-last-arg '
	bind	' "\e[1;5B":	"\e-1\e." '
	# ctrl + arrow left/right
	bind	' "\e[1;5D":	backward-word '
	bind	' "\e[1;5C":	forward-word '
	# ctrl + backspace
	bind	' "\b":			backward-kill-word '
	# ctrl + del
	bind	' "\e[3;5~":	kill-word '
	# ctrl + g: list elements of glob behind cursor
	bind	' "\C-g":		glob-list-expansions '
	# ctrl + u
	bind	' "\C-u":		undo '
	# alt + z: go back ("undo cd") (indirect to not print command)
	bind -x	' "\201":		"cd - >/dev/null" '
	bind	' "\ez":		"\201\C-m" '
	# alt + x: go up
	bind -x	' "\202":		"cd .." '
	bind	' "\ex":		"\202\C-m" '
	# shift + tab: complete current string against EVERYTHING from history
	bind	' "\e[Z":		dynamic-complete-history '
	# F-keys: various nifty things
	bind	' "\eOQ":		start-kbd-macro '		# F2
	bind	' "\eOR":		end-kbd-macro '			# F3
	bind	' "\eOS":		call-last-kbd-macro '	# F4
	bind -x	' "\e[15~":		" xdg-open . &>/dev/null" '	# F5, already in Alacritty config
	# alt + q followed by key ("quick snippets")
	bind	' "\eq\"":		"\"\"\C-b" '	# paired characters
	bind	" \"\eq'\":		\"''\C-b\" "
	bind	' "\eq[":		"[]\C-b" '
	bind	' "\eq{":		"{}\C-b" '
	bind	' "\eq(":		"()\C-b" '
	bind	' "\eqq":		"\eb\"\ef\"" '	# quote word behind cursor (uses `backward-word`, letters/digits only. `shell-backward-word is too janky)
	bind	' "\eqn":		">/dev/null\C-b\C-b\C-b\C-b\C-b\C-b\C-b\C-b\C-b\C-b" '		# common phrases
	bind	' "\eqw":		"while true; do ; done\C-b\C-b\C-b\C-b\C-b\C-b" '
	bind	' "\eqf":		"for f in *; do  \"$f\"; done\C-b\C-b\C-b\C-b\C-b\C-b\C-b\C-b\C-b\C-b\C-b" '
	bind	' "\eqF":		"find . -iname \"**\"\C-b\C-b" '

	## Readline options
	if vercmp "$BASH_VERSION" "5.2"; then
		bind "set active-region-start-color ${f[u-]}${u[R]}"	# colors for bracketed paste
		bind "set active-region-end-color ${f[~u]}${u[x]}"
	fi
	bind "set bell-style none"
	bind "set blink-matching-paren on"			# briefly highlight matching bracket on insertion!
	bind "set colored-stats on"					# colored completion list (using $LS_COLORS)
												# FIXME: LS_COLORS is only read while initializing. would need a .inputrc >:(
												# https://unix.stackexchange.com/a/741843/138699
	bind "set colored-completion-prefix on"		# color common elements in list on completing
	bind "set completion-ignore-case on"		# ignore case on completions (but this fucks with already-typed entries!)
	##bind "set completion-map-case on"			# equal - and _ on completions (also fucks with typed entries)
	##bind "set completion-prefix-display-length 5"	# ellipsize common prefixes longer than this during completion (but breaks all colors...)
	bind "set completion-query-items 1024"
	##bind "set echo-control-characters off"	# no ^C spam on Ctrl-C (but prevents useful feedback)
	bind "set enable-bracketed-paste on"		# highlight pasted text and ignore special/potentially dangerous chars
	##bind "set mark-modified-lines on"			# prefix prompt with `*` when going through history lines that have been modified
	bind "set match-hidden-files off"			# don't show hidden files in completions unless requested by prepending .
	bind "set page-completions off"				# no completion pager and don't ask to display smaller lists
	bind "set revert-all-at-newline on"			# revert modified history lines on enter
	##bind "set show-all-if-ambiguous on"		# only press tab once for a list (this is spammy)
	bind "set skip-completed-text on"			# less annoying completion in the middle of a word
	bind "set visible-stats on"					# show character denoting file type in completions

	## Shell history options
	export HISTFILE="$XDG_STATE_HOME/bash_history"	# XDG (and secure against truncation)
	[[ -f "$HISTFILE" ]] || mkdir -p "${HISTFILE%/*}"
	export HISTTIMEFORMAT="%F_%T  "	# timestamp format in `history`
	export HISTCONTROL=ignoreboth	# ignore identical with previous or beginning with space
	export HISTIGNORE="$HISTIGNORE:history*:hgrep*:hs:[bf]g*:jobs*:exit:logout:pwd:clear:reset"	# https://gist.github.com/Angles/3273505

	# don't save history if HISTFILE is broken symlink (prevent its creation on unmounted ~/Private)
	[[ -L "$HISTFILE" && ! -w "$HISTFILE" ]] && unset HISTFILE

	# save everything (use export!! subshells, screen, etc. MUST inherit these settings!)
	if vercmp "$BASH_VERSION" "4.3"
		then export HISTSIZE=-1	# commands
		else export HISTSIZE=999999	# old bash doesn't support -1
	fi
	export HISTFILESIZE=$HISTSIZE	# lines
	declare -r HISTSIZE HISTFILESIZE

	# share history across all open terminals
	##PROMPT_COMMAND+=('history -a; history -n')

	## HSTR stuff
	# workaround https://github.com/dvorka/hstr/issues/531 (needs `dev.tty.legacy_tiocsti=1`)
	function hstrnotiocsti() {
		{ READLINE_LINE="$( { </dev/tty hstr ${READLINE_LINE}; } 2>&1 1>&3 3>&- )"; } 3>&1;
		READLINE_POINT=${#READLINE_LINE}
	}
	bind -x '"\C-r": "hstrnotiocsti"'	# bind to ctrl-r and F12
	bind -x '"\C-[[24~": "hstrnotiocsti"'
	export HSTR_CONFIG='prompt-bottom,hicolor,hide-basic-help'
fi


## Personal preferences
[[ $- == *i* ]] && tabs -4
export EDITOR="mcedit -d"	# see aliases below
# FIXME: viewer in mc shows previous dir's terminal title
export PAGER=less

## Colorful ls
if [[ -r "$XDG_CONFIG_HOME/DIR_COLORS" ]]
	then source <(dircolors -b "$XDG_CONFIG_HOME/DIR_COLORS")
	else source <(dircolors -b)
fi

## Colorful less and manpages (https://unix.stackexchange.com/a/108840)
export GROFF_NO_SGR=1
export LESS_TERMCAP_md="${f[b]}${fg[b]}"			# begin bold
export LESS_TERMCAP_mb="${f[bl]}${f[b]}${fg[r]}"	# begin blinking
export LESS_TERMCAP_me="${f[~bl]}${f[~bd]}${fg[x]}"	# end mode
export LESS_TERMCAP_so="${bg[y]}${fg[k]}"			# begin standout (status line, search terms)
export LESS_TERMCAP_se="${bg[x]}${fg[x]}"			# end mode
export LESS_TERMCAP_us="${f[u]}${fg[g]}"			# begin underline
export LESS_TERMCAP_ue="${f[~u]}${fg[x]}"			# end mode

## Colorful mc, prefer Debian's thin skins
if [[ $EUID -eq 0 ]]
	then export MC_SKIN="modarin256root-defbg"
	else export MC_SKIN="modarin256-defbg"
fi
[[ -f "/usr/share/mc/skins/$MC_SKIN-thin.ini" ]] && MC_SKIN+="-thin"

## Some aliasless defaults
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'	# warnings and errors
export GREP_COLORS='ms=01;31:mc=01;31:sl=:cx=:fn=36:ln=32:bn=32:se=35'	# more visible filename
export LESS="-RiMQ --follow-name --tabs=4"	# allow escapes, dynamic case on search, better prompt, no bell (can block on older less!), follow filename not inode, proper default tab width
vercmp "$(less --version | grep -o 'less [0-9]\+')" "less 581" && LESS+=" --use-color"	# distinct meta colors
vercmp "$(less --version | grep -o 'less [0-9]\+')" "less 632" && LESS+=" --wordwrap"	# wrap at word boundaries
export SUDO_PROMPT='[sudo] %p  '	# target username and lock char
export SYSTEMD_LESS="$LESS -F"	# Fuck you, Pöttering! use my defaults, also skip pager if it fits on screen
export WHOIS_OPTIONS="-H"
export XZ_DEFAULTS="--threads=0"
export ZSTD_NBTHREADS="0"

# Syntax highlighting for less
# TODO: re-investigate `|-` to trigger when piping into less (pygmentize needs `-s` to not block until EOF and can't guess lexer then)
if command -v pygmentize >/dev/null; then
	# Debian's lesspipe won't do syntax highlighting, Gentoo's is incomplete; monkey-wrench in pygmentize
	# also large files are slow to highlight, bail out early
	# based on https://unix.stackexchange.com/q/191487/138699
	export LESSOPEN='|s=%s; lp="$(lesspipe "$s")"; [[ "$lp" ]] && { echo "$lp"; exit 0; }; [[ "$(stat -c %%s "$s")" -gt 1000000 ]] && exit 2; pygmentize -O style=emacs "$s" 2>/dev/null || exit 1'
else
	export LESSOPEN='|lesspipe %s'
fi
# Security! (http://seclists.org/fulldisclosure/2014/Nov/74)
# but makes it impossible to open compressed files...
###LESS="$LESS --no-lessopen"

## custom command-not-found handler
function command_not_found_handle {
	echo "What did you think \`$1\` was, dumb meatbag?!" >&2
	return 127
}

## custom completions
# clone completions from command $1 to $2 [$3, $4, ...]
function complete_clone() {
	local oldcmd="$1"
	shift

	command -v "$oldcmd" >/dev/null || return 1

	# this is much faster than __load_completion
	[[ -f "/usr/share/bash-completion/completions/$oldcmd" ]] && source "/usr/share/bash-completion/completions/$oldcmd"
	[[ -f "$XDG_DATA_HOME/bash-completion/completions/$oldcmd" ]] && source "$XDG_DATA_HOME/bash-completion/completions/$oldcmd"
	local completion="$(complete -p "$oldcmd" 2>/dev/null)"
	[[ "$completion" ]] || return 2

	${completion%$oldcmd} "$@"
}

# misc additions
complete_clone ssh salt-ssh


## Custom aliases and functions
shopt -s expand_aliases	# for non-interactive shells
if [[ -e "${ENV_HOME:-$HOME}/.bash_definitions" ]]; then source "${ENV_HOME:-$HOME}/.bash_definitions"; fi


## Timers and terminal title
# Set the terminal title
# parses prompt-like strings
# $1: title, $2: optional command string, will be cleaned up and `\c` will be substituted by it
function settermtitle() {
	[[ "$TERM" == linux ]] && return	# not on vt
	[[ "$COMP_LINE" ]] && return		# not when bash-completing

	local cmd

	# we don't want PROMPT_COMMAND-triggered DEBUG traps to be able to set the title
	# check each component against BASH_COMMAND
	for cmd in "${PROMPT_COMMAND[@]}"; do
		[[ "$BASH_COMMAND" == "$cmd" ]] && return
	done

	local text="${1@P}"

	if [[ "$2" ]]; then
		# clean up the command string
		# strip env variable assignments and args (FIXME: cmd names with spaces get split)
		local IFS=$' \t\n()'; for cmd in $2; do
			[[ "$cmd" =~ '=' ]] && continue
			# strip path if present
			cmd="${cmd##*/}"
			break
		done

		text="${text/\\c/$cmd}"
	fi
	echo -ne "\e]0;$text\a"
}
# Turn seconds into Hh Mm Ss
function _format_seconds() {
	(($1<5)) && return 1	# don't bother below 5s

	local h m s
	(( h=$1/3600, m=$1%3600/60, s=$1%60 ))

	if ((h>0)); then	echo "(${h}h ${m}m ${s}s) "
	elif ((m>0)); then	echo "(${m}m ${s}s) "
	else				echo "(${s}s) "
	fi
}
# Trap to be executed as a command starts
function _debug_trap() {
	_timer=${_timer:-$SECONDS}
	settermtitle "$PST2" "$BASH_COMMAND"
}

# Terminal title on prompt
PROMPT_COMMAND+=('settermtitle "$PST1"')
# should be last PROMPT_COMMAND
PROMPT_COMMAND+=('unset _timer')
# Terminal title on command
# moved to bottom because other directives put a lot of garbage through the DEBUG trap on startup
[[ $- == *i* ]] && trap '_debug_trap' DEBUG



## Performance profiling tail
#set +x
#exec 2>&3 3>&-

# vim: set filetype=sh noexpandtab tabstop=4 shiftwidth=4 wrap
