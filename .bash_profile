#!/bin/bash
# Console login
# and screen sessions on Gentoo (?!)

[[ (! $STY) && -f ~/.profile ]] && . ~/.profile
[[ -f ~/.bashrc ]] && . ~/.bashrc
