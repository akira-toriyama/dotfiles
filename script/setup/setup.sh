#! /bin/bash

./script/setup/app.sh
./script/setup/defaults.sh
./script/setup/asdf.sh

# git
git config --global push.default current

# ssh
mkdir -p $HOME/.ssh/github
cp setting/.ssh/config  $HOME/.ssh/config

# zsh
ln -s ./setting/zsh/.* ~
