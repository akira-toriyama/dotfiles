# !/usr/bin/env bash

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew tap homebrew/cask-fonts
brew tap homebrew/cask-drivers

brew install mas
brew install gibo
brew install alt-tab
brew install trash
brew install starship
brew install asdf
brew install gpg
brew install zsh-syntax-highlighting
brew install zsh-autosuggestions
brew install zsh-completions
brew install exa
brew install font-jetbrains-mono-nerd-font
brew install zsh-history-substring-search
brew install koekeishiya/formulae/yabai
brew install qmk/qmk/qmk
brew install bat
brew install shortcat
brew install gh
brew install terminal-notifier
brew install font-monaspace
brew install --cask fsnotes
brew install --cask kindle
brew install --cask google-chrome
brew install --cask the-unarchiver
brew install --cask transmission
brew install --cask visual-studio-code
brew install --cask teensy
brew install --cask appcleaner
brew install --cask vlc
brew install --cask karabiner-elements
brew install --cask font-hack-nerd-font
brew install --cask fig
brew install --cask google-japanese-ime
brew install --cask qmk-toolbox
brew install --cask onedrive
brew install --cask raycast
brew install --cask cleanshot

# EdgeView 2
mas install 1206246482
# PopClip
mas install 445189367
# Translatium
mas install 1547052291
# ScreenBrush
mas install 1233965871
# OneDrive
mas install 823766827
# Dropover
mas install 1355679052
# Be Focused Pro - Focus Timer
mas install 961632517



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

# スリープを無効化
sudo pmset -a displaysleep 0
sudo pmset -a sleep 0

# デスクトップに表示する項目 ハードディスク
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false

# デスクトップに表示する項目 外部ディスク
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false

# デスクトップに表示する項目 CD，DVD，および iPod
defaults write com.apple.finder ShowMountedServersOnDesktop -bool false

# デスクトップに表示する項目 接続しているサーバ
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false

# asdf
asdf plugin add nodejs
asdf plugin add golang
asdf plugin add yarn
asdf plugin add rust
asdf plugin add deno  
asdf plugin add direnv

asdf install nodejs latest
asdf install golang latest
asdf install yarn latest
asdf install rust latest
asdf install deno latest
asdf direnv setup --shell zsh --version latest

asdf global nodejs latest
asdf global golang latest
asdf global yarn latest
asdf global rust latest
asdf global deno latest

# git
git config --global push.default current

# .config
mkdir $DOT_FILE_ROOT_PATH/.config

# zsh
ln -s $DOT_FILE_ROOT_PATH/dotfiles/zsh/.zprofile ~/.
ln -s $DOT_FILE_ROOT_PATH/dotfiles/zsh/.zshrc ~/.

# yabai
ln -s $DOT_FILE_ROOT_PATH/dotfiles/yabai/yabairc ~/.config/yabai/.

# compinit
# https://zenn.dev/tomo_saku/articles/d48a158a2c4526
chmod 755 /usr/local/share                   

source ~/.zprofile
source ~/.zshrc

# powerline-go
go install github.com/justjanne/powerline-go@latest

# zsh-completions
chmod -R go-w '/usr/local/share/zsh' 

# TODO https://www.reddit.com/r/olkb/comments/wo3cfo/solution_qmk_bad_interpreter_message_when_running/
# qmk
qmk setup -y

# gramma
npm i gramma -g
