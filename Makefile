## help: print each command's help message
.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

## ansible/requirements: installs the requirements for the ansible playbook, requires ansible
.PHONY: ansible/requirements
ansible/requirements:
	ansible-galaxy install -r ./ansible/collections/requirements.yml

## ansible/site: creates/adds a new node to a k3s cluster, requires ansible and kubectl
.PHONY: ansible/site
ansible/site:
	ansible-playbook k3s.orchestration.site -K

## ansible/cluster-setup: creates/adds a new node to a k3s cluster, updates it, and sets the tls/monitoring stack
.PHONY: ansible/setup
ansible/setup:
	$(MAKE) ansible/requirements
	$(MAKE) ansible/site

## ansible/ping: util to ping the full cluster
.PHONY: ansible/ping
ansible/ping:
	ansible k3s_cluster -m ping
