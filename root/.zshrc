# asdf
# append completions to fpath
fpath=(${ASDF_DIR}/completions $fpath)
# initialise completions with ZSH's compinit
autoload -Uz compinit && compinit
export ASDF_DATA_DIR=`brew --prefix asdf`/
source $ASDF_DATA_DIR/asdf.sh

# trash
alias rm='trash'
