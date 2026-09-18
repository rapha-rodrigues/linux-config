# ==========================
# .zshrc — Ubuntu + Oh My Zsh + Starship
# ==========================
# Carregado em shells INTERATIVAS: aliases, funções, plugins e prompt.

# ---- 1) Oh My Zsh ----
export ZSH="$HOME/.oh-my-zsh"

# Tema de fallback: o Starship sobrescreve logo abaixo.
ZSH_THEME="robbyrussell"

zstyle ':omz:update' mode reminder
zstyle ':omz:update' frequency 7

# Lista enxuta: cada plugin custa tempo de startup.
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  web-search
)

[[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# ---- 2) Prompt ----
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
else
  echo "⚠️  starship não encontrado. Instale: ./install.sh (passo Starship)"
fi

# ---- 3) Python: uv + direnv ----
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
  export DIRENV_LOG_FORMAT=
else
  echo "⚠️  direnv não encontrado. Instale: sudo apt install direnv"
fi

# venv — cria um ambiente virtual com uv e registra o projeto para o `workon`
# Uso: venv [--python 3.11] [nome]
venv() {
    local venv_name
    local dir_name=$(basename "$PWD")

    if [ $# -eq 0 ] || [[ "${!#}" == -* ]]; then
        venv_name="$dir_name"
    else
        venv_name="${!#}"
        set -- "${@:1:$#-1}"
    fi

    if [ -f .envrc ]; then
        echo "❌ .envrc já existe neste diretório." >&2
        return 1
    fi

    if ! uv venv --seed --prompt "$venv_name" "$@"; then
        echo "❌ Falhou ao criar o ambiente com uv." >&2
        echo "Instale o uv: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
        return 1
    fi

    echo "layout python" > .envrc
    echo "${venv_name} = ${PWD}" >> "$HOME/.projects"
    direnv allow

    echo "✅ Ambiente '${venv_name}' criado."
    echo "📁 ${PWD}/.venv"
}

# workon — entra no diretório de um projeto registrado pelo venv
workon() {
    local project_name="$1"
    local projects_file="$HOME/.projects"
    local project_dir

    if [[ -z "$project_name" ]]; then
        echo "uso: workon <projeto>" >&2
        return 1
    fi

    if [[ ! -f "$projects_file" ]]; then
        echo "❌ $projects_file não existe. Rode 'venv' num projeto para criar." >&2
        return 1
    fi

    project_dir=$(grep -E "^${project_name}\s*=" "$projects_file" | sed 's/^[^=]*=\s*//')

    if [[ -z "$project_dir" ]]; then
        echo "❌ projeto '$project_name' não está em $projects_file" >&2
        echo "Disponíveis:"
        sed 's/\s*=.*//' "$projects_file" | sed 's/^/  - /'
        return 1
    fi

    if [[ ! -d "$project_dir" ]]; then
        echo "❌ diretório não existe: $project_dir" >&2
        return 1
    fi

    cd "$project_dir"
}

# ---- 4) Banner de SSH ----
if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]; then
  echo "🔒 Connected to: $(uname -s) $(uname -r)"
fi

# ---- 5) Aliases ----
if command -v eza >/dev/null 2>&1; then
  alias ls="eza --color=always --long --no-filesize --icons=always --no-time --no-user --no-permissions --all"
  alias lsd='ls -l -s mod -r'
else
  echo "⚠️  eza não encontrado. Instale: sudo apt install eza"
fi

# No Ubuntu o binário do bat se chama batcat (conflito com o pacote 'bat').
if command -v batcat >/dev/null 2>&1; then
  alias bat="batcat"
  alias cat="batcat"
elif command -v bat >/dev/null 2>&1; then
  alias cat="bat"
else
  echo "⚠️  bat não encontrado. Instale: sudo apt install bat"
fi

# ---- 6) fzf ----
if command -v fzf >/dev/null 2>&1; then

  # Keybindings e completions. O apt instala em /usr/share/doc/fzf/examples,
  # a instalação via git fica em ~/.fzf/shell.
  for _fzf_dir in /usr/share/doc/fzf/examples /usr/share/fzf/shell "$HOME/.fzf/shell"; do
    [[ -f "$_fzf_dir/key-bindings.zsh" ]] && source "$_fzf_dir/key-bindings.zsh" && break
  done
  for _fzf_dir in /usr/share/doc/fzf/examples /usr/share/fzf/shell "$HOME/.fzf/shell"; do
    [[ -f "$_fzf_dir/completion.zsh" ]] && source "$_fzf_dir/completion.zsh" && break
  done
  unset _fzf_dir

  # Ctrl-O também navega diretórios (além do Alt-C)
  bindkey '^o' fzf-cd-widget 2>/dev/null

  # Casamento exato por padrão (prefixe com ' para fuzzy pontual)
  export FZF_DEFAULT_OPTS="--exact"

  # O ~/.fzf_functions.zsh (carregado no fim) troca o widget do Ctrl-T por
  # fzf-file-widget-smart: linha vazia + Enter abre no editor ou entra na pasta;
  # com texto digitado, cola o caminho como sempre. Navegador completo: `fe`.
  _bat_bin=$(command -v batcat || command -v bat || echo cat)
  export FZF_CTRL_T_OPTS="--preview 'if [ -d {} ]; then eza --tree --color=always {} | head -200; else $_bat_bin -n --color=always --line-range :500 {}; fi' --bind 'ctrl-e:execute(${EDITOR:-nano} {})' --header 'enter: colar caminho · ctrl-e: abrir no editor e voltar'"
  export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

  _fzf_comprun() {
    local command=$1
    shift
    case "$command" in
      cd)            fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
      export|unset)  fzf --preview "eval 'echo \${}'" "$@" ;;
      ssh)           fzf --preview 'dig {}' "$@" ;;
      *)             fzf --preview "if [ -d {} ]; then eza --tree --color=always {} | head -200; else $_bat_bin -n --color=always --line-range :500 {}; fi" "$@" ;;
    esac
  }
else
  echo "⚠️  fzf não encontrado. Instale: sudo apt install fzf"
fi

# ---- 7) Funções pessoais (symlinks criados por scripts/install.sh) ----
[ -f ~/.git_functions.zsh ]    && source ~/.git_functions.zsh
[ -f ~/.claude_functions.zsh ] && source ~/.claude_functions.zsh
[ -f ~/.fzf_functions.zsh ]    && source ~/.fzf_functions.zsh
[ -f ~/.yazi_functions.zsh ]   && source ~/.yazi_functions.zsh

# ---- 8) Local, fora do versionamento ----
# Aliases de máquina, atalhos de SSH, tokens: nada disso entra no repo.
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
