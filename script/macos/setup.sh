#!/usr/bin/env bash

# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# brew tap homebrew/cask-fonts

# brew install mas
# brew install gibo
# brew install alt-tab
# brew install trash
# brew install starship
# brew install asdf
# brew install gpg

# brew install --cask font-jetbrains-mono
# brew install --cask kindle
# brew install --cask hammerspoon
# brew install --cask google-chrome
# brew install --cask the-unarchiver
# brew install --cask transmission
# brew install --cask visual-studio-code
# brew install --cask teensy
# brew install --cask appcleaner
# brew install --cask vlc
# brew install --cask karabiner-elements
# brew install --cask font-hack-nerd-font

# # EdgeView 2
# mas install 1206246482

# # Translate Tab
# mas install 458887729

# # PopClip
# mas install 445189367

# # ScreenBrush
# mas install 1233965871

# # Loud Typer
# mas install 1493508558

# # 隠しファイル表示
# defaults write com.apple.finder AppleShowAllFiles true

# # Dock を自動的に隠す
# defaults write com.apple.dock autohide -bool true

# # Dockマウスオン遅延無し
# defaults write com.apple.Dock autohide-delay -float 0

# # ステータスバーを表示
# defaults write com.apple.finder ShowStatusBar -bool true

# # パスバーを表示
# defaults write com.apple.finder ShowPathbar -bool true

# # タブバーを表示
# defaults write com.apple.finder ShowTabView -bool true

# # ライブラリディレクトリを表示
# chflags nohidden ~/Library

# # 未確認のアプリケーションを実行する際のダイアログを無効にする
# defaults write com.apple.LaunchServices LSQuarantine -bool false

# # すべての拡張子を表示する
# defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# # メニューバー　隠す
# defaults write NSGlobalDomain _HIHideMenuBar -bool true

# # .DS_Store ファイルを作らせない設定 (ネットワークドライブ)
# defaults write com.apple.desktopservices DSDontWriteNetworkStores true

# # スリープまたはスクリーンセーバから復帰した際、パスワードを要求しない
# defaults write com.apple.screensaver askForPassword -int 0

# # ダウンロードしたアプリケーションの実行許可
# sudo spctl --master-disable

# # 省エネモード解除
# defaults write NSGlobalDomain NSAppSleepDisabled -bool yes

# # マウススクロール
# defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# # スリープを無効化
# sudo pmset -a displaysleep 0
# sudo pmset -a sleep 0

# # デスクトップに表示する項目 ハードディスク
# defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false

# # デスクトップに表示する項目 外部ディスク
# defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false

# # デスクトップに表示する項目 CD，DVD，および iPod
# defaults write com.apple.finder ShowMountedServersOnDesktop -bool false

# # デスクトップに表示する項目 接続しているサーバ
# defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false

# # asdf
# asdf plugin add nodejs
# asdf plugin add golang
# asdf install golang latest
# asdf global golang latest

# # zsh
# ln -s $DOT_FILE_ROOT_PATH/dotfiles/zsh/.zshrc ~/.

# # powerline-go
# go install github.com/justjanne/powerline-go@latest

echo $DOT_FILE_ROOT_PATH/dotfiles/zsh/.zshrc
ln -s $DOT_FILE_ROOT_PATH/dotfiles/zsh/.zshrc ~/.
cat ~/.zshrc
