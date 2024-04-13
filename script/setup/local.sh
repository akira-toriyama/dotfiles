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

# commit hook
git config --local core.hooksPath .githooks
chmod +x .githooks/prepare-commit-msg

# ghq
git config --global ghq.root '/Volumes/workspace/'

# alt-tab
ln -s "/Users/$USER/Library/Mobile Documents/com~apple~CloudDocs/alt-tab/com.lwouis.alt-tab-macos.plist" /Users/$USER/Library/Preferences/.
