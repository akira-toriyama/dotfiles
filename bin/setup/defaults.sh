#! /bin/bash

# 隠しファイル表示
defaults write com.apple.finder AppleShowAllFiles true

# Dock を自動的に隠す
defaults write com.apple.dock autohide -bool true

# Dockマウスオン遅延無し
defaults write com.apple.Dock autohide-delay -float 0

# ステータスバーを表示
defaults write com.apple.finder ShowStatusBar -bool true

# パスバーを表示
defaults write com.apple.finder ShowPathbar -bool true

# タブバーを表示
defaults write com.apple.finder ShowTabView -bool true

# ライブラリディレクトリを表示
chflags nohidden ~/Library

# 未確認のアプリケーションを実行する際のダイアログを無効にする
defaults write com.apple.LaunchServices LSQuarantine -bool false

# すべての拡張子を表示する
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# メニューバー　隠す
defaults write NSGlobalDomain _HIHideMenuBar -bool true

# .DS_Store ファイルを作らせない設定 (ネットワークドライブ)
defaults write com.apple.desktopservices DSDontWriteNetworkStores true

# スリープまたはスクリーンセーバから復帰した際、パスワードを要求しない
defaults write com.apple.screensaver askForPassword -int 0

# ダウンロードしたアプリケーションの実行許可
sudo spctl --master-disable

# 省エネモード解除
defaults write NSGlobalDomain NSAppSleepDisabled -bool yes

# マウススクロール
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# デスクトップに表示する項目 ハードディスク
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false

# デスクトップに表示する項目 外部ディスク
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false

# デスクトップに表示する項目 CD，DVD，および iPod
defaults write com.apple.finder ShowMountedServersOnDesktop -bool false

# デスクトップに表示する項目 接続しているサーバ
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false

# https://discuss.binaryage.com/t/can-we-help-test-total-spaces-3-if-we-have-apple-silicon/8199/65
defaults write com.apple.dock "mru-spaces" -bool false
