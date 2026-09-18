# ==========================
# .zprofile - Login Shell Configuration
# ==========================
# Carregado em shells de LOGIN. É onde o PATH é montado.

# ---- PATH ----
# O array `path` do zsh é mais limpo que manipular a string PATH.
path=(
  $path
)

# Binários do usuário (scripts pessoais entram aqui por symlink)
if [[ -d "$HOME/.local/bin" ]]; then
  path=($HOME/.local/bin $path)
fi

# Node via nvm, quando instalado
if [[ -d "$HOME/.nvm" ]]; then
  export NVM_DIR="$HOME/.nvm"
fi

# Go, quando instalado
if [[ -d "/usr/local/go/bin" ]]; then
  path=(/usr/local/go/bin $path)
fi
if [[ -d "$HOME/go/bin" ]]; then
  path=($HOME/go/bin $path)
fi

# Remove duplicatas
typeset -U path
export PATH

# Arquivo de ambiente extra, se existir (uv cria um)
[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"
