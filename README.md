# dotfiles

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
source ~/.zprofile
brew install chezmoi
chezmoi init --apply akira-toriyama
```

## 手動で

### Shell

```bash
gh auth login
# ~/.ssh/conf.d/hosts/github.com.akira-toriyama/id_rsa.pub
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
