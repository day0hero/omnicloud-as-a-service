.PHONY: default
default: help

.PHONY: help
# No need to add a comment here as help is described in common/
help:
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^(\s|[a-zA-Z_0-9-])+:.*?##/ { printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: install
install: ## multicluster provisioning (uses vars.yml and group_vars)
	@if [ -z "$(PROVIDER)" ]; then \
		echo "Usage: make install PROVIDER=aws"; \
		echo "  PROVIDER can be: aws, azure, gcp, baremetal"; \
		echo "  Running with default (all groups)..."; \
		ansible-playbook site.yaml -i inventory.yml -e "@vars.yml" -e create=true; \
	else \
		ansible-playbook site.yaml -i inventory.yml -e "@vars.yml" -e create=true --limit $(PROVIDER); \
	fi

.PHONY: destroy
destroy: ## Destroys clusters (uses vars.yml and group_vars)
	@if [ -z "$(PROVIDER)" ]; then \
		echo "Usage: make destroy PROVIDER=aws"; \
		echo "  PROVIDER can be: aws, azure, gcp, baremetal"; \
		echo "  Running with default (all groups)..."; \
		ansible-playbook site.yaml -i inventory.yml -e "@vars.yml" -e destroy=true; \
	else \
		ansible-playbook site.yaml -i inventory.yml -e "@vars.yml" -e destroy=true --limit $(PROVIDER); \
	fi

.PHONY: debug
debug: ## Render templates locally (uses vars.yml and group_vars)
	@if [ -z "$(PROVIDER)" ]; then \
		echo "Usage: make debug PROVIDER=aws"; \
		echo "  PROVIDER can be: aws, azure, gcp, baremetal"; \
		echo "  Running with default (all groups)..."; \
		ansible-playbook site.yaml -i inventory.yml -e "@vars.yml" -e debug_task=true; \
	else \
		ansible-playbook site.yaml -i inventory.yml -e "@vars.yml" -e debug_task=true --limit $(PROVIDER); \
	fi

.PHONY: idm-install
idm-install: ## Provision ec2 and install IDM - idm-vars to describe server
	ansible-playbook create-idm-infra.yml

.PHONY: idm-destroy
idm-destroy: ## Deletes the ec2 and dns records for the provisioned IDM
	ansible-playbook destroy-idm-infra.yml

.PHONY: lab-create
lab-create: ## Create baremetal lab (EC2 metal + libvirt VMs + sushy-tools)
	ansible-playbook create-baremetal-lab.yml -e "@baremetal-lab-vars.yml"

.PHONY: lab-destroy
lab-destroy: ## Destroy baremetal lab (VMs, sushy-tools, and EC2 instance)
	ansible-playbook destroy-baremetal-lab.yml -e "@baremetal-lab-vars.yml"

.PHONY: lab-deploy
lab-deploy: ## Deploy OpenShift on baremetal lab (requires lab-create first)
	ansible-playbook site.yaml -i inventory.yml -e "@baremetal-lab-vars.yml" -e "@generated-baremetal-hosts.yml" -e create=true --limit baremetal
