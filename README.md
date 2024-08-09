# dotfiles

```bash
# TODO 自動化
git config --local core.hooksPath .githooks
chmod +x .githooks/prepare-commit-msg

# TODO 自動化
defaults import com.lwouis.alt-tab-macos $(chezmoi source-path)/_/plist/com.lwouis.alt-tab-macos.plist
```

## 手動で

### Google IME

- スペースを常に半角に
- `_/ime/romantable.txt`をインポート
- `_/ime/keymap.txt`をインポート

### Mac 起動時向けの設定

- `mac--startup`を Dock に D&D で追加して、ログイン時にひらく
- Terminal を自動で閉じる

![Terminal](./_/img/Terminal.png)
