# Fig pre block. Keep at the top of this file.
[[ -f "$HOME/.fig/shell/zprofile.pre.zsh" ]] && . "$HOME/.fig/shell/zprofile.pre.zsh"

# workspace
open ~/Documents/workspace.dmg.sparseimage

# TODO ctr + f が暴発する https://github.com/withfig/fig/issues/1583
export FIG_WORKFLOWS_KEYBIND="^\\"

# Fig post block. Keep at the bottom of this file.
[[ -f "$HOME/.fig/shell/zprofile.post.zsh" ]] && . "$HOME/.fig/shell/zprofile.post.zsh"
