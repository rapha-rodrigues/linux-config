# 🐧 linux-config

Setup de terminal para **Ubuntu**, versionado. Porte do meu setup de macOS, com as partes que
só existiam lá removidas em vez de emuladas.

Testado em **Ubuntu 24.04 LTS**. Deve funcionar em qualquer derivado Debian com `apt`.

```bash
git clone https://github.com/rapha-rodrigues/linux-config.git ~/projects/linux-config
cd ~/projects/linux-config
./install.sh
```

## Como o repo funciona

Convivem **dois tipos de pasta**, e a regra de trabalho muda conforme o tipo:

| Tipo | Fonte da verdade | Pastas | Como alterar |
|---|---|---|---|
| **Espelho** de configuração | a máquina (`~/…`) | `zsh/`, `nano/`, `starship/`, `yazi/`, `lazygit/`, `ccstatusline/`, `claude/` | Edite o arquivo vivo em `~` e rode `./backup.sh`, **ou** edite no repo e rode `./install.sh` |
| **Sub-projeto** (desenvolvido aqui) | o repo | `scripts/`, `claude-plugins/` | Edite no repo. Cada um tem `README.md`, `CLAUDE.md` e `Makefile` |

```
linux-config/
├── install.sh              # repo → ~  (9 passos, interativo)
├── backup.sh               # ~ → repo  (--dry-run disponível)
├── zsh/                    # .zshrc · .zprofile · .zshenv
├── nano/nanorc
├── starship/starship.toml
├── yazi/                   # theme.toml · package.toml
├── lazygit/config.yml
├── ccstatusline/settings.json
├── claude/
│   ├── settings.template.json   # gerado por allowlist; NÃO é o settings.json vivo
│   └── hooks/notify.sh          # notify-send
├── scripts/                # funções zsh, instaladas por symlink
└── claude-plugins/         # marketplace local "personal"
```

## Os dois scripts

```bash
./install.sh            # passo a passo, perguntando antes de cada coisa
./install.sh --yes      # responde sim a tudo (provisionamento)

./backup.sh             # captura as configs vivas para o repo
./backup.sh --dry-run   # mostra o que mudaria, sem escrever
```

`install.sh` nunca sobrescreve em silêncio: um arquivo que difira do repo vira
`<destino>.bak.<timestamp>` antes de ser trocado.

### Passos do install

| # | Passo | Observação |
|---|---|---|
| 1 | Pacotes do apt | `zsh git curl nano jq fzf ripgrep bat eza direnv fd-find unzip fontconfig libnotify-bin xclip` |
| 2 | Zsh como shell padrão | `chsh`, vale no próximo login |
| 3 | Oh My Zsh + `zsh-autosuggestions` e `zsh-syntax-highlighting` | |
| 4 | Configs do zsh e do nano | cria `~/.zshrc.local` vazio |
| 5 | Starship | instalador oficial |
| 6 | Nerd Font | baixa DroidSansMono das releases do nerd-fonts |
| 7 | yazi e lazygit | yazi não está no apt; o script explica as opções |
| 8 | Claude Code | hooks, ccstatusline, `settings.json` a partir do template |
| 9 | `scripts/install.sh` | symlinks das funções zsh |

## O que é pessoal fica fora

Este repo é feito para ser **público**. Três decisões vêm daí:

**`claude/settings.template.json` é gerado, não copiado.** O `backup.sh` lê o
`~/.claude/settings.json` vivo e mantém só uma **allowlist** de chaves. O que não está na lista
nunca chega ao repo: `autoMode` (que descreve repos e fronteiras de produção do trabalho),
hooks de terceiros, plugins que não sejam do marketplace local. O caminho absoluto do
marketplace vira um placeholder, resolvido pelo `install.sh` na hora de escrever.

**`~/.claude/CLAUDE.md` não é versionado aqui.** É perfil pessoal. Se quiser versionar, use um
repo privado.

**`~/.zshrc.local` é o escape.** Aliases de máquina, atalhos de SSH, IPs internos, tokens: tudo
isso vai nesse arquivo, que o `.zshrc` carrega no fim e o repo ignora.

## Diferenças em relação ao setup de macOS

| | macOS | Ubuntu |
|---|---|---|
| Gerenciador de pacotes | Homebrew | apt (+ instaladores oficiais para starship, lazygit, yazi) |
| Binário do `bat` | `bat` | `batcat` (alias no `.zshrc`) |
| Binário do `fd` | `fd` | `fdfind` (symlink criado pelo `install.sh`) |
| Clipboard | `pbcopy` | `wl-copy` no Wayland, `xclip`/`xsel` no X11, detectado em runtime |
| Notificação | `osascript` | `notify-send` (`libnotify-bin`) |
| Fontes | `~/Library/Fonts` | `~/.local/share/fonts` + `fc-cache` |
| Sintaxe do nano | `/opt/homebrew/share/nano/` | `/usr/share/nano/` |
| Tema do `bat` | seguia a aparência do sistema | fixo em `BAT_THEME`, sem equivalente universal |

### O que não veio junto

`iterm2`, `raycast`, `supacode`, `config-bkp` (BetterTouchTool, PopClip, RewriteBar) e o
window manager **OmniWM** são macOS-only. O `brew-audit`, os `cards` impressos, as configs de
**VPN** e o `ai-profile` ficaram de fora por decisão, não por incompatibilidade.

> Nota sobre o OmniWM: no repo de origem a pasta se chamava `niri/`, mas o conteúdo era config
> do OmniWM, um app macOS. O **niri** de verdade, no Linux, é um compositor Wayland com config
> em KDL (`~/.config/niri/config.kdl`) — formato sem nenhuma relação. Não há o que portar; se
> quiser niri aqui, é escrever a config do zero.

## Sub-projetos

- **[`scripts/`](scripts/)** — funções zsh (`cs`, `csg`, `csview`, `fe`, `y`, e o fluxo de git
  `gstart`/`gship`/`gdone`), instaladas por **symlink**. Editar no repo já vale na próxima shell.
  `make -C scripts test`.
- **[`claude-plugins/`](claude-plugins/)** — marketplace local `personal`. Um plugin hoje,
  `english-coach`. Plugin instalado roda do cache: depois de editar, reinstale com
  `make -C claude-plugins reinstall PLUGIN=<nome>` e reinicie o Claude Code.

## Dependências que o apt não resolve

| Ferramenta | Como instalar |
|---|---|
| **yazi** | `cargo install --locked yazi-fm yazi-cli`, `snap install yazi --classic`, ou o binário das releases |
| **lazygit** | o `install.sh` baixa o binário da última release para `~/.local/bin` |
| **starship** | instalador oficial (`curl -sS https://starship.rs/install.sh \| sh`) |
| **Claude Code** | veja `docs.claude.com/claude-code` |
| **eza** | está no apt a partir do Ubuntu 24.04; em versões antigas use o `.deb` do projeto |

## Convenções

- Documentação em português (pt-BR). Código e comentários podem misturar. Commits em inglês,
  no imperativo.
- Scripts bash: `set -euo pipefail`, helpers `info/ok/warn` coloridos, `bash -n` antes de entregar.
  Sem `rm -rf` fora de alvos `clean`.
- Ao adicionar um componente, atualize **os dois scripts**, a tabela e a árvore deste README.
