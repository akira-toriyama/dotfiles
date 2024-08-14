# dotfiles

## 手動で

### Git アカウント

```bash
git config --local user.name "akira-toriyama"
git config --local user.email "92862731+akira-toriyama@users.noreply.github.com"
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
