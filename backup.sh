#!/bin/bash
# ==============================================================================
# backup.sh — captura as configs vivas da máquina para o repositório
#
# Direção: ~/  →  repo. O inverso é o install.sh.
#
# Duas exceções à cópia crua:
#   - claude/settings.template.json é GERADO a partir de ~/.claude/settings.json,
#     mantendo só uma allowlist de chaves. Este repo é público: autoMode, plugins
#     de trabalho e caminhos absolutos não entram.
#   - scripts/ e claude-plugins/ têm o repo como fonte da verdade (symlink e
#     marketplace local). Aqui só se confere o estado, nada é copiado de volta.
#
# Uso: ./backup.sh            captura tudo
#      ./backup.sh --dry-run  mostra o que mudaria, sem escrever
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; DIM='\033[2m'; RESET='\033[0m'
info() { echo -e "${CYAN}▸${RESET} $1"; }
ok()   { echo -e "${GREEN}✔${RESET}   $1"; }
warn() { echo -e "${YELLOW}⚠${RESET}   $1"; }
skip() { echo -e "${DIM}  ⏭ $1${RESET}"; }

DRY=0
case "${1:-}" in
  "")            ;;
  --dry-run|-n)  DRY=1 ;;
  -h|--help)     sed -n '3,/^# ====/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "uso: $0 [--dry-run]" >&2; exit 2 ;;
esac

# copia $1 (vivo) para $2 (repo), criando o diretório e respeitando --dry-run
grab() {
  local live=$1 repo=$2 label=${3:-$2}
  if [ ! -f "$live" ]; then
    skip "$label — não existe em $(printf '%s' "$live" | sed "s|$HOME|~|")"
    return
  fi
  if cmp -s "$live" "$SCRIPT_DIR/$repo" 2>/dev/null; then
    ok "$label ${DIM}(sem mudança)${RESET}"
    return
  fi
  if [ "$DRY" -eq 1 ]; then
    echo -e "  ${CYAN}~${RESET} atualizaria $label"
    return
  fi
  mkdir -p "$SCRIPT_DIR/$(dirname "$repo")"
  cp "$live" "$SCRIPT_DIR/$repo"
  ok "$label"
}

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║   💾  Linux Terminal Setup — Backup      ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${RESET}"
[ "$DRY" -eq 1 ] && echo -e "${DIM}   (dry-run: nada será escrito)${RESET}"
echo ""

# ---------- zsh ----------
info "Zsh configs..."
for f in .zshrc .zprofile .zshenv; do
  grab "$HOME/$f" "zsh/$f" "$f"
done

# ---------- nano ----------
info "nano..."
grab "$HOME/.nanorc" "nano/nanorc" "nanorc"

# ---------- starship ----------
info "Starship..."
grab "$HOME/.config/starship.toml" "starship/starship.toml" "starship.toml"

# ---------- yazi ----------
info "yazi..."
YAZI_COUNT=0
for f in yazi.toml keymap.toml theme.toml init.lua package.toml; do
  if [ -f "$HOME/.config/yazi/$f" ]; then
    grab "$HOME/.config/yazi/$f" "yazi/$f" "$f"
    YAZI_COUNT=$((YAZI_COUNT + 1))
  fi
done
[ "$YAZI_COUNT" -gt 0 ] || skip "~/.config/yazi/ sem arquivos de config"

# ---------- lazygit ----------
info "lazygit..."
grab "$HOME/.config/lazygit/config.yml" "lazygit/config.yml" "config.yml"

# ---------- ccstatusline ----------
info "ccstatusline..."
grab "$HOME/.config/ccstatusline/settings.json" "ccstatusline/settings.json" "settings.json"

# ---------- Claude Code ----------
# settings.json NÃO é copiado cru: seria vazar configuração de trabalho num repo
# público. O template é regerado com uma allowlist de chaves.
info "Claude Code..."
LIVE_SETTINGS="$HOME/.claude/settings.json"
if [ -f "$LIVE_SETTINGS" ] && command -v python3 >/dev/null 2>&1; then
  TMP=$(mktemp)
  python3 - "$LIVE_SETTINGS" "$TMP" <<'PY'
import collections, io, json, sys

live, out = sys.argv[1], sys.argv[2]
o = json.load(io.open(live, encoding="utf-8"))

# Allowlist explícita: o que NÃO está aqui nunca chega ao repo.
KEEP = ["model", "effortLevel", "tui", "statusLine", "voice", "voiceEnabled",
        "preferredNotifChannel", "remoteControlAtStartup", "agentPushNotifEnabled",
        "skipAutoPermissionPrompt", "permissions"]

tpl = collections.OrderedDict((k, o[k]) for k in KEEP if k in o)

# hooks: só os do notify.sh deste repo. Qualquer hook de terceiro é descartado.
hooks = {}
for event, entries in (o.get("hooks") or {}).items():
    kept = []
    for entry in entries:
        inner = [h for h in entry.get("hooks", [])
                 if "notify.sh" in (h.get("command") or "")]
        if inner:
            kept.append({**{k: v for k, v in entry.items() if k != "hooks"}, "hooks": inner})
    if kept:
        hooks[event] = kept
if hooks:
    tpl["hooks"] = hooks

# plugins: só os que vêm do marketplace local deste repo
plugins = {k: v for k, v in (o.get("enabledPlugins") or {}).items()
           if k.endswith("@personal")}
if plugins:
    tpl["enabledPlugins"] = plugins

# o caminho do marketplace é da máquina: vira placeholder
tpl["extraKnownMarketplaces"] = {"personal": {"source": {
    "source": "directory",
    "path": "REPLACE_WITH_ABSOLUTE_PATH/linux-config/claude-plugins"}}}

io.open(out, "w", encoding="utf-8").write(json.dumps(tpl, indent=2, ensure_ascii=False) + "\n")
PY
  if cmp -s "$TMP" "$SCRIPT_DIR/claude/settings.template.json" 2>/dev/null; then
    ok "settings.template.json ${DIM}(sem mudança)${RESET}"
    rm -f "$TMP"
  elif [ "$DRY" -eq 1 ]; then
    echo -e "  ${CYAN}~${RESET} atualizaria settings.template.json (allowlist)"
    rm -f "$TMP"
  else
    mkdir -p "$SCRIPT_DIR/claude"
    mv "$TMP" "$SCRIPT_DIR/claude/settings.template.json"
    ok "settings.template.json ${DIM}(regerado pela allowlist)${RESET}"
  fi
else
  skip "~/.claude/settings.json não existe, ou python3 ausente"
fi

# ~/.claude/CLAUDE.md é o perfil pessoal do usuário e NÃO entra neste repo,
# por decisão explícita. Se quiser versioná-lo, faça num repo privado.
skip "CLAUDE.md global — fora do repo por ser pessoal"

HOOKS_COUNT=0
if [ -d "$HOME/.claude/hooks" ]; then
  for hook in "$HOME/.claude/hooks/"*.sh; do
    [ -f "$hook" ] || continue
    grab "$hook" "claude/hooks/$(basename "$hook")" "hooks/$(basename "$hook")"
    HOOKS_COUNT=$((HOOKS_COUNT + 1))
  done
fi
[ "$HOOKS_COUNT" -gt 0 ] || skip "~/.claude/hooks/ sem scripts"

# ---------- sub-projetos: repo é a fonte, só conferimos ----------
info "Sub-projetos (fonte é o repo, nada é copiado de volta)..."
if [ -x "$SCRIPT_DIR/scripts/install.sh" ]; then
  if "$SCRIPT_DIR/scripts/install.sh" --check >/dev/null 2>&1; then
    ok "scripts/ — symlinks no lugar"
  else
    warn "scripts/ — algum symlink fora do lugar; rode: ./scripts/install.sh --check"
  fi
fi
if [ -d "$SCRIPT_DIR/claude-plugins" ]; then
  ok "claude-plugins/ — editado no repo; reinstale com make -C claude-plugins reinstall PLUGIN=<nome>"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║   ✅  Backup concluído!                  ║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${RESET}"
echo ""
if [ "$DRY" -eq 0 ]; then
  echo "  Próximos passos:"
  echo -e "    ${CYAN}git add -A${RESET}"
  echo -e "    ${CYAN}git commit -m \"backup: \$(date +%Y-%m-%d)\"${RESET}"
  echo ""
  echo -e "  ${DIM}O template de settings é gerado por allowlist, mas confira o diff${RESET}"
  echo -e "  ${DIM}de claude/ e zsh/ antes de publicar mesmo assim.${RESET}"
fi
echo ""
