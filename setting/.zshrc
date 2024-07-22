ZSH_DIR="${HOME}/dotfiles/setting/.zhs.d"

if [ -d $ZSH_DIR ] && [ -r $ZSH_DIR ] && [ -x $ZSH_DIR ]; then
    for file in ${ZSH_DIR}/**/*.zsh; do
        [ -r $file ] && source $file
    done
fi
source "${XDG_CONFIG_HOME:-$HOME/.config}/asdf-direnv/zshrc"
