# dotfiles

<p align="center">
  <a href="https://github.com/akira-toriyama/dotfiles">
    <img src="https://raw.githubusercontent.com/akira-toriyama/dotfiles/master/media/logo.png"/>
  </a>
</p>

<p align="center">
  <a href="https://github.com/akira-toriyama/dotfiles/actions/workflows/macos.yml">
    <img src="https://github.com/akira-toriyama/dotfiles/actions/workflows/macos.yml/badge.svg"/>
  </a>
</p>

## 使い方

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
git clone git@github.com:akira-toriyama/dotfiles.git
cd dotfiles
export DOT_FILE_ROOT_PATH=$HOME
script/macos/setup.sh
```

```bash
# fig
fig

# ime
# インポートする
~/dotfiles/setting/ime/romantable.txt
~/dotfiles/setting/ime/keymap.txt
```
