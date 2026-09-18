# scripts/ — notas para o Claude Code

- Fonte da verdade é esta pasta. Os arquivos em `~` (`~/.git_functions.zsh`, `~/.claude_functions.zsh`, `~/.fzf_functions.zsh`, `~/.yazi_functions.zsh`) são **symlinks** para cá; nunca edite lá nem copie de volta.
- Depois de editar: `make test` (sintaxe + carga das funções numa `zsh -f`). Para testar uma função interativa sem executar de verdade, sobrescreva os comandos externos num subshell: `zsh -f -c 'source functions/claude_functions.zsh; fzf() { head -1 }; claude() { print "DRY $*" }; cs'`. Lembre que o `fzf` dentro de `$(...)` roda em subshell: contadores de mock precisam ir para um arquivo.
- `bin/` está vazio: executáveis novos entram ali e o `install.sh` os linka sozinho em `~/.local/bin`.
- No Ubuntu `bat` é `batcat` e `fd` é `fdfind`. `cat` é alias de `batcat` na shell do usuário: nos testes use `/bin/cat`.
- Clipboard não é `pbcopy`: use a detecção `wl-copy` → `xclip` → `xsel` que já está em `functions/fzf_functions.zsh`.
- Script novo em `bin/` → `make install` (symlink) e linha na tabela do `README.md`. Função nova → o `source` fica no `zsh/.zshrc` (espelho) **e** no `~/.zshrc` vivo, e o nome entra na lista do alvo `test` do `Makefile`.
- Não use `rm` para trocar cópia por link: `ln -sfn` já substitui; arquivos divergentes vão para `.bak.<ts>` com `mv`.
