SHELL := /bin/bash

# Make file config
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
CYAN   := $(shell tput -Txterm setaf 6)
RESET  := $(shell tput -Txterm sgr0)

# Version requirements
KUSTOMIZE_VERSION 	?= "5.5.0"
OPM_VERSION 		?= "1.53.0"
YQ_VERSION 			?= "4.44.3"

# Default files and directories
TMP		?= "temp" # Blank value will create temp directory using 'mktemp'.
DIR		?= "" # Blank value will use 'catalog.directory' from config.
OCP		?= "" # Blank value will generate catalog for all OCP version in config.
CONFIG	?= "config.yaml" # Specifying Config file is mandatory.
BIN		?= "bin" # Default path for installing binaries.
BUNDLE	?= "" # Specify a single bundle. Overrides config file.
REBUILD	?= "false" # Set true to build catalog from scratch.

# Being binaries, they're OS and Arch specific
OS 		?= $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH 	?= $(shell uname -m | sed 's/x86_64/amd64/')


.PHONY: help
help: ## Show this help.
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} { \
		if (/^[a-zA-Z_-]+:.*?##.*$$/) {printf "    ${YELLOW}%-20s${GREEN}%s${RESET}\n", $$1, $$2} \
		else if (/^## .*$$/) {printf "  ${CYAN}%s${RESET}\n", substr($$1,4)} \
		}' $(MAKEFILE_LIST)

.PHONY: install
install: ## Install binaries
	@bash ./scripts/install.sh -p $(BIN) kustomize=$(KUSTOMIZE_VERSION) yq=$(YQ_VERSION) opm=$(OPM_VERSION)

.PHONY: generate
generate: ## Generate catalog manifests
	@bash ./scripts/generate.sh -v $(OCP) -p $(DIR) -t $(TMP) -b $(BUNDLE) -r $(REBUILD) $(CONFIG)

#.PHONY: build
#build: ## Build catalog image
#	#TODO: Implement builds automation
#
#.PHONY: push
#push: ## Push catalog to repository
#	#TODO: Implement builds automation
#
#.PHONY: test
#test: ## Test catalog in cluster
#	#TODO: Implement test automation
