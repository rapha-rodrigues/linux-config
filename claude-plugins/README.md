# 🔌 claude-plugins — marketplace local `personal`

Sub-projeto do `linux-config`: meus plugins pessoais do Claude Code, servidos por um
**marketplace local** chamado `personal`, cuja raiz é **esta pasta** (`.claude-plugin/marketplace.json`).
Cada plugin é uma subpasta irmã; adicionar um plugin é criar a pasta e listá-la no manifesto.

```
claude-plugins/
├── .claude-plugin/marketplace.json   # o marketplace: nome "personal" + lista de plugins
├── Makefile                          # register · install · reinstall · dev · validate · check · list
├── english-coach/                    # plugin: coaching passivo de inglês
│   ├── .claude-plugin/plugin.json
│   ├── README.md
│   ├── commands/english-review.md    # /english-review
│   └── hooks/
│       ├── hooks.json                # UserPromptSubmit → english-coach.sh
│       └── english-coach.sh
└── <proximo-plugin>/
```

## Plugins

| Plugin | O que faz | Doc |
|---|---|---|
| **english-coach** | A cada prompt em inglês, um hook `UserPromptSubmit` injeta instruções e o Claude registra a versão nativizada em `~/.claude/english-learning/learning.md`, sem nunca bloquear ou alterar a tarefa. `/english-review` resume os erros recorrentes, sugere drills e lista todas as entradas | [english-coach/README.md](english-coach/README.md) |

## Instalar numa máquina nova

Fica fora do `install.sh`/`backup.sh` da raiz de propósito: o CLI do Claude Code é quem gerencia
o estado dos plugins (`~/.claude/plugins/`, `enabledPlugins` e `extraKnownMarketplaces` no
`settings.json` — este último vem de `claude/settings.template.json`, com o caminho
resolvido pelo `install.sh` da raiz).

```bash
make register                        # claude plugin marketplace add <esta pasta>
make install PLUGIN=english-coach    # claude plugin install english-coach@personal
```

Depois reinicie o Claude Code (hooks carregam no início da sessão) e confira com `/hooks`.

`make register` é idempotente: se o `settings.json` escrito pelo `install.sh` (ou um registro antigo)
já trouxer um `personal` apontando para **outro** caminho, o `add` com o mesmo nome **substitui** o registro
sem desinstalar nada. `make install` e `make reinstall` conferem antes (`make check-registered`) se o registro
desta máquina aponta para esta pasta e **se recusam a rodar** caso contrário — evita um `uninstall` seguido de
um `install` que falharia por o marketplace não resolver.

## Ciclo de manutenção

O plugin instalado roda de uma **cópia em cache** (`~/.claude/plugins/cache/personal/<plugin>/<versão>/`),
não desta pasta. Editar aqui não muda nada até reinstalar:

```bash
make reinstall PLUGIN=english-coach  # uninstall + install → recopia para o cache
# e reinicie o Claude Code (ou /reload-plugins) para recarregar hooks e comandos
```

Para iterar sem instalar: `make dev PLUGIN=english-coach` abre uma sessão com
`claude --plugin-dir ./english-coach` (o plugin vale só naquela sessão).

Checagens:

```bash
make check             # conteúdo: jq nos JSONs, plugin listado no marketplace, hooks com +x e bash -n — sem o CLI
make check-registered  # estado desta máquina: o registro do marketplace aponta para esta pasta? — sem o CLI
make validate          # claude plugin validate (marketplace e cada plugin)
make list              # plugins deste marketplace
```

## Adicionar um plugin

1. Crie a pasta aqui com `.claude-plugin/plugin.json` (`name`, `version`, `description`, `author`) —
   ou `claude plugin init <nome>` para o esqueleto.
2. Conteúdo conforme o caso: `commands/*.md`, `hooks/hooks.json` + scripts (`chmod +x`), `skills/`,
   `agents/`. Dentro do plugin, referencie arquivos via `${CLAUDE_PLUGIN_ROOT}`.
3. Acrescente a entrada em `.claude-plugin/marketplace.json` (`"source": "./<nome>"`).
4. `make check`, depois `make install PLUGIN=<nome>` e reinicie o Claude Code.
5. README dentro do plugin e uma linha na tabela acima. O `enabledPlugins` do template
   se atualiza sozinho no próximo `./backup.sh`.

> Se esta pasta mudar de lugar: `make register` (substitui o registro) e depois `make reinstall PLUGIN=<nome>`
> para cada plugin, que recarrega o cache a partir do novo caminho. **Não** use `claude plugin marketplace remove`
> como migração: remover um marketplace desinstala os plugins instalados a partir dele. O caminho registrado fica
> em `~/.claude/plugins/known_marketplaces.json` e em `extraKnownMarketplaces.personal` do `~/.claude/settings.json`
> (o template do repo guarda um placeholder; rode `./backup.sh` depois de re-registrar).
