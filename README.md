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

### CLI

```bash
git clone https://github.com/akira-toriyama/dotfiles.git
cd dotfiles

# brew install
# https://brew.sh/

bin/setup/setup.sh
bin/setup/local.sh
gh auth login

# akira-toriyama
deno run --allow-run --allow-read --allow-write --allow-env --allow-sys $HOME/dotfiles/template/ssh/generation.ts

# bird-studio
deno run --allow-run --allow-read --allow-write --allow-env --allow-sys $HOME/dotfiles/template/ssh/generation.ts
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

# yabai リスタート
yabai --stop-service && yabai --start-service

# 全般更新
bin/update.sh
```
