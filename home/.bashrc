# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source ~/.local/share/omarchy/default/bash/rc

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

. "$HOME/.local/share/../bin/env"

fastfetch

# opencode
export PATH=/home/danilo/.opencode/bin:$PATH
export PATH="$HOME/.local/share/omarchy/local-bin:$PATH"

#intellij idea
export PATH="$HOME/.idea/bin:$PATH"

