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

# brew install \
#   asdf \
#   mas \
#   gh

# # EdgeView 2
# mas install 1206246482
# # PopClip
# mas install 445189367
# # Dropover
# mas install 1355679052

brew install \
  asdf \
  mas

# EdgeView 2
mas install 1206246482
# PopClip
mas install 445189367
# Dropover
mas install 1355679052
