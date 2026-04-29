SHELL   := /bin/bash
.DEFAULT_GOAL := help

PKG      ?=
VERSION  ?=
SUITES   ?= noble trixie
ALL_SUITES     := noble trixie
ALL_DEV_SUITES := noble-dev trixie-dev
SCRIPTS  := scripts

_require_pkg     = $(if $(PKG),,$(error PKG is required. Example: make $@ PKG=fzf))
_require_version = $(if $(VERSION),,$(error VERSION is required. Example: make $@ PKG=fzf VERSION=0.60.3))

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*##"}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

.PHONY: index
index: ## Regenerate Packages files from packages.tsv
	@bash $(SCRIPTS)/update-index.sh --suites "$(ALL_SUITES)"

.PHONY: sign
sign: ## Re-sign Release files for all suites (GPG_KEY_ID= required)
	$(if $(GPG_KEY_ID),,$(error GPG_KEY_ID is required. Example: make $@ GPG_KEY_ID=<fingerprint>))
	@bash $(SCRIPTS)/sign-release.sh \
		--suites "$(ALL_SUITES) $(ALL_DEV_SUITES)" \
		--key-id "$(GPG_KEY_ID)"

.PHONY: rebuild
rebuild: index sign ## Regenerate and sign all metadata (GPG_KEY_ID= required)

.PHONY: register
register: ## Register a package in stable (PKG= VERSION= SUITES= required)
	$(call _require_pkg)
	$(call _require_version)
	@bash $(SCRIPTS)/register-package.sh \
		--pkg     "$(PKG)" \
		--version "$(VERSION)" \
		--suites  "$(SUITES)"

.PHONY: register-dev
register-dev: ## Register a package in the dev channel (PKG= VERSION= SUITES= required)
	$(call _require_pkg)
	$(call _require_version)
	@bash $(SCRIPTS)/register-package.sh \
		--pkg     "$(PKG)" \
		--version "$(VERSION)" \
		--suites  "$(SUITES)" \
		--channel dev

.PHONY: promote
promote: ## Promote all dev entries to stable (SUITES= optional)
	@bash $(SCRIPTS)/promote-packages.sh --all --suites "$(SUITES)"

.PHONY: promote-pkg
promote-pkg: ## Promote a single package dev → stable (PKG= required, VERSION= optional)
	$(call _require_pkg)
	@bash $(SCRIPTS)/promote-packages.sh \
		--pkg    "$(PKG)" \
		--suites "$(SUITES)" \
		$(if $(VERSION),--version "$(VERSION)")

.PHONY: remove
remove: ## Remove a package from the index (PKG= required, SUITES= optional)
	$(call _require_pkg)
	@bash $(SCRIPTS)/remove-entries.sh \
		--package "$(PKG)" \
		$(if $(filter-out noble trixie,$(SUITES)),--suites "$(SUITES)")

.PHONY: prune-dry
prune-dry: ## Show stale releases in build-apt-omakasui (dry-run)
	@bash $(SCRIPTS)/prune-releases.sh

.PHONY: prune
prune: ## Delete stale releases in build-apt-omakasui
	@bash $(SCRIPTS)/prune-releases.sh --delete

.PHONY: list
list: ## List all packages and versions from packages.tsv
	@awk '{print $$3, $$4, $$1, $$2}' index/packages.tsv \
		| sort -u \
		| column -t || true

.PHONY: list-dev
list-dev: ## List packages not yet promoted to stable
	@awk '(NF>=11 && $$11=="dev") {print $$3, $$4, $$1, $$2}' index/packages.tsv \
		| sort -u \
		| column -t

.PHONY: preview-promote
preview-promote: ## Preview what next promote-all will add vs update in stable
	@added=$$(awk -v suites="$(SUITES)" \
	  'BEGIN{n=split(suites,sa," ");for(i=1;i<=n;i++)ss[sa[i]]=1} \
	   {ch=(NF>=11)?$$11:"stable";if(!ss[$$1])next; \
	    if(ch=="dev")d[$$3]=$$4;if(ch=="stable")s[$$3]=$$4} \
	   END{for(p in d)if(!(p in s))print p,d[p]}' \
	  index/packages.tsv | sort); \
	updated=$$(awk -v suites="$(SUITES)" \
	  'BEGIN{n=split(suites,sa," ");for(i=1;i<=n;i++)ss[sa[i]]=1} \
	   {ch=(NF>=11)?$$11:"stable";if(!ss[$$1])next; \
	    if(ch=="dev")d[$$3]=$$4;if(ch=="stable")s[$$3]=$$4} \
	   END{for(p in d)if(p in s&&s[p]!=d[p])print p,s[p],d[p]}' \
	  index/packages.tsv | sort); \
	printf '\033[1;33mTo be added:\033[0m\n'; \
	if [[ -n "$$added" ]]; then printf '%s\n' "$$added" | awk '{printf "  %-26s %s\n",$$1,$$2}'; else echo '  (none)'; fi; \
	printf '\n\033[1;36mTo be updated:\033[0m\n'; \
	if [[ -n "$$updated" ]]; then printf '%s\n' "$$updated" | awk '{printf "  %-26s %s -> %s\n",$$1,$$2,$$3}'; else echo '  (none)'; fi

.PHONY: info
info: ## Show index entries for a package (PKG= required)
	$(call _require_pkg)
	@awk '$$3 == "$(PKG)"' index/packages.tsv \
		| awk '{printf "suite=%-12s arch=%-6s ver=%-12s channel=%s\n", $$1, $$2, $$4, (NF>=11?$$11:"stable")}'

.PHONY: check
check: ## Count entries per suite/arch in the Packages files
	@for suite in $(ALL_SUITES) $(ALL_DEV_SUITES); do \
		for arch in amd64 arm64; do \
			f="dists/$${suite}/main/binary-$${arch}/Packages"; \
			[[ -f "$$f" ]] && printf "  %-18s %-6s %s entries\n" "$$suite" "$$arch" "$$(grep -c '^Package:' "$$f")"; \
		done; \
	done
