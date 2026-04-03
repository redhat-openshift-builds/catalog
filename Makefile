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
TMP     ?= temp
DIR     ?=
OCP     ?=
CONFIG  ?= config.yaml
BIN     ?= bin
BUNDLE  ?=
REBUILD ?= false

# Image configuration
REGISTRY   ?= localhost
VERSION    ?=
IMAGE_NAME  = $(REGISTRY)/openshift-builds-catalog:$(VERSION)-$(OCP)

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
	@bash ./scripts/generate.sh \
		$(if $(OCP),-v $(OCP)) \
		$(if $(DIR),-p $(DIR)) \
		$(if $(TMP),-t $(TMP)) \
		$(if $(BUNDLE),-b $(BUNDLE)) \
		-r $(REBUILD) \
		$(CONFIG)

.PHONY: build
build: ## Build catalog image (requires OCP and VERSION)
	@if [ -z "$(OCP)" ]; then echo "Error: OCP version is required. Usage: make build OCP=4.18 VERSION=1.7"; exit 1; fi
	@if [ -z "$(VERSION)" ]; then echo "Error: VERSION is required. Usage: make build OCP=4.18 VERSION=1.7"; exit 1; fi
	@echo "Building image: $(IMAGE_NAME)"
	podman build \
		--tag "$(IMAGE_NAME)" \
		--file "fbc/$(OCP)/Dockerfile" \
		"fbc/$(OCP)"

.PHONY: push
push: build ## Push catalog image to registry (requires OCP and VERSION)
	@if [ -z "$(OCP)" ]; then echo "Error: OCP version is required. Usage: make push OCP=4.18 VERSION=1.7"; exit 1; fi
	@if [ -z "$(VERSION)" ]; then echo "Error: VERSION is required. Usage: make push OCP=4.18 VERSION=1.7"; exit 1; fi
	@echo "Pushing image: $(IMAGE_NAME)"
	podman push "$(IMAGE_NAME)"

#.PHONY: test
#test: ## Test catalog in cluster
#	#TODO: Implement test automation
