# scripts/ — alvos de manutenção do sub-projeto. `make` (ou `make help`) lista.
SHELL := /bin/bash
.DEFAULT_GOAL := help
.PHONY: help install check dry-run lint test

help: ## lista os alvos
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN { FS = ":.*## " } { printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 }'

install: ## cria/atualiza os symlinks em ~/.local/bin e ~/ (idempotente)
	@./install.sh

dry-run: ## mostra o que install faria, sem tocar em nada
	@./install.sh --dry-run

check: ## estado de cada symlink (é o que o backup.sh roda); exit 1 se algo estiver fora
	@./install.sh --check

lint: ## sintaxe: bash -n nos scripts bash, zsh -n nas funções
	@for f in install.sh bin/*; do \
	  [ -e "$$f" ] || continue; \
	  if head -1 "$$f" | grep -q bash; then bash -n "$$f" && echo "ok  $$f"; \
	  elif head -1 "$$f" | grep -q zsh; then zsh -n "$$f" && echo "ok  $$f"; \
	  else echo "--  $$f (shebang não é bash/zsh; sem lint)"; fi; \
	done
	@for f in functions/*.zsh; do zsh -n "$$f" && echo "ok  $$f"; done

test: lint ## carrega as funções numa zsh limpa e confere --help dos executáveis
	@zsh -f -c 'for f in functions/*.zsh; do source "$$f"; done; \
	  for fn in gstart gship gdone gstartd gshipd gdoned greleased cs csg csview fe y; do \
	    whence -w "$$fn" >/dev/null || { echo "FALTOU  $$fn"; exit 1; }; \
	  done; echo "ok  funções zsh carregam (gstart… greleased, cs, csg, csview, fe, y)"'
	@for f in bin/*; do [ -e "$$f" ] || continue; "$$f" --help >/dev/null && echo "ok  $$f --help"; done
