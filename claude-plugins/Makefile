# claude-plugins/ — marketplace local "personal". `make` (ou `make help`) lista os alvos.
# Os alvos register/install/reinstall/validate/dev usam o CLI do Claude Code (claude).
SHELL := /bin/bash
.DEFAULT_GOAL := help
MARKETPLACE := personal
ROOT := $(abspath .)
PLUGINS := $(patsubst %/.claude-plugin/plugin.json,%,$(wildcard */.claude-plugin/plugin.json))
# Caminho que o Claude Code tem registrado para este marketplace nesta máquina (vazio = não registrado).
# Lido direto do arquivo de estado, sem o CLI, para as guardas funcionarem em qualquer contexto.
KNOWN := $(HOME)/.claude/plugins/known_marketplaces.json
REGISTERED := $(shell jq -r '.["$(MARKETPLACE)"].source.path // empty' "$(KNOWN)" 2>/dev/null)
.PHONY: help list register check-registered install reinstall dev validate check

help: ## lista os alvos
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN { FS = ":.*## " } { printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2 }'

list: ## plugins deste marketplace (pasta + descrição do plugin.json)
	@for p in $(PLUGINS); do printf "  %-18s %s\n" "$$p" "$$(jq -r .description $$p/.claude-plugin/plugin.json)"; done

register: ## registra esta pasta como marketplace "personal"; registro antigo em outro caminho é substituído (plugins instalados são mantidos)
	@if [ "$(REGISTERED)" = "$(ROOT)" ]; then \
	  echo "ok  marketplace '$(MARKETPLACE)' já registrado → $(ROOT)"; \
	else \
	  if [ -n "$(REGISTERED)" ]; then \
	    echo "registro atual aponta para $(REGISTERED) — substituindo (add com o mesmo nome substitui; nada é desinstalado)"; \
	  fi; \
	  claude plugin marketplace add "$(ROOT)" && \
	  echo "plugins já instalados seguem rodando do cache antigo — recarregue com: make reinstall PLUGIN=<nome>"; \
	fi

check-registered: ## confere se o registro do marketplace nesta máquina aponta para esta pasta (sem o CLI)
	@if [ -z "$(REGISTERED)" ]; then \
	  echo "ERRO  marketplace '$(MARKETPLACE)' não registrado nesta máquina — rode: make register"; exit 1; \
	elif [ "$(REGISTERED)" != "$(ROOT)" ]; then \
	  echo "ERRO  marketplace '$(MARKETPLACE)' registrado em $(REGISTERED), não nesta pasta — rode: make register"; exit 1; \
	else \
	  echo "ok  marketplace '$(MARKETPLACE)' → $(ROOT)"; \
	fi

install: check-registered ## instala um plugin: make install PLUGIN=english-coach
	@test -n "$(PLUGIN)" || { echo "uso: make install PLUGIN=<nome>"; exit 2; }
	claude plugin install $(PLUGIN)@$(MARKETPLACE)

reinstall: check-registered ## recarrega um plugin editado (uninstall + install): make reinstall PLUGIN=english-coach
	@test -n "$(PLUGIN)" || { echo "uso: make reinstall PLUGIN=<nome>"; exit 2; }
	-claude plugin uninstall $(PLUGIN)@$(MARKETPLACE)
	claude plugin install $(PLUGIN)@$(MARKETPLACE)
	@echo "reinicie o Claude Code (ou /reload-plugins) para recarregar hooks e comandos"

dev: ## sessão do Claude Code com o plugin direto da pasta, sem instalar: make dev PLUGIN=english-coach
	@test -n "$(PLUGIN)" || { echo "uso: make dev PLUGIN=<nome>"; exit 2; }
	claude --plugin-dir $(ROOT)/$(PLUGIN)

validate: ## claude plugin validate no marketplace e em cada plugin
	claude plugin validate $(ROOT)
	@for p in $(PLUGINS); do claude plugin validate $(ROOT)/$$p; done

check: ## checagens do conteúdo, sem o CLI: JSONs válidos, cada plugin listado no marketplace, hooks com +x
	@jq -e . .claude-plugin/marketplace.json >/dev/null && echo "ok  .claude-plugin/marketplace.json"
	@for p in $(PLUGINS); do \
	  jq -e . "$$p/.claude-plugin/plugin.json" >/dev/null && echo "ok  $$p/.claude-plugin/plugin.json"; \
	  jq -e --arg p "./$$p" 'any(.plugins[]; .source == $$p)' .claude-plugin/marketplace.json >/dev/null \
	    && echo "ok  $$p listado em marketplace.json" \
	    || { echo "ERRO  $$p não está em .claude-plugin/marketplace.json"; exit 1; }; \
	  if [ -f "$$p/hooks/hooks.json" ]; then jq -e . "$$p/hooks/hooks.json" >/dev/null && echo "ok  $$p/hooks/hooks.json"; fi; \
	  for h in "$$p"/hooks/*.sh; do \
	    [ -e "$$h" ] || continue; \
	    if [ -x "$$h" ]; then bash -n "$$h" && echo "ok  $$h (+x, bash -n)"; else echo "ERRO  $$h sem +x"; exit 1; fi; \
	  done; \
	done
