#!/bin/bash
# ==============================================================================
# scripts/install.sh — instala os scripts pessoais por symlink
#
#   scripts/bin/<nome>            -> ~/.local/bin/<nome>   (executáveis; ~/.local/bin
#                                                            entra no PATH via zsh/.zprofile)
#   scripts/functions/<nome>.zsh  -> ~/.<nome>.zsh         (bibliotecas carregadas pelo ~/.zshrc)
#
# Symlink, não cópia: o repo é a única fonte de verdade e editar aqui já vale na
# próxima shell/execução. Por isso o backup.sh não copia esses arquivos de volta —
# só confere os links (com --check).
#
# Uso: install.sh            cria/atualiza os links (idempotente)
#      install.sh --check    só relata o estado de cada link; exit 1 se algo estiver fora
#      install.sh --dry-run  mostra o que faria, sem tocar em nada
#
# Se o destino for um arquivo comum com conteúdo diferente do repo, ele é
# preservado como <destino>.bak.<timestamp> antes de virar link.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; DIM='\033[2m'; RESET='\033[0m'
info() { echo -e "${CYAN}▸${RESET} $1"; }
ok()   { echo -e "  ${GREEN}✔${RESET} $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET} $1"; }
note() { echo -e "    ${DIM}$1${RESET}"; }

MODE=install
case "${1:-}" in
  "")           ;;
  --check|-c)   MODE=check ;;
  --dry-run|-n) MODE=dry ;;
  -h|--help)    sed -n '3,/^# ====/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "uso: $0 [--check | --dry-run]" >&2; exit 2 ;;
esac

# Pares "origem<TAB>destino", um por linha
pairs() {
  local f
  for f in "$SCRIPT_DIR"/bin/*; do
    if [ -f "$f" ]; then printf '%s\t%s\n' "$f" "$HOME/.local/bin/$(basename "$f")"; fi
  done
  for f in "$SCRIPT_DIR"/functions/*.zsh; do
    if [ -f "$f" ]; then printf '%s\t%s\n' "$f" "$HOME/.$(basename "$f")"; fi
  done
}

# Caminho curto para exibir: relativo ao repo, ou com ~
short() {
  local p=$1
  p=${p#"$REPO_DIR/"}
  p=${p/#"$HOME"/\~}
  printf '%s' "$p"
}

# Estado do destino em relação à origem:
#   linked   já é symlink para a origem
#   missing  não existe
#   same     arquivo comum com conteúdo igual ao do repo (cópia antiga do install.sh)
#   stale    arquivo comum com conteúdo diferente
#   foreign  symlink para outro lugar
state_of() {
  local src=$1 dst=$2
  if [ -L "$dst" ]; then
    if [ "$dst" -ef "$src" ]; then echo linked; else echo foreign; fi
  elif [ -e "$dst" ]; then
    if cmp -s "$src" "$dst"; then echo same; else echo stale; fi
  else
    echo missing
  fi
}

if [ "$MODE" != check ]; then
  info "Scripts pessoais → symlinks (repo: $(short "$SCRIPT_DIR"))"
fi

PROBLEMS=0
while IFS=$'\t' read -r src dst; do
  st=$(state_of "$src" "$dst")
  label="$(short "$dst") → $(short "$src")"
  case "$MODE" in
    check)
      case "$st" in
        linked)  ok "$label" ;;
        missing) warn "$(short "$dst") não existe — rode scripts/install.sh"; PROBLEMS=$((PROBLEMS + 1)) ;;
        same)    warn "$(short "$dst") é cópia (não link), igual ao repo — rode scripts/install.sh"; PROBLEMS=$((PROBLEMS + 1)) ;;
        stale)   warn "$(short "$dst") é cópia com conteúdo DIFERENTE do repo"
                 note "o repo é a fonte: traga a mudança para $(short "$src") e rode scripts/install.sh"
                 PROBLEMS=$((PROBLEMS + 1)) ;;
        foreign) warn "$(short "$dst") aponta para $(readlink "$dst"), não para o repo"; PROBLEMS=$((PROBLEMS + 1)) ;;
      esac
      ;;
    dry)
      case "$st" in
        linked)  ok "$label ${DIM}(já linkado)${RESET}" ;;
        missing) echo -e "  ${CYAN}+${RESET} criaria $label" ;;
        same)    echo -e "  ${CYAN}~${RESET} trocaria a cópia por link: $label" ;;
        stale)   echo -e "  ${CYAN}~${RESET} moveria $(short "$dst") para .bak.<ts> e criaria $label" ;;
        foreign) echo -e "  ${CYAN}~${RESET} refaria o link (hoje → $(readlink "$dst")): $label" ;;
      esac
      ;;
    install)
      mkdir -p "$(dirname "$dst")"
      case "$st" in
        linked)  ok "$label ${DIM}(já linkado)${RESET}" ;;
        missing) ln -s "$src" "$dst"; ok "$label" ;;
        same)    ln -sfn "$src" "$dst"; ok "$label"; note "cópia antiga substituída por link (o conteúdo era idêntico)" ;;
        stale)   bak="$dst.bak.$(date +%s)"; mv "$dst" "$bak"; ln -s "$src" "$dst"
                 warn "$label"; note "o conteúdo diferia do repo — original preservado em $(short "$bak")" ;;
        foreign) old=$(readlink "$dst"); ln -sfn "$src" "$dst"; warn "$label"; note "apontava para $old" ;;
      esac
      case "$src" in "$SCRIPT_DIR"/bin/*) chmod u+x "$src" ;; esac
      ;;
  esac
done < <(pairs)

case "$MODE" in
  check)
    [ "$PROBLEMS" -eq 0 ] || exit 1
    ;;
  install)
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) ;;
      *) warn "~/.local/bin não está no PATH desta shell (zsh/.zprofile cuida disso em shells de login — abra um terminal novo)" ;;
    esac
    note "funções zsh entram em shells novas (ou: source ~/.zshrc)"
    ;;
esac
