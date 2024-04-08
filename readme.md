# Dotfiles

<p align="center">
  <a href="https://github.com/akira-toriyama/dotfiles">
    <img src="https://user-images.githubusercontent.com/92862731/166393194-1c4a4338-ae35-4dee-bd0f-7fce2f7f01dd.png"/>
  </a>
</p>

<p align="center">
  <a href="https://github.com/akira-toriyama/dotfiles/actions/workflows/macos.yml">
    <img src="https://github.com/akira-toriyama/dotfiles/actions/workflows/macos.yml/badge.svg"/>
  </a>
</p>


## Install

```bash
cd dotfiles
script/setup/setup.sh

ssh-keygen -t ed25519 -C "imatomiyuichi+github3@gmail.com" -f "$HOME/.ssh/github/akira-toriyama"
# pbcopy < "$HOME/.ssh/github/akira-toriyama.pub"
# https://docs.github.com/ja/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account
# ssh -T git@github.com.akira-toriyama

# karabiner
deno run ~/dotfiles/script/karabiner/karabinerJson.ts > ~/.config/karabiner/karabiner.json && \
open '/Applications/Karabiner-Elements.app' && \ 
echo "Devices の マウスを on"

# workspace
hdiutil create -type SPARSE -fs 'Case-sensitive Journaled HFS+' -size 256g -volname workspace ~/Documents/workspace.dmg.sparseimage
```

## Google IME

スペースを常に半角にする。
`~/dotfiles/setting/ime/romantable.txt`をインポート
`~/dotfiles/setting/ime/keymap.txt`をインポート

## yabai

```bash
brew install koekeishiya/formulae/yabai
```
