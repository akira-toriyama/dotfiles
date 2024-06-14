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

## Setup

```bash
git clone https://github.com/akira-toriyama/dotfiles.git
cd dotfiles
script/setup/setup.sh
```

## Setting

### Shell

```bash
script/setup/local.sh

# ssh key
ssh-keygen -t ed25519 -f "$HOME/.ssh/github/akira-toriyama"
# pbcopy < "$HOME/.ssh/github/akira-toriyama.pub"
# https://docs.github.com/ja/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account
# ssh -T git@github.com.akira-toriyama

# github
gh auth login
```

### Google IME

- スペースを常に半角に
- `setting/ime/romantable.txt`をインポート
- `setting/ime/keymap.txt`をインポート

## よく使う

```bash
# karabiner 更新
bin/karabiner/generation.sh

# alt-tab 更新
cp ~/Library/Preferences/com.lwouis.alt-tab-macos.plist ~/dotfiles/setting/alt-tab/.

# yabai のウィンドウ
yabai -m query --windows --space | jq

# 全般更新
bin/update.sh
```
