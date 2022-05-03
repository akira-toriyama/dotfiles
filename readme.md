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
script/macos/setup.sh
```


##　手動

```bash
# clone
git clone https://github.com/powerline/fonts.git --depth=1
# install
cd fonts
./install.sh
# clean-up a bit
cd ..
rm -rf fonts
```

```bash
fig
```

## ime

インポートする

~/dotfiles/setting/ime/romantable.txt
~/dotfiles/setting/ime/keymap.txt


## yabai

https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection
