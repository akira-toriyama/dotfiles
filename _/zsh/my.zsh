# 自作コマンドへパスを通す
export PATH=$(chezmoi source-path)/_/bin:$PATH

# asdf
. $(brew --prefix asdf)/libexec/asdf.sh
# asdf-direnv
source "${XDG_CONFIG_HOME:-$HOME/.config}/asdf-direnv/zshrc"

# rmをゴミ箱に
alias rm='trash'

# カーソルから行頭までの文字を削除
bindkey "^u" backward-kill-line
