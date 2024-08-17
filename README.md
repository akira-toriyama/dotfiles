# dotfiles

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# update .zprofile
source ~/.zprofile
brew install chezmoi
chezmoi init --apply akira-toriyama
```

## 手動で

### TotalSpaces3

https://downloads.binaryage.com/TotalSpaces3-0.8.114.dmg

### Shell

```bash
gh auth login
yabai--restart
```

### Google IME

- スペースを常に半角に
- `_/ime/romantable.txt`をインポート
- `_/ime/keymap.txt`をインポート

### Github 用 SSH

```bash
# akira-toriyama, bird-studio
shenron--ssh--generation
```

## よく使う

```bash
# yabai のウィンドウ
yabai -m query --windows --space | jq
```
