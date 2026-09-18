# ============================================================
# yazi: gerenciador de arquivos no terminal
#
#   y [dir]  — abre o yazi e, ao sair (q), a shell fica na pasta onde
#              você parou (o yazi grava o cwd num arquivo temporário via
#              --cwd-file; este wrapper lê e faz o cd). É o snippet oficial
#              da doc do yazi, com unlink no lugar de rm.
#
# Config: ~/.config/yazi/ (espelho em yazi/ no linux-config). Tema e
# plugins vêm do package.toml via `ya pkg install`. Abre arquivos de texto
# no $EDITOR (nano, definido em ~/.zshenv).
# Dependências: yazi; opcionais já instaladas: fd, poppler, ffmpeg, jq, rg, fzf.
# ============================================================

y() {
  emulate -L zsh
  if ! (( $+commands[yazi] )); then
    print -u2 "y: requer yazi (veja o README: o apt do Ubuntu 24.04 não tem yazi)"
    return 1
  fi
  local tmp cwd
  tmp=$(mktemp -t yazi-cwd.XXXXXX) || return 1
  yazi "$@" --cwd-file="$tmp"
  if [[ -s $tmp ]]; then
    IFS= read -r -d '' cwd < "$tmp"
    [[ -n $cwd && $cwd != $PWD ]] && builtin cd -- "$cwd"
  fi
  unlink "$tmp" 2>/dev/null
}
