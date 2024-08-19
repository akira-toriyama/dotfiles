# 自作コマンドへパスを通す
export PATH=$(chezmoi source-path)/_/bin:$PATH

# rmをゴミ箱に
alias rm='trash'

# カーソルから行頭までの文字を削除
bindkey "^u" backward-kill-line
