# dotfiles

```bash
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/akira-toriyama/dotfiles/main/init)"
```

## 手動で

### TotalSpaces3

https://downloads.binaryage.com/TotalSpaces3-0.8.114.dmg

### Shell

```bash
yabai--restart
karabiner--generation
mac--bump
# one　passwordをchromeにインストールしてから
gh auth login

# akira-toriyama
# 92862731+akira-toriyama@users.noreply.github.com
shenron--ssh--generation

# bird-studio
# 92862731+akira-toriyama@users.noreply.github.com
shenron--ssh--generation

sudo shutdown -r now
```

### yabai

https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection

### Google IME

- スペースを常に半角に
- `_/ime/romantable.txt`をインポート
- `_/ime/keymap.txt`をインポート

## よく使う

```bash
# yabai のウィンドウ
yabai -m query --windows --space | jq
```
