# dotfiles

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

## 自動

```bash
git clone git@github.com:akira-toriyama/dotfiles.git
cd dotfiles
export DOT_FILE_ROOT_PATH=$HOME
script/setup.sh
```

## 手動

```bash
# fonts
git clone https://github.com/powerline/fonts.git --depth=1
cd fonts
./install.sh
cd ..
rm -rf fonts
```

```bash
# OneDrive 設定後
# `ln`だとうまく動作しないので`cp`
cp ~/Library/CloudStorage/OneDrive-個人用/plist/com.lwouis.alt-tab-macos.plist ~/Library/Preferences/com.lwouis.alt-tab-macos.plist
```

```bash
fig
```

```bash
# workspace
hdiutil create -type SPARSE -fs 'Case-sensitive Journaled HFS+' -size 256g -volname workspace ~/Documents/workspace.dmg.sparseimage
```

## ime

インポートする

- ~/dotfiles/setting/ime/romantable.txt
- ~/dotfiles/setting/ime/keymap.txt

## yabai

- https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection

## よく使う sh

```bash
# karabiner.json生成
deno run ./script/karabiner/karabinerJson.ts > .config/karabiner/karabiner.json

# karabinerの使用中のキー
deno run ./script/karabiner/usedKeys.ts 

# yabai 再起動
brew services restart yabai
```
