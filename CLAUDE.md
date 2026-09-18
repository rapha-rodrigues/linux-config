# linux-config — instruções para o Claude Code

Setup de terminal para Ubuntu, versionado. Convivem aqui **dois tipos de pasta**, e a regra de
trabalho muda conforme o tipo:

| Tipo | Fonte da verdade | Pastas | Como alterar |
|---|---|---|---|
| **Espelho** de configuração | a máquina (`~/…`) | `zsh/`, `nano/`, `starship/`, `yazi/`, `lazygit/`, `ccstatusline/`, `claude/` | Edite o arquivo vivo em `~` e rode `./backup.sh`, **ou** edite no repo e rode `./install.sh`. Nunca deixe os dois divergirem sem avisar o usuário. |
| **Sub-projeto** (desenvolvido aqui) | o repo | `scripts/`, `claude-plugins/` | Edite no repo. Cada um tem `README.md`, `CLAUDE.md` (carregado sob demanda) e `Makefile`. |

## Este repo é público

É a restrição que manda em tudo aqui.

- `claude/settings.template.json` é **gerado** pelo `backup.sh` a partir do `~/.claude/settings.json`
  vivo, mantendo só uma **allowlist** de chaves. Nunca troque isso por uma cópia crua: o settings vivo
  carrega `autoMode` com repos e fronteiras de produção do trabalho do usuário.
- `~/.claude/CLAUDE.md` (perfil pessoal) **não entra**. O `backup.sh` pula de propósito.
- Aliases de máquina, SSH, IPs e tokens vão em `~/.zshrc.local`, que o `.zshrc` carrega no fim e o
  repo ignora. Se encontrar algo desse tipo dentro de `zsh/`, tire e avise.

## Espelhos

- `backup.sh` copia máquina → repo; `install.sh` (interativo, 9 passos) copia repo → máquina. Ao
  adicionar um componente, atualize **os dois scripts**, a tabela e a árvore do `README.md`.
- `install.sh` nunca sobrescreve em silêncio: preserva o original em `<destino>.bak.<timestamp>`.

## Sub-projetos

- **`scripts/`** — funções zsh instaladas por **symlink** em `~` (`make -C scripts install`). Editar
  no repo já vale na próxima shell; `backup.sh` só confere os links. Teste com `make -C scripts test`.
  `bin/` está vazio: executáveis novos entram ali e o instalador os linka sozinho.
- **`claude-plugins/`** — raiz do marketplace local `personal`; um plugin por subpasta. Plugin
  instalado roda do cache: depois de editar, o usuário precisa reinstalar
  (`make -C claude-plugins reinstall PLUGIN=…`) e reiniciar o Claude Code.
- Ao trabalhar dentro de um deles, siga o `CLAUDE.md` da pasta.

## Ubuntu, não macOS

Este repo nasceu de um porte. Ao escrever qualquer coisa nova, lembre:

- `bat` é `batcat`, `fd` é `fdfind`. Detecte em runtime, não assuma.
- Clipboard: `wl-copy` (Wayland) → `xclip` → `xsel`, nessa ordem, com no-op silencioso no fim.
- Notificação é `notify-send`, não `osascript`.
- `stat -c %s` (GNU), não `stat -f %z` (BSD).
- `sed -i` do GNU não leva o argumento vazio que o BSD exige.
- Nada de Homebrew, `/Applications`, `~/Library`, `plutil` ou `defaults`.

## Convenções

- Documentação em português (pt-BR). Código e comentários podem misturar. Commits em inglês, no
  imperativo. Commite só quando o usuário pedir.
- Scripts bash: `set -euo pipefail`, helpers `info/ok/warn` coloridos, `bash -n` antes de entregar.
  Funções zsh: `emulate -L zsh` e dependências checadas com `(( $+commands[x] ))`.
  Sem `rm -rf` fora de alvos `clean`.
- Ao mover ou renomear pastas, procure referências com `grep -rn` (README, `install.sh`, `backup.sh`,
  READMEs dos sub-projetos) — os caminhos aparecem em vários lugares.
