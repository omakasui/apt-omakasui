SHELL := /bin/bash
.DEFAULT_GOAL := help

PKG ?=
VERSION ?=
PRODUCT ?=
SUITE ?=
PRODUCES ?=
GPG_KEY_URL ?= https://github.com/omakasui/keyrings/raw/refs/heads/main/omakasui-core.gpg.key
GPG_KEY_ID ?=
SCRIPTS := scripts

_require_pkg = $(if $(PKG),,$(error PKG is required))
_require_version = $(if $(VERSION),,$(error VERSION is required))
_require_target = $(if $(and $(PRODUCT),$(SUITE)),,$(error PRODUCT and SUITE are required))

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

.PHONY: register register-dev
register register-dev: ## Register a release (PKG= VERSION= PRODUCT= SUITE= required)
	$(call _require_pkg)
	$(call _require_version)
	$(call _require_target)
	@bash $(SCRIPTS)/register-package.sh --pkg "$(PKG)" --version "$(VERSION)" \
		--product "$(PRODUCT)" --suite "$(SUITE)" --produces "$(PRODUCES)" \
		$(if $(filter register-dev,$@),--channel dev)

.PHONY: promote promote-pkg
promote promote-pkg: ## Promote dev entries
	$(if $(filter promote-pkg,$@),$(call _require_target))
	$(if $(filter promote-pkg,$@),$(call _require_pkg))
	@bash $(SCRIPTS)/promote-packages.sh --product "$(PRODUCT)" --suite "$(SUITE)" \
		$(if $(filter promote,$@),--all,--pkg "$(PKG)") $(if $(VERSION),--version "$(VERSION)")

.PHONY: remove
remove: ## Remove PKG from PRODUCT/SUITE
	$(call _require_pkg)
	$(call _require_target)
	@bash $(SCRIPTS)/remove-entries.sh --package "$(PKG)" --product "$(PRODUCT)" --suite "$(SUITE)"

.PHONY: freeze unfreeze
freeze unfreeze: ## Freeze/unfreeze PKG in PRODUCT/SUITE
	$(call _require_pkg)
	$(call _require_target)
	@touch index/freeze.list
	@if [[ "$@" == freeze ]]; then \
		entry="$(PRODUCT) $(SUITE) $(PKG)"; grep -qxF "$$entry" index/freeze.list || echo "$$entry" >> index/freeze.list; \
		sort -o index/freeze.list index/freeze.list; \
	else sed -i '/^$(PRODUCT) $(SUITE) $(PKG)$$/d' index/freeze.list; fi

.PHONY: prune-dry prune
prune-dry: ## Preview stale releases
	@bash $(SCRIPTS)/prune-releases.sh
prune: ## Delete stale releases
	@bash $(SCRIPTS)/prune-releases.sh --delete

.PHONY: list list-dev info
list: ## List all indexed packages
	@awk '{print $$4,$$5,$$1"/"$$2,$$3,$$12}' index/packages.tsv | sort -u | column -t || true
list-dev: ## List dev entries
	@awk '$$12=="dev"{print $$4,$$5,$$1"/"$$2,$$3}' index/packages.tsv | sort -u | column -t || true
info: ## Show PKG entries
	$(call _require_pkg)
	@awk '$$4=="$(PKG)"{printf "target=%-22s arch=%-6s ver=%-12s channel=%s\n",$$1"/"$$2,$$3,$$5,$$12}' index/packages.tsv

.PHONY: validate
validate: ## Validate targets and manifest integrity
	@bash $(SCRIPTS)/validate.sh

.PHONY: check
check: ## Count generated entries per target and architecture
	@while read -r product suite _label status; do [[ "$$status" == active ]] || continue; \
		for published_suite in "$$suite" "$$suite-dev"; do for arch in amd64 arm64; do \
			f="$$product/dists/$$published_suite/main/binary-$$arch/Packages"; \
			[[ -f "$$f" ]] && printf '  %-24s %-6s %s entries\n' "$$product/$$published_suite" "$$arch" "$$(grep -c '^Package:' "$$f")"; \
		done; done; done < index/targets.tsv; true
