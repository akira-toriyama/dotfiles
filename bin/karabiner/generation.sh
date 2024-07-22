#! /bin/bash

deno run ~/dotfiles/setting/karabiner/karabinerJson.ts > ~/.config/karabiner/karabiner.json
open '/Applications/Karabiner-Elements.app'
echo "Devices の マウスを on"
