# make init | workspace ENV=dev | plan ENV=dev | apply ENV=dev
INFRA_DIR := infrastructure
ENV ?= dev
TFVARS := $(ENV).tfvars
BACKEND_CONFIG ?= $(INFRA_DIR)/backend.hcl
PLAN_FILE ?= tfplan-$(ENV)

.PHONY: help fmt validate init workspace plan apply destroy clean

help:
	@echo "Targets (Terraform under $(INFRA_DIR)/, workspaces + per-env tfvars):"
	@echo "  make fmt                    Format all Terraform files"
	@echo "  make init                   terraform init (uses backend.hcl if present)"
	@echo "  make workspace ENV=dev      create/select workspace"
	@echo "  make validate ENV=dev       validate with ENV.tfvars"
	@echo "  make plan ENV=dev           plan -> $(INFRA_DIR)/tfplan-ENV"
	@echo "  make apply ENV=dev          apply saved plan (review first)"
	@echo "  make destroy ENV=dev        destroy (interactive confirmation)"
	@echo "  make clean                  remove local .terraform and plan files"

fmt:
	cd $(INFRA_DIR) && terraform fmt -recursive

init:
	@if [ -f "$(BACKEND_CONFIG)" ]; then \
		cd $(INFRA_DIR) && terraform init -backend-config=backend.hcl; \
	else \
		echo "No $(BACKEND_CONFIG) found — initializing without remote backend config."; \
		echo "Copy $(INFRA_DIR)/backend.hcl.example to $(INFRA_DIR)/backend.hcl and re-run make init"; \
		cd $(INFRA_DIR) && terraform init -backend=false; \
	fi

workspace: init
	@if [ ! -f "$(INFRA_DIR)/$(TFVARS)" ]; then echo "Missing $(INFRA_DIR)/$(TFVARS)"; exit 1; fi
	@cd $(INFRA_DIR) && (terraform workspace select $(ENV) 2>/dev/null || terraform workspace new $(ENV))
	@cd $(INFRA_DIR) && echo "Active workspace: $$(terraform workspace show)"

validate: workspace
	cd $(INFRA_DIR) && terraform validate

plan: workspace
	cd $(INFRA_DIR) && terraform plan -var-file=$(TFVARS) -out=$(PLAN_FILE)
	@echo "Review $(INFRA_DIR)/$(PLAN_FILE) before apply."

apply:
	@if [ ! -f "$(INFRA_DIR)/$(PLAN_FILE)" ]; then echo "Missing $(INFRA_DIR)/$(PLAN_FILE) — run make plan ENV=$(ENV) first"; exit 1; fi
	cd $(INFRA_DIR) && terraform workspace select $(ENV) && terraform apply $(PLAN_FILE)

destroy: workspace
	@echo "WARNING: destroy will remove all resources in workspace=$(ENV)"
	cd $(INFRA_DIR) && terraform destroy -var-file=$(TFVARS)

clean:
	rm -rf $(INFRA_DIR)/.terraform $(INFRA_DIR)/tfplan-*
