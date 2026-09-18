#!/bin/bash
# ==============================================================================
# install.sh — restaura o setup de terminal numa máquina Ubuntu limpa
#
# Direção: repo  →  ~/. O inverso é o backup.sh.
# Interativo: cada passo pergunta antes de tocar em qualquer coisa.
#
# Testado em Ubuntu 24.04 LTS. Deve funcionar em qualquer derivado Debian com apt.
#
# Uso: ./install.sh          passo a passo, perguntando
#      ./install.sh --yes    responde sim a tudo (para provisionamento)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; DIM='\033[2m'; RESET='\033[0m'
info() { echo -e "\n${CYAN}▸${RESET} ${1}"; }
ok()   { echo -e "${GREEN}✔${RESET}   $1"; }
warn() { echo -e "${YELLOW}⚠${RESET}   $1"; }
err()  { echo -e "${RED}✖${RESET}   $1"; }
skip() { echo -e "${DIM}  ⏭ $1${RESET}"; }

ASSUME_YES=0
case "${1:-}" in
  "")         ;;
  --yes|-y)   ASSUME_YES=1 ;;
  -h|--help)  sed -n '3,/^# ====/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "uso: $0 [--yes]" >&2; exit 2 ;;
esac

ask() {
  [ "$ASSUME_YES" -eq 1 ] && return 0
  local answer
  read -r -p "$(echo -e "${YELLOW}?${RESET} $1 [y/N] ")" answer || return 1
  case "$answer" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# Copia repo → ~, preservando o que já existia se o conteúdo diferir
place() {
  local repo=$1 live=$2 label=${3:-$2}
  if [ ! -f "$SCRIPT_DIR/$repo" ]; then
    skip "$label — não existe no repo"
    return
  fi
  mkdir -p "$(dirname "$live")"
  if cmp -s "$SCRIPT_DIR/$repo" "$live" 2>/dev/null; then
    ok "$label ${DIM}(já igual)${RESET}"
    return
  fi
  if [ -e "$live" ]; then
    local bak="$live.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$live" "$bak"
    warn "$label — original preservado em $(printf '%s' "$bak" | sed "s|$HOME|~|")"
  fi
  cp "$SCRIPT_DIR/$repo" "$live"
  ok "$label"
}

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║   🐧  Linux Terminal Setup — Install     ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${RESET}"

if ! command -v apt-get >/dev/null 2>&1; then
  err "apt-get não encontrado. Este script assume Ubuntu/Debian."
  exit 1
fi
echo -e "${DIM}   $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")${RESET}"

# ---------- 1) pacotes do apt ----------
info "1/9  Pacotes base (apt)"
APT_PKGS=(zsh git curl nano jq fzf ripgrep bat eza direnv fd-find
          unzip fontconfig libnotify-bin xclip)
MISSING=()
for p in "${APT_PKGS[@]}"; do
  dpkg -s "$p" >/dev/null 2>&1 || MISSING+=("$p")
done
if [ ${#MISSING[@]} -eq 0 ]; then
  ok "todos já instalados"
elif ask "Instalar: ${MISSING[*]}?"; then
  sudo apt-get update
  sudo apt-get install -y "${MISSING[@]}" && ok "pacotes instalados"
else
  skip "pacotes pulados — passos seguintes podem falhar"
fi

# eza não existe no apt do Ubuntu < 24.04; wl-clipboard só faz sentido no Wayland
if [ -n "${WAYLAND_DISPLAY:-}" ] && ! command -v wl-copy >/dev/null 2>&1; then
  ask "Sessão Wayland detectada. Instalar wl-clipboard (ctrl-y do fe)?" \
    && sudo apt-get install -y wl-clipboard && ok "wl-clipboard instalado"
fi

# No Ubuntu os binários de bat e fd têm outro nome; os aliases do .zshrc cobrem o bat.
command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1 && {
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
  ok "fd → fdfind (symlink em ~/.local/bin)"
}

# ---------- 2) zsh como shell padrão ----------
info "2/9  Zsh como shell padrão"
if [ "$(basename "${SHELL:-}")" = "zsh" ]; then
  ok "já é o shell padrão"
elif command -v zsh >/dev/null 2>&1 && ask "Definir zsh como shell padrão (chsh)?"; then
  chsh -s "$(command -v zsh)" && ok "definido — vale no próximo login"
else
  skip "mantido $(basename "${SHELL:-desconhecido}")"
fi

# ---------- 3) Oh My Zsh + plugins ----------
info "3/9  Oh My Zsh e plugins"
if [ -d "$HOME/.oh-my-zsh" ]; then
  ok "Oh My Zsh já instalado"
elif ask "Instalar Oh My Zsh?"; then
  RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    && ok "Oh My Zsh instalado"
fi
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for plug in zsh-autosuggestions zsh-syntax-highlighting; do
  if [ -d "$ZSH_CUSTOM/plugins/$plug" ]; then
    ok "$plug já presente"
  elif [ -d "$HOME/.oh-my-zsh" ]; then
    git clone -q --depth 1 "https://github.com/zsh-users/$plug" \
      "$ZSH_CUSTOM/plugins/$plug" && ok "$plug clonado"
  fi
done

# ---------- 4) configs do shell ----------
info "4/9  Configs do zsh e do nano"
place "zsh/.zshrc"    "$HOME/.zshrc"    ".zshrc"
place "zsh/.zprofile" "$HOME/.zprofile" ".zprofile"
place "zsh/.zshenv"   "$HOME/.zshenv"   ".zshenv"
place "nano/nanorc"   "$HOME/.nanorc"   ".nanorc"
[ -f "$HOME/.zshrc.local" ] || {
  printf '# Aliases e variáveis desta máquina. Fora do versionamento.\n' > "$HOME/.zshrc.local"
  ok ".zshrc.local criado (vazio, para o que é local)"
}

# ---------- 5) Starship ----------
info "5/9  Starship"
if command -v starship >/dev/null 2>&1; then
  ok "já instalado ($(starship --version | head -1))"
elif ask "Instalar Starship?"; then
  curl -sS https://starship.rs/install.sh | sh -s -- --yes && ok "Starship instalado"
fi
place "starship/starship.toml" "$HOME/.config/starship.toml" "starship.toml"

# ---------- 6) Nerd Font ----------
info "6/9  Nerd Font (ícones do eza, starship e yazi)"
FONT_DIR="$HOME/.local/share/fonts"
if find "$FONT_DIR" -iname '*Nerd*' -print -quit 2>/dev/null | grep -q .; then
  ok "já há uma Nerd Font em ~/.local/share/fonts"
elif ask "Baixar DroidSansMono Nerd Font do GitHub?"; then
  mkdir -p "$FONT_DIR"
  TMPZIP=$(mktemp --suffix=.zip)
  if curl -fsSL -o "$TMPZIP" \
      https://github.com/ryanoasis/nerd-fonts/releases/latest/download/DroidSansMono.zip; then
    unzip -oq "$TMPZIP" -d "$FONT_DIR" -x 'LICENSE*' 'README*' && fc-cache -f >/dev/null
    ok "fonte instalada e cache atualizado"
  else
    warn "download falhou — instale manualmente de github.com/ryanoasis/nerd-fonts"
  fi
  rm -f "$TMPZIP"
fi
skip "configure a fonte no seu emulador de terminal (GNOME Terminal, Kitty, Alacritty…)"

# ---------- 7) yazi + lazygit ----------
info "7/9  yazi e lazygit"
if command -v yazi >/dev/null 2>&1; then
  ok "yazi já instalado"
else
  skip "yazi não está no apt do Ubuntu 24.04. Opções: cargo install --locked yazi-fm yazi-cli,"
  skip "  snap install yazi --classic, ou o binário de github.com/sxyazi/yazi/releases"
fi
if [ -d "$HOME/.config/yazi" ] || ask "Copiar a config do yazi mesmo sem o binário?"; then
  for f in yazi.toml keymap.toml theme.toml init.lua package.toml; do
    [ -f "$SCRIPT_DIR/yazi/$f" ] && place "yazi/$f" "$HOME/.config/yazi/$f" "yazi/$f"
  done
  [ -d "$SCRIPT_DIR/yazi/flavors" ] && {
    mkdir -p "$HOME/.config/yazi/flavors"
    cp -R "$SCRIPT_DIR/yazi/flavors/." "$HOME/.config/yazi/flavors/"
    ok "yazi/flavors"
  }
fi
if command -v lazygit >/dev/null 2>&1; then
  ok "lazygit já instalado"
elif ask "Instalar lazygit (binário da última release)?"; then
  LG_VER=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
           | grep -Po '"tag_name": *"v\K[^"]*' || true)
  if [ -n "$LG_VER" ]; then
    TMPTGZ=$(mktemp --suffix=.tar.gz)
    curl -fsSL -o "$TMPTGZ" \
      "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LG_VER}_Linux_x86_64.tar.gz" \
      && mkdir -p "$HOME/.local/bin" \
      && tar -xzf "$TMPTGZ" -C "$HOME/.local/bin" lazygit \
      && ok "lazygit $LG_VER em ~/.local/bin"
    rm -f "$TMPTGZ"
  else
    warn "não consegui descobrir a versão — instale manualmente"
  fi
fi
place "lazygit/config.yml" "$HOME/.config/lazygit/config.yml" "lazygit/config.yml"

# ---------- 8) Claude Code ----------
info "8/9  Claude Code"
if command -v claude >/dev/null 2>&1; then
  ok "claude já no PATH"
else
  skip "instale de docs.claude.com/claude-code e rode este script de novo"
fi

place "claude/hooks/notify.sh" "$HOME/.claude/hooks/notify.sh" "hooks/notify.sh"
[ -f "$HOME/.claude/hooks/notify.sh" ] && chmod +x "$HOME/.claude/hooks/notify.sh"
place "ccstatusline/settings.json" "$HOME/.config/ccstatusline/settings.json" "ccstatusline"

# settings.json: template com o caminho do marketplace resolvido. Nunca sobrescreve
# um settings.json existente sem confirmação, porque ele acumula estado da máquina.
if [ -f "$SCRIPT_DIR/claude/settings.template.json" ]; then
  TARGET="$HOME/.claude/settings.json"
  RENDERED=$(mktemp)
  sed "s|REPLACE_WITH_ABSOLUTE_PATH/linux-config|$SCRIPT_DIR|" \
    "$SCRIPT_DIR/claude/settings.template.json" > "$RENDERED"
  if [ ! -f "$TARGET" ]; then
    mkdir -p "$HOME/.claude"
    cp "$RENDERED" "$TARGET"
    ok "settings.json criado a partir do template"
  elif ask "~/.claude/settings.json já existe. Sobrescrever com o template (backup antes)?"; then
    cp "$TARGET" "$TARGET.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$RENDERED" "$TARGET"
    ok "settings.json substituído (backup ao lado)"
  else
    skip "settings.json mantido — compare com claude/settings.template.json à mão"
  fi
  rm -f "$RENDERED"
fi

# ---------- 9) sub-projetos ----------
info "9/9  Scripts pessoais e plugins do Claude Code"
if ask "Criar os symlinks de scripts/ (funções zsh em ~/)?"; then
  "$SCRIPT_DIR/scripts/install.sh"
fi
if command -v claude >/dev/null 2>&1; then
  echo ""
  echo "  Marketplace local de plugins, rode você mesmo:"
  echo -e "    ${CYAN}claude plugin marketplace add $SCRIPT_DIR/claude-plugins${RESET}"
  echo -e "    ${CYAN}claude plugin install english-coach@personal${RESET}"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║   ✅  Instalação concluída!              ║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${RESET}"
echo ""
echo "  Abra um terminal novo (ou: exec zsh) para carregar tudo."
echo -e "  ${DIM}Coisas desta máquina (aliases, SSH) vão em ~/.zshrc.local, fora do repo.${RESET}"
echo ""
