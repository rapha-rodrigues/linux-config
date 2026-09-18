#!/bin/bash
# usage: notify.sh <label> <urgency>
#   label:   "Needs your input" (evento Notification) ou "Finished" (evento Stop) — vem do settings.json
#   urgency: low | normal | critical (padrão: normal). Vira --urgency do notify-send.
#
# Hook global do Claude Code: notificação de desktop quando o Claude precisa de você
# (Notification) ou terminou um turno (Stop). Usa notify-send, que é o padrão
# freedesktop e funciona em GNOME, KDE, Sway, Hyprland e afins.
#
# Título "<projeto> · <label>". Corpo: a mensagem do Claude Code no Notification;
# vazio no Stop (é só "acabou", não há nada a ler). Nome do projeto, nesta ordem:
#   1. arquivo opcional <cwd>/.claude/notify-title (primeira linha)
#   2. nome da pasta do projeto (basename do cwd)
#
# Regras automáticas (sem configuração):
#   - só tipos que pedem ação passam (allowlist abaixo); idle_prompt, que o Claude Code
#     re-dispara a cada ~60 s enquanto acha que o terminal está sem foco, é descartado
#   - se o transcript crescer em ~1,5 s, o Claude seguiu sozinho (ex.: modo auto negou/
#     aprovou) → não notifica
#
# Sem notify-send instalado o hook cai no fallback de bell (\a) e segue em silêncio.
#   sudo apt install libnotify-bin
#
# NOTIFY_REPLAY=1: imprime a decisão e sai sem emitir (para testes).

export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
LABEL="${1:-Needs your input}"
URGENCY="${2:-normal}"

IN=""
[ -t 0 ] || IN=$(cat 2>/dev/null)

json_field() {
  [ -n "$IN" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$IN" | jq -r --arg k "$1" '.[$k] // empty' 2>/dev/null
  else
    printf '%s' "$IN" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
  fi
}

EVENT=$(json_field hook_event_name)
NTYPE=$(json_field notification_type)
MSG=$(json_field message); MSG=${MSG:0:600}
CWD=$(json_field cwd); [ -n "$CWD" ] || CWD="$PWD"
TRANSCRIPT=$(json_field transcript_path)

finish() {  # $1 = decisão (só exibida em modo replay)
  [ -n "${NOTIFY_REPLAY:-}" ] && echo "decisão: $1${TITLE:+ · título: $TITLE}"
  exit 0
}

# --- 0) Stop: fim de turno. stop_hook_active=true é o Stop re-disparado depois de
# um stop hook forçar continuação → ignora.
if [ "$EVENT" = "Stop" ]; then
  [ "$(json_field stop_hook_active)" = "true" ] && finish "skip:stop-hook-active"
  MSG=""
fi

# --- 1) allowlist: só avisos que pedem ação ---
case "$NTYPE" in
  ""|permission_prompt|worker_permission_prompt|elicitation_dialog|elicitation_url_dialog|agent_needs_input) ;;
  *) finish "skip:type" ;;
esac

# --- 2) o Claude seguiu sozinho? (só no Notification) ---
# stat -c é GNU coreutils; no macOS seria stat -f.
if [ "$EVENT" != "Stop" ] && [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  size0=$(stat -c %s "$TRANSCRIPT" 2>/dev/null || echo 0)
  sleep "${NOTIFY_DEBOUNCE:-1.5}"
  size1=$(stat -c %s "$TRANSCRIPT" 2>/dev/null || echo 0)
  [ "$size1" != "$size0" ] && finish "skip:resolved"
fi

# --- 3) rótulo do projeto ---
PROJECT=""
[ -r "$CWD/.claude/notify-title" ] && PROJECT=$(head -n1 "$CWD/.claude/notify-title" | tr -d '\r')
[ -n "$PROJECT" ] || PROJECT=$(basename "$CWD")
TITLE="$PROJECT · $LABEL"
if [ "$EVENT" = "Stop" ]; then BODY=""; else BODY="${MSG:-$LABEL}"; fi

# --- 4) emitir ---
[ -n "${NOTIFY_REPLAY:-}" ] && finish "send:notify-send"

if command -v notify-send >/dev/null 2>&1; then
  # -a agrupa as notificações sob um mesmo app no centro de notificações.
  # -h string:desktop-entry ajuda o GNOME a escolher o ícone.
  notify-send \
    --app-name="Claude Code" \
    --urgency="$URGENCY" \
    --hint=string:desktop-entry:claude-code \
    -- "$TITLE" "$BODY" >/dev/null 2>&1
else
  # Sem libnotify: bell no terminal, melhor que silêncio total.
  printf '\a' >/dev/tty 2>/dev/null || true
fi
finish "send:notify-send"
