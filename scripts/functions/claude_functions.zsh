# ============================================================
# Claude Code session tools
#
#   cs             — picker em dois níveis: projetos → sessões
#                    (a primeira linha dá a lista plana de todas);
#                    Enter retoma, Ctrl-O abre o transcript no
#                    pager, Esc volta ao nível anterior
#   csg <termo>    — busca full-text DENTRO das sessões; preview
#                    mostra os trechos encontrados com contexto
#   csview <id>    — lê o transcript completo de uma sessão no
#                    pager (aceita caminho .jsonl ou session-id,
#                    inclusive prefixo do id)
#
# Fonte de dados: ~/.claude/projects/**/*.jsonl
# Dependências: fzf, jq
# ============================================================

zmodload zsh/datetime 2>/dev/null
zmodload -F zsh/stat b:zstat 2>/dev/null

# Caminho deste arquivo (para os subshells de preview/execute do fzf)
typeset -g _CS_SOURCE=${${(%):-%N}:A}

# ------------------------------------------------------------
# Helpers internos
# ------------------------------------------------------------

# Renderiza um transcript JSONL em texto legível (com cores ANSI):
# turnos Você/Claude com horário local + comandos/ferramentas em dim.
_cs_render() {
  emulate -L zsh
  local f=$1
  [[ -f $f ]] || { print -u2 "_cs_render: arquivo não encontrado: $f"; return 1 }

  local title cwd
  title=$(grep -m1 -o '"aiTitle":"[^"]*"' -- "$f" 2>/dev/null)
  title=${${title#\"aiTitle\":\"}%\"}
  cwd=$(grep -m1 -o '"cwd":"[^"]*"' -- "$f" 2>/dev/null)
  cwd=${${cwd#\"cwd\":\"}%\"}

  printf '\e[1;33m═══ %s ═══\e[0m\n' "${title:-(sem título)}"
  printf '\e[2m%s · sessão %s\e[0m\n' "${cwd:-?}" "${${f:t}:r}"

  jq -rn '
    def ts($e):
      ($e.timestamp // ""
       | try (sub("\\.[0-9]+"; "") | fromdate | strflocaltime("%d/%m %H:%M")) catch "");

    def body($e):
      ($e.message.content // "") as $c
      | if $e.type == "user" then
          (if ($c | type) == "string" then $c
           elif ($c | type) == "array" then
             ($c | map(select(.type? == "text") | (.text // ""))
                 | map(select(startswith("<system-reminder>") | not))
                 | join("\n"))
           else "" end)
          | if startswith("<command-") or startswith("<local-command") then "" else . end
        else
          (if ($c | type) == "array" then
             ($c | map(
                if .type? == "text" then (.text // "")
                elif .type? == "tool_use" then
                  "[2m   ⚙ " + (.name // "?") + "  "
                  + ((.input.command // .input.file_path // .input.pattern
                      // .input.prompt // ((.input // {}) | tojson))
                     | tostring | gsub("\n"; " ⏎ ") | .[0:150])
                  + "[0m"
                else "" end)
              | map(select(length > 0)) | join("\n"))
           elif ($c | type) == "string" then $c
           else "" end)
        end;

    # foreach: só imprime o cabeçalho 👤/🤖 quando o papel muda,
    # fundindo entradas consecutivas do mesmo lado num turno só
    foreach ( inputs
              | select(.type == "user" or .type == "assistant")
              | select(.isSidechain != true) ) as $e
      ( {prev: "", emit: ""} ;
        body($e) as $t
        | if ($t | length) == 0 then .emit = ""
          else
            { prev: $e.type,
              emit: ( (if $e.type != .prev then
                         (if $e.type == "user"
                          then "\n[1;36m━━ 👤 Você · " + ts($e) + "[0m\n"
                          else "\n[1;38;5;208m━━ 🤖 Claude[0m\n" end)
                       else "" end) + $t ) }
          end ;
        .emit | select(length > 0) )
  ' -- "$f" 2>/dev/null
}

# Imprime a linha do picker: "data  projeto  título<TAB>arquivo"
_cs_line() {
  emulate -L zsh
  local f=$1 title cwd proj mdate
  local -a mt

  # Título gerado pelo Claude Code, quando existir
  title=$(grep -m1 -o '"aiTitle":"[^"]*"' -- "$f" 2>/dev/null)
  title=${${title#\"aiTitle\":\"}%\"}

  # Fallback: primeira mensagem do usuário
  if [[ -z $title ]]; then
    title=$(head -20 -- "$f" | jq -r '
      select(.type=="user") | .message.content? // empty
      | if type=="array" then (map(.text? // empty) | join(" ")) else . end
    ' 2>/dev/null | grep -v '^$' | head -1)
    title=${title[1,80]}
  fi

  cwd=$(grep -m1 -o '"cwd":"[^"]*"' -- "$f" 2>/dev/null)
  cwd=${${cwd#\"cwd\":\"}%\"}
  proj=${cwd:t}

  if zstat -A mt +mtime -- "$f" 2>/dev/null; then
    strftime -s mdate '%Y-%m-%d' "$mt[1]"
  else
    mdate='????-??-??'
  fi

  print -r -- "${mdate}  ${(r:22:)proj:-?}  ${title:-(sem título)}"$'\t'"$f"
}

# Picker fzf de sessões: recebe prompt + transcripts,
# imprime o arquivo selecionado (vazio se Esc)
_cs_pick() {
  emulate -L zsh
  local prompt=$1; shift
  local f
  local -a lines
  for f in "$@"; do
    lines+=("$(_cs_line "$f")")
  done

  local src=${_CS_SOURCE:-$HOME/.claude_functions.zsh}
  local sel
  sel=$(print -rl -- "${lines[@]}" | fzf \
    --height 90% --reverse --exact \
    --delimiter '\t' --with-nth 1 \
    --tiebreak index \
    --prompt "$prompt" \
    --header 'enter: retomar · ctrl-o: ler transcript · shift-↑/↓: rolar preview · esc: voltar' \
    --preview-window 'right:55%:wrap' \
    --preview "zsh -c 'source ${(q)src}; _cs_render \"\$1\"' p {2}" \
    --bind 'shift-up:preview-half-page-up,shift-down:preview-half-page-down' \
    --bind "ctrl-o:execute(zsh -c 'source ${(q)src}; csview \"\$1\"' v {2})")

  [[ -n $sel ]] && print -r -- "${sel##*$'\t'}"
}

# Lista "data  projeto  título" das sessões de um diretório de
# projeto (ou de todos, com ALL) — usado no preview do nível 1
_cs_project_lines() {
  emulate -L zsh
  setopt local_options extended_glob null_glob
  local -a pf
  if [[ $1 == ALL ]]; then
    pf=(~/.claude/projects/**/*.jsonl(N.om))
  else
    pf=($1/*.jsonl(N.om))
  fi
  local f
  for f in $pf; do
    _cs_line "$f" | cut -f1
  done
}

# Retoma a sessão de um transcript no diretório original
_cs_resume() {
  emulate -L zsh
  local file=$1
  local id=${${file:t}:r}
  local dir
  dir=$(grep -m1 -o '"cwd":"[^"]*"' -- "$file" 2>/dev/null)
  dir=${${dir#\"cwd\":\"}%\"}

  if [[ -d $dir ]]; then
    # Subshell: ao sair do Claude você volta para o diretório atual
    (cd -- "$dir" && claude --resume "$id")
  else
    print -u2 "cs: diretório original indisponível, retomando aqui"
    claude --resume "$id"
  fi
}

_cs_check_deps() {
  if ! (( $+commands[fzf] && $+commands[jq] )); then
    print -u2 "cs: requer fzf e jq (sudo apt install fzf jq)"
    return 1
  fi
  if ! (( $+commands[claude] )); then
    print -u2 "cs: claude não encontrado no PATH"
    return 1
  fi
}

# ------------------------------------------------------------
# Comandos
# ------------------------------------------------------------

# cs — picker de sessões do Claude Code (projetos → sessões)
cs() {
  emulate -L zsh
  setopt local_options extended_glob null_glob

  _cs_check_deps || return 1

  local -a files
  files=(~/.claude/projects/**/*.jsonl(N.om))
  if (( ${#files} == 0 )); then
    print -u2 "cs: nenhuma sessão encontrada em ~/.claude/projects"
    return 1
  fi

  # Nível 1: projetos ordenados pela sessão mais recente
  # (files já vem por mtime desc; o 1º arquivo de cada dir é o mais novo)
  local f d cwd proj mdate ses
  local -a mt plines
  local -A count seen
  for f in $files; do
    d=${f:h}
    (( count[$d]++ ))
  done

  proj='todos os projetos'
  plines=("──────────  ${(r:22:)proj}  ${#files} sessões"$'\t'"ALL")
  for f in $files; do
    d=${f:h}
    [[ -n ${seen[$d]} ]] && continue
    seen[$d]=1

    cwd=$(grep -m1 -o '"cwd":"[^"]*"' -- "$f" 2>/dev/null)
    cwd=${${cwd#\"cwd\":\"}%\"}
    proj=${${cwd:t}:-${d:t}}

    if zstat -A mt +mtime -- "$f" 2>/dev/null; then
      strftime -s mdate '%Y-%m-%d' "$mt[1]"
    else
      mdate='????-??-??'
    fi

    (( count[$d] == 1 )) && ses='sessão' || ses='sessões'
    plines+=("${mdate}  ${(r:22:)proj}  ${count[$d]} ${ses}"$'\t'"$d")
  done

  local src=${_CS_SOURCE:-$HOME/.claude_functions.zsh}
  local psel pdir sel
  local -a sfiles
  while true; do
    psel=$(print -rl -- "${plines[@]}" | fzf \
      --height 90% --reverse --exact \
      --delimiter '\t' --with-nth 1 \
      --tiebreak index \
      --prompt 'projeto> ' \
      --header 'enter: abrir sessões · shift-↑/↓: rolar preview · esc: sair' \
      --preview-window 'right:55%:wrap' \
      --preview "zsh -c 'source ${(q)src}; _cs_project_lines \"\$1\"' p {2}" \
      --bind 'shift-up:preview-half-page-up,shift-down:preview-half-page-down')
    [[ -n $psel ]] || return 0

    pdir=${psel##*$'\t'}
    if [[ $pdir == ALL ]]; then
      sfiles=($files)
    else
      sfiles=($pdir/*.jsonl(N.om))
    fi

    sel=$(_cs_pick 'sessão> ' $sfiles)
    if [[ -n $sel ]]; then
      _cs_resume "$sel"
      return
    fi
    # Esc no nível 2 volta para a lista de projetos
  done
}

# csg — busca full-text dentro das sessões
csg() {
  emulate -L zsh
  setopt local_options extended_glob null_glob

  _cs_check_deps || return 1

  local q=$*
  if [[ -z $q ]]; then
    print -u2 "uso: csg <termo>"
    return 1
  fi

  local -a files cand
  files=(~/.claude/projects/**/*.jsonl(N.om))
  if (( ${#files} == 0 )); then
    print -u2 "csg: nenhuma sessão encontrada em ~/.claude/projects"
    return 1
  fi

  # Candidatas: grep no JSONL bruto (rápido; mantém ordem por data)
  cand=(${(f)"$(grep -l -i -F -- "$q" $files 2>/dev/null)"})
  if (( ${#cand} == 0 )); then
    print -u2 "csg: nenhuma sessão contém: $q"
    return 1
  fi

  local f
  local -a lines
  for f in $cand; do
    lines+=("$(_cs_line "$f")")
  done

  local src=${_CS_SOURCE:-$HOME/.claude_functions.zsh}
  local sel
  sel=$(print -rl -- "${lines[@]}" | fzf \
    --height 90% --reverse --exact \
    --delimiter '\t' --with-nth 1 \
    --tiebreak index \
    --prompt "conteúdo[$q]> " \
    --header 'enter: retomar · ctrl-o: ler transcript no 1º match · shift-↑/↓: rolar preview' \
    --preview-window 'right:55%:wrap' \
    --preview "zsh -c 'source ${(q)src}; _cs_render \"\$1\" | grep -i -F -C2 --color=always -- \"\$2\"' p {2} ${(q)q}" \
    --bind 'shift-up:preview-half-page-up,shift-down:preview-half-page-down' \
    --bind "ctrl-o:execute(zsh -c 'source ${(q)src}; csview \"\$1\" \"\$2\"' v {2} ${(q)q})")

  [[ -n $sel ]] || return 0
  _cs_resume "${sel##*$'\t'}"
}

# csview — lê o transcript completo de uma sessão no pager
csview() {
  emulate -L zsh
  setopt local_options extended_glob null_glob

  if ! (( $+commands[jq] )); then
    print -u2 "csview: requer jq (sudo apt install jq)"
    return 1
  fi

  local f=$1 pat=$2
  if [[ -z $f ]]; then
    print -u2 "uso: csview <arquivo.jsonl | session-id> [termo]"
    return 1
  fi

  # Aceita session-id (ou prefixo dele) no lugar do caminho
  if [[ ! -f $f ]]; then
    local -a hit
    hit=(~/.claude/projects/**/${f}*.jsonl(N))
    if (( ${#hit} == 0 )); then
      print -u2 "csview: sessão não encontrada: $f"
      return 1
    fi
    f=$hit[1]
  fi

  if [[ -n $pat ]]; then
    _cs_render "$f" | less -R -i -p "$pat"
  else
    _cs_render "$f" | less -R
  fi
}
