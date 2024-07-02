#! /bin/bash

# mas
script/setup/mas.sh

# karabiner
bin/karabiner/generation.sh

# google-japanese-ime が apple silicon 非対応なので
softwareupdate --install-rosetta --agree-to-license && brew install --cask google-japanese-ime

# workspace
hdiutil create -type SPARSE -fs 'Case-sensitive Journaled HFS+' -size 256g -volname workspace ~/Documents/workspace.dmg.sparseimage

# alt-tab
# ln -s は正しく動作しない
cp setting/alt-tab/com.lwouis.alt-tab-macos.plist ~/Library/Preferences/.

# git
###############################################################
# その他の設定
cp -r ./setting/git ~/.config/.
# git push でリモートブランチ名を指定なしで実行
git config --global push.default current
# 大文字・小文字区別
git config --global core.ignorecase false
# ghq
git config --global ghq.root '/Volumes/workspace/'

# commit hook
git config --local core.hooksPath .githooks
chmod +x .githooks/prepare-commit-msg
###############################################################

# yabai
brew install koekeishiya/formulae/yabai
ln -s ${PWD}/setting/yabai/.yabairc ~/.

# https://github.com/akira-toriyama/Adv360-Pro-ZMK?tab=readme-ov-file#macos-specific
colima start --arch x86_64

cp -r ./setting/.ssh  ~/.
