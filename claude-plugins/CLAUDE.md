# claude-plugins/ — notas para o Claude Code

- Esta pasta é a raiz do marketplace `personal`; um plugin por subpasta irmã. Nunca crie um plugin dentro de outro.
- `Bash(claude *)` é negado nas permissões do usuário: **não tente** `claude plugin ...`. Edite, rode `make check`, e entregue ao usuário os comandos para ele rodar no prompt com `! ` (`make -C claude-plugins reinstall PLUGIN=<nome>` + reiniciar o Claude Code).
- O plugin instalado roda do cache (`~/.claude/plugins/cache/personal/...`), não daqui: editar hook/comando não tem efeito até reinstalar. Diga isso explicitamente ao entregar.
- Hooks: caminho `${CLAUDE_PLUGIN_ROOT}/hooks/<script>`, `chmod +x`, e `exit 0` sempre em hooks que não devem bloquear. `hooks.json` e `plugin.json` precisam passar em `jq -e .`.
- Plugin novo = pasta + `plugin.json` + entrada em `.claude-plugin/marketplace.json` + linha na tabela do `README.md`.
- `install`/`reinstall` só rodam se `make check-registered` confirmar que o registro desta máquina (`~/.claude/plugins/known_marketplaces.json`) aponta para esta pasta; `make register` substitui um registro antigo (o `add` com o mesmo nome substitui). Nunca sugira `claude plugin marketplace remove` como migração: ele desinstala os plugins daquele marketplace.
- Se esta pasta mudar de caminho, atualize também o `path` em `claude/settings.template.json` (placeholder `REPLACE_WITH_ABSOLUTE_PATH`, resolvido pelo `install.sh` da raiz).
