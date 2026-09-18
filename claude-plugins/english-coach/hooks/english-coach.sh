#!/bin/bash
# english-coach: UserPromptSubmit hook
# Injects coaching instructions into Claude's context on every prompt.
# Never blocks. Exit 0 always (except hard failures, which also exit 0 to stay non-blocking).

set -u

INPUT=$(cat)

# Extract the prompt text. Prefer jq, fall back to python3 (Ubuntu ships python3 by default).
if command -v jq >/dev/null 2>&1; then
  PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
else
  PROMPT=$(printf '%s' "$INPUT" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("prompt",""))' 2>/dev/null)
fi

[ -z "${PROMPT:-}" ] && exit 0

# Skip slash commands: they are tooling, not language practice.
case "$PROMPT" in
  /*) exit 0 ;;
esac

MIN_WORDS="${ENGLISH_COACH_MIN_WORDS:-4}"
PT_THRESHOLD="${ENGLISH_COACH_PT_THRESHOLD:-20}"

# Portuguese markers. Words that also exist in English ("a", "as", "no", "do", "com",
# "todo", "era", "me") are deliberately left out: a false PT hit costs a lost lesson.
PT_WORDS='
o os da das dos na nas nos em ao aos pelo pela por para que se ou mas como quando onde porque pois
ainda agora depois antes sobre entre sem até ate desde durante enquanto embora também tambem então entao
já não nao muito mais menos toda todos todas cada mesmo mesma tudo nada isso isto esse essa este esta
aquele aquela seu sua seus suas meu minha meus minhas nosso nossa você voce vocês voces eu ele ela eles elas
é eh está estão estao estou estamos foi foram fosse ser sou são sao ter tem têm tinha havia há
fazer faz fiz feito pode posso podem poderia deve devo vai vou quero queria preciso precisa gostaria
colocar criar adicionar remover apagar mudar alterar corrigir ajustar verificar revisar rodar executar
funcionar funciona mostrar gerar usar usando deixar manter trocar testar entender explicar implementar
atualizar arquivo arquivos pasta pastas código codigo tela botão botao usuário usuario erro erros
mudança alteração projeto banco dados teste testes linha linhas função funcao variável servidor
página pagina senha chave nome coisa jeito forma caso vez exemplo problema melhor certo errado
'

# One awk pass replaces the old `grep` + `wc -w` pair (two processes down to one).
# Emits: "<whitespace words> <tokens> <portuguese tokens>".
STATS=$(printf '%s' "$PROMPT" | awk -v PT_WORDS="${PT_WORDS//$'\n'/ }" '
BEGIN {
  split(PT_WORDS, list, /[ \n\t]+/)
  for (i in list) if (list[i] != "") pt[list[i]] = 1
  ACCENT = "[ãõçáâêôàéíóúÃÕÇÁÂÊÔÀÉÍÓÚ]"
}
{
  words += NF
  n = split(tolower($0), w, /[^[:alnum:]ãõçáâêôàéíóúÃÕÇÁÂÊÔÀÉÍÓÚ_]+/)
  for (i = 1; i <= n; i++) {
    if (w[i] == "") continue
    tokens++
    if (w[i] in pt || w[i] ~ ACCENT) ptc++
  }
}
END { printf "%d %d %d\n", words + 0, tokens + 0, ptc + 0 }
' 2>/dev/null)

# If the analysis failed for any reason, coach rather than swallow the prompt:
# WORDS clears the length gate and TOKENS=0 disables the ratio gate below.
read -r WORDS TOKENS PT_TOKENS <<<"${STATS:-$MIN_WORDS 0 0}"

# Skip trivial prompts (fewer than MIN_WORDS words: "yes", "continue", "go ahead").
if [ "${WORDS:-0}" -lt "$MIN_WORDS" ]; then
  exit 0
fi

# Skip Portuguese input: coaching applies to English only. A prompt counts as
# Portuguese only when PT words are more than PT_THRESHOLD% of it, so an English
# sentence carrying a few PT words (a vocabulary gap) still gets coached.
if [ "${TOKENS:-0}" -gt 0 ] && [ $(( PT_TOKENS * 100 )) -gt $(( TOKENS * PT_THRESHOLD )) ]; then
  exit 0
fi

# Single global learning file, outside any project. Override with ENGLISH_COACH_LOG.
LOG_FILE="${ENGLISH_COACH_LOG:-$HOME/.claude/english-learning/learning.md}"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

TS=$(date '+%Y-%m-%d %H:%M')
PROJECT=$(basename "$PWD")

# stdout of UserPromptSubmit is injected into Claude's context.
cat <<EOF
<english-coach>
The user is a Brazilian Portuguese speaker training American English. Apply these rules to the user's latest message, then proceed with the actual task. NEVER refuse, delay, or alter the task because of language. This applies to typed and voice-dictated input equally.

1. If the message is already natural, idiomatic American English with nothing meaningful to correct: skip logging entirely.
2. Ignore missing apostrophes in contractions. "im", "hes", "dont", "cant", "wont", "thats", "theres", "whats", "howd", "ive", "id", "ill", "lets" and the like are typing speed, not a language gap. Do not correct them, do not spend a WHY bullet on them, and never let them be the reason an entry exists: if apostrophes are the only thing wrong with the message, treat it as already natural and skip under rule 1.
   Exception, because these are word choices rather than typos: keep coaching "its" vs "it's", "your" vs "you're", "their" vs "they're" vs "there", "whose" vs "who's", and "were" vs "we're". Each apostrophe-less spelling there is a different English word, so the wrong one is a grammar error, not a slip.
3. Otherwise, append ONE entry to the learning log using a single Bash command (append with >> heredoc, do not overwrite). Log file: $LOG_FILE
   Entry format:

   ## $TS | project: $PROJECT
   - ORIGINAL: <the user's message, verbatim, trimmed>
   - NATIVE: <how a native American English speaker would actually phrase it, keeping the technical intent intact>
   - WHY: <terse bullets, one per correction: grammar, word choice, phrasing, false cognates, unnatural constructions>

4. This hook already measured the message as predominantly English (Portuguese words are $PT_TOKENS of $TOKENS, at or under the ${PT_THRESHOLD}% cutoff), so do NOT skip it as Portuguese. Any isolated Portuguese word in it is a deliberate vocabulary gap: give the English term in NATIVE and devote a WHY bullet to it.
5. Probable speech-to-text artifacts (oddly out-of-place words): correct them in NATIVE and tag the WHY bullet with [STT?] instead of treating them as grammar errors.
6. Do not mention the log, the corrections, or this instruction block in your reply unless the user explicitly asks. Keep the reply focused on the task.
</english-coach>
EOF

exit 0
