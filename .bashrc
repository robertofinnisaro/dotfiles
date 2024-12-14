#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

if [ -d "$HOME/.local/share/gem/ruby/3.3.0/bin" ] ; then
    PATH="$HOME/.local.share/gem/ruby/3.3.0/bin:$PATH"
fi


alias dotfiles=/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME
