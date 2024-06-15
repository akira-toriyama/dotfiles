#! /bin/bash

# mas
script/setup/mas.sh

# karabiner
script/karabiner/generation.sh

# google-japanese-ime が apple silicon 非対応なので
softwareupdate --install-rosetta --agree-to-license && brew install --cask google-japanese-ime

# yabaiは手順が複雑
brew install koekeishiya/formulae/yabai

# workspace
hdiutil create -type SPARSE -fs 'Case-sensitive Journaled HFS+' -size 256g -volname workspace ~/Documents/workspace.dmg.sparseimage

# ghq
git config --global ghq.root '/Volumes/workspace/'

# alt-tab
# ln -s は正しく動作しない
cp setting/alt-tab/com.lwouis.alt-tab-macos.plist ~/Library/Preferences/.

# git
cp setting/.gitignore_global ~/.
git config --global push.default current
# 大文字・小文字区別
git config --global core.ignorecase false
git config --global core.excludesfile ~/.gitignore_global
# commit hook
git config --local core.hooksPath .githooks
chmod +x .githooks/prepare-commit-msg

# ssh
mkdir -p $HOME/.ssh/conf.d/keys
cp -pR ./setting/.ssh/*  $HOME/.ssh/

# yabai
ln -s $PWD/setting/yabai/.yabairc ~/.
