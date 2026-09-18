# ============================================================
# fzf: navegador de arquivos com preview, edição e navegação
#
#   fe [dir] [consulta]  — lista arquivos E pastas do diretório (fd, ou find)
#                          à esquerda e o preview (bat / eza --tree) à direita.
#                            Enter / duplo clique em arquivo → abre no $EDITOR
#                              (nano por padrão) e volta à lista ao fechar
#                            Enter / duplo clique em pasta   → entra nela
#                              (a entrada ".." sobe um nível)
#                            ctrl-g     → cd da shell para a pasta atual e sai
#                            ctrl-v     → abre no VS Code (code-insiders / code)
#                            ctrl-y     → copia o caminho (wl-copy, xclip ou xsel)
#                            ctrl-/     → liga/desliga o preview
#                            shift-↑/↓  → rola o preview
#                            esc        → sai (a shell fica onde estava)
#
#   Ctrl-T (fzf-file-widget-smart, substitui o widget padrão do fzf):
#     linha de comando VAZIA  → Enter/duplo clique abre o arquivo no $EDITOR
#                                ou entra na pasta (cd), como o fe
#     linha com texto         → comportamento padrão: cola o(s) caminho(s)
#                                (ex.: `nano ` + Ctrl-T); ctrl-e abre o item
#                                no editor e volta ao fzf
#
# Dependências: fzf, bat (batcat no Ubuntu), eza. Opcional: fd (fdfind no Ubuntu,
# respeita .gitignore e é mais rápido) e wl-clipboard/xclip para o ctrl-y.
# ============================================================

# Lista arquivos e pastas do diretório atual, caminhos relativos. fd respeita o
# .gitignore; a variante find poda o que o walker do fzf também ignora + venvs.
_fe_list() {
  emulate -L zsh
  if (( $+commands[fd] )); then
    fd --hidden --follow --exclude .git --exclude node_modules --color=never .
  else
    find . -mindepth 1 \( -name .git -o -name node_modules -o -name .venv -o -name __pycache__ -o -name .DS_Store \) -prune -o -print 2>/dev/null | sed 's|^\./||'
  fi
}

fe() {
  emulate -L zsh
  setopt local_options pipefail

  if ! (( $+commands[fzf] )); then
    print -u2 "fe: requer fzf (sudo apt install fzf)"
    return 1
  fi

  local dir=$PWD
  if [[ -n $1 && -d $1 ]]; then
    dir=${1:a}
    shift
  fi
  local query=$*

  local editor=${EDITOR:-nano}
  local vscode=code-insiders
  (( $+commands[$vscode] )) || vscode=code

  # No Ubuntu o bat se chama batcat (conflito de nome com o pacote 'bat').
  local bat_bin=bat
  (( $+commands[batcat] )) && bat_bin=batcat

  # Clipboard: Wayland usa wl-copy, X11 usa xclip ou xsel. Sem nenhum, ctrl-y
  # vira no-op silencioso em vez de erro dentro do fzf.
  local clip='cat >/dev/null'
  if [[ -n ${WAYLAND_DISPLAY:-} ]] && (( $+commands[wl-copy] )); then clip='wl-copy'
  elif (( $+commands[xclip] )); then clip='xclip -selection clipboard'
  elif (( $+commands[xsel] )); then clip='xsel --clipboard --input'
  fi

  local preview="if [ -d {} ]; then eza --tree --color=always --icons=always --level=2 {} | head -200; else $bat_bin -n --color=always --line-range :500 {}; fi"

  local out key sel target
  local -a lines
  while true; do
    # Tudo roda com cwd = $dir (subshell do $(...)): lista, preview e caminhos ficam relativos e curtos.
    # Saída do fzf: consulta \n tecla (--expect) \n seleção. Esc/ctrl-c (130) e Enter sem item (1) encerram.
    out=$( cd -q -- "$dir" && { [[ $PWD != / ]] && print -r -- ..; _fe_list; } | fzf \
        --height 90% --reverse --exact --print-query --expect ctrl-g --query "$query" \
        --prompt "${dir/#$HOME/~}/ " \
        --header 'enter: abrir arquivo · entrar na pasta (.. sobe) · ctrl-g: cd aqui · ctrl-v: VS Code · ctrl-y: copiar · esc: sair' \
        --preview "$preview" --preview-window 'right:60%:wrap' \
        --bind 'shift-up:preview-half-page-up,shift-down:preview-half-page-down' \
        --bind 'ctrl-/:toggle-preview' \
        --bind "ctrl-y:execute-silent(printf %s {} | $clip)" \
        --bind "ctrl-v:execute-silent($vscode {})" ) || break

    lines=("${(@f)out}")
    query=$lines[1]; key=$lines[2]; sel=$lines[3]

    if [[ $key == ctrl-g ]]; then
      cd -- "$dir"
      return
    fi
    [[ -n $sel ]] || continue

    if [[ $sel == .. ]]; then
      dir=${dir:h}; query=''
      continue
    fi
    target=$dir/$sel
    if [[ -d $target ]]; then
      dir=${target:a}; query=''
    else
      "$editor" "$target"
    fi
  done
}

# ------------------------------------------------------------
# Ctrl-T inteligente. Usa as mesmas peças internas do fzf que o widget padrão
# (__fzf_defaults, __fzfcmd, FZF_CTRL_T_COMMAND/OPTS); se elas mudarem numa
# versão futura, o guard abaixo mantém o Ctrl-T padrão.
# ------------------------------------------------------------
fzf-file-widget-smart() {
  emulate -L zsh
  setopt local_options pipefail no_aliases

  # Linha de comando em uso → comportamento padrão do fzf: colar caminho(s)
  if [[ -n $BUFFER ]]; then
    zle fzf-file-widget
    return $?
  fi

  local item
  item=$(
    FZF_DEFAULT_COMMAND=${FZF_CTRL_T_COMMAND:-} \
    FZF_DEFAULT_OPTS=$(__fzf_defaults "--reverse --walker=file,dir,follow,hidden --scheme=path" \
      "${FZF_CTRL_T_OPTS-} +m --header 'enter/duplo clique: abrir arquivo ou entrar na pasta · ctrl-e: abrir e voltar · esc: sair'") \
    FZF_DEFAULT_OPTS_FILE='' $(__fzfcmd) < /dev/tty
  )
  if [[ -z $item ]]; then
    zle redisplay
    return 0
  fi

  zle push-line   # buffer (vazio) volta no próximo prompt
  if [[ -d $item ]]; then
    BUFFER="builtin cd -- ${(q)item}"
  else
    BUFFER="${EDITOR:-nano} ${(q)item}"
  fi
  zle accept-line
  local ret=$?
  zle reset-prompt
  return $ret
}

if [[ -o interactive ]] && (( $+functions[fzf-file-widget] && $+functions[__fzf_defaults] && $+functions[__fzfcmd] )); then
  zle -N fzf-file-widget-smart
  bindkey -M emacs '^T' fzf-file-widget-smart
  bindkey -M viins '^T' fzf-file-widget-smart
fi
