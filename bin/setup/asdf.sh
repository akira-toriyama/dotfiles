#! /bin/bash

asdf plugin add nodejs
asdf install nodejs latest
asdf global nodejs latest

asdf plugin add golang
asdf install golang latest
asdf global golang latest

asdf plugin add rust
asdf install rust latest
asdf global rust latest

asdf plugin add deno  
asdf install deno latest
asdf global deno latest

asdf plugin add direnv
asdf direnv setup --shell zsh --version latest

echo -e "\n. $(brew --prefix asdf)/libexec/asdf.sh" >> ${ZDOTDIR:-~}/.zshrc
