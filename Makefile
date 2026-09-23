SHELL := /bin/bash
.DEFAULT_GOAL := help

PKG ?=
GPG_KEY_URL ?= https://github.com/omakasui/keyrings/raw/refs/heads/main/omakasui-core.gpg.key
GPG_KEY_ID ?=
SCRIPTS := scripts

_require_pkg = $(if $(PKG),,$(error PKG is required))

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*##"}{printf "  \033[36m%-18s\033[0m %s\n",$$1,$$2}'

.PHONY: index
index: ## Regenerate all active product indexes
	@bash $(SCRIPTS)/update-index.sh

.PHONY: sign
sign: ## Sign all active product indexes
	@bash $(SCRIPTS)/sign-release.sh $(if $(GPG_KEY_ID),--key-id "$(GPG_KEY_ID)",--key-url "$(GPG_KEY_URL)")

.PHONY: rebuild
rebuild: index sign ## Regenerate and sign all active metadata

.PHONY: readme
readme: ## Sync the README package table
	@bash $(SCRIPTS)/update-readme.sh

.PHONY: prune-dry
prune-dry: ## Preview stale releases
	@bash $(SCRIPTS)/prune-releases.sh

.PHONY: list list-dev info
list: ## List all indexed packages
	@awk '{print $$4,$$5,$$1"/"$$2,$$3,$$12}' index/packages.tsv | sort -u | column -t || true
list-dev: ## List dev entries
	@awk '$$12=="dev"{print $$4,$$5,$$1"/"$$2,$$3}' index/packages.tsv | sort -u | column -t || true
info: ## Show PKG entries
	$(call _require_pkg)
	@awk '$$4=="$(PKG)"{printf "target=%-22s arch=%-6s ver=%-12s channel=%s\n",$$1"/"$$2,$$3,$$5,$$12}' index/packages.tsv

.PHONY: validate test check
validate: ## Validate targets and manifest integrity
	@bash $(SCRIPTS)/validate.sh

test: ## Test index generation and target isolation
	@bash $(SCRIPTS)/test.sh

check: validate test ## Run all local checks

.PHONY: status
status: ## Count generated entries per target and architecture
	@while read -r product suite _label status; do [[ "$$status" == active ]] || continue; \
		for published_suite in "$$suite" "$$suite-dev"; do for arch in amd64 arm64; do \
			f="$$product/dists/$$published_suite/main/binary-$$arch/Packages"; \
			[[ -f "$$f" ]] && printf '  %-24s %-6s %s entries\n' "$$product/$$published_suite" "$$arch" "$$(grep -c '^Package:' "$$f")"; \
		done; done; done < index/targets.tsv; true
