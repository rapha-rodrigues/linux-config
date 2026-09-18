# 🛠️ scripts — funções zsh pessoais

Sub-projeto do `linux-config`: tudo aqui é **desenvolvido neste repo** e instalado na máquina por
**symlink**, então editar um arquivo aqui já vale na próxima shell. Nada é copiado de volta pelo
`backup.sh`: o repo é a fonte da verdade; o backup só confere os links.

## O que tem

| Arquivo | Instala em | O que faz |
|---|---|---|
| `functions/git_functions.zsh` | `~/.git_functions.zsh` | Fluxo de branches com PR via `gh`: `gstart`, `gship`, `gdone` (master) e `gstartd`, `gshipd`, `gdoned`, `greleased` (develop → master) |
| `functions/claude_functions.zsh` | `~/.claude_functions.zsh` | Sessões do Claude Code: `cs` (picker projetos → sessões, com preview do transcript), `csg <termo>` (busca full-text dentro das sessões), `csview <id>` (lê o transcript no pager). Requer `fzf` e `jq` |
| `functions/fzf_functions.zsh` | `~/.fzf_functions.zsh` | `fe [dir] [consulta]`: navegador de arquivos com fzf — lista arquivos e pastas à esquerda, preview `batcat`/`eza --tree` à direita; Enter ou duplo clique **abre o arquivo** no `$EDITOR` (nano) e volta à lista, ou **entra na pasta** (`..` sobe); `ctrl-g` faz `cd` para a pasta atual e sai; `ctrl-v` abre no VS Code, `ctrl-y` copia o caminho. Também troca o **Ctrl-T** por um widget inteligente |
| `functions/yazi_functions.zsh` | `~/.yazi_functions.zsh` | `y [dir]`: abre o yazi e, ao sair, a shell fica na pasta onde você parou. Requer `yazi` |

`bin/` existe e está vazio: executáveis novos entram ali e o `install.sh` os linka em `~/.local/bin`
automaticamente, sem edição nenhuma.

O `~/.zshrc` (espelhado em `zsh/.zshrc`) carrega cada biblioteca com `[ -f ~/.<nome>.zsh ] && source ...`;
o `~/.local/bin` entra no PATH pelo `zsh/.zprofile`.

## Instalar / conferir

```bash
make install     # cria/atualiza os symlinks (idempotente) — ou ./install.sh
make dry-run     # mostra o que install faria
make check       # estado de cada link; é o que o backup.sh roda
make test        # bash -n / zsh -n + carrega as funções numa zsh limpa
```

`install.sh` preserva arquivos comuns que difiram do repo como `<destino>.bak.<timestamp>` antes de
trocá-los por link. O `install.sh` da raiz chama este instalador no passo **9/9**.

## Nomes de binário diferentes no Ubuntu

Dois pacotes do Debian renomeiam o executável para evitar conflito, e isso afeta estas funções:

| Ferramenta | Binário no Ubuntu | Como o setup resolve |
|---|---|---|
| `bat` | `batcat` | alias em `zsh/.zshrc`; `fe` detecta em runtime |
| `fd` | `fdfind` | `install.sh` da raiz cria o symlink `~/.local/bin/fd` |

## fe — navegar, ler e editar sem sair do terminal

```
fe                    # a partir do diretório atual
fe src/               # a partir de outro diretório
fe README             # já filtrando
```

A lista traz arquivos **e** pastas (relativos à pasta atual do navegador, mostrada no prompt). Enter ou
duplo clique (o fzf aceita mouse) em **arquivo** abre no `$EDITOR`, `nano` se a variável não existir; ao
fechar você volta à lista com o mesmo filtro. Em **pasta**, entra nela; a entrada `..` sobe. `ctrl-g` faz a
**shell** dar `cd` para a pasta onde o navegador está e sai; Esc sai deixando a shell onde estava. A
listagem usa `fd` quando instalado (respeita `.gitignore`) e `find` caso contrário.

O `ctrl-y` (copiar caminho) detecta o ambiente gráfico: `wl-copy` no Wayland, `xclip` ou `xsel` no X11.
Sem nenhum dos três ele vira no-op silencioso em vez de erro dentro do fzf.

## Ctrl-T inteligente

| Situação | Enter / duplo clique |
|---|---|
| Linha de comando **vazia** | abre o arquivo no `$EDITOR` ou entra na pasta (`builtin cd`) |
| Linha **com texto** (`nano ` + Ctrl-T) | cola o caminho, como o widget padrão (`ctrl-e` abre no editor e volta) |

O widget reaproveita as peças internas do fzf (`__fzf_defaults`, `__fzfcmd`) e só é ativado se elas
existirem; se uma versão futura as renomear, o Ctrl-T padrão continua valendo.

## Adicionar um script novo

1. Executável: salve em `bin/<nome>` (sem extensão, com shebang) e `chmod +x`. Biblioteca zsh:
   `functions/<nome>.zsh`, e acrescente o `source` correspondente no `zsh/.zshrc` **e** no `~/.zshrc` vivo.
2. `make install` cria o link; `make test` confere (inclua funções novas na lista do alvo `test`).
3. Documente na tabela acima.

Convenções: bash com `set -euo pipefail` e `--help`; zsh com `emulate -L zsh` nas funções e dependências
checadas em runtime (`(( $+commands[fzf] ))`), avisando o pacote apt a instalar.
