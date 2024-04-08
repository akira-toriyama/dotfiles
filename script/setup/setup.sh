#! /bin/bash

~/dotfiles/script/setup/app.sh
~/dotfiles/script/setup/defaults.sh
~/dotfiles/script/setup/asdf.sh

# git
git config --global push.default current

# ssh
mkdir -p $HOME/.ssh/github
cp setting/.ssh/config  $HOME/.ssh/config

# zsh
ln -s ~/dotfiles/setting/zsh/.* ~
