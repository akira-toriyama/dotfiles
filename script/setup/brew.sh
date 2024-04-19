#! /bin/bash

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile

brew install --cask \
  visual-studio-code \
  warp \
  alt-tab \
  fsnotes \
  google-chrome \
  the-unarchiver \
  transmission \
  appcleaner \
  vlc \
  raycast \
  karabiner-elements

brew install \
  asdf \
  mas \
  gh \
  ghq \
  jq

brew tap FelixKratz/formulae && brew install borders
