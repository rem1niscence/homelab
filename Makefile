## help: print each command's help message
.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

## ansible/requirements: installs the requirements for the ansible playbook, requires ansible
.PHONY: ansible/requirements
ansible/requirements:
	ansible-galaxy install -r ./ansible/collections/requirements.yml
	ansible-galaxy install -r ./ansible/collections/roles.yml

## ansible/site: creates/adds a new node to a k3s cluster, requires ansible and kubectl
.PHONY: ansible/site
ansible/site:
	ansible-playbook k3s.orchestration.site

## ansible/cluster-setup: creates/adds a new node to a k3s cluster, updates it, and sets the tls/monitoring stack
.PHONY: ansible/setup
ansible/setup:
	$(MAKE) ansible/requirements
	$(MAKE) ansible/site

## ansible/ping: util to ping the full cluster
.PHONY: ansible/ping
ansible/ping:
	ansible k3s_cluster -m ping

## ansible/teardown: removes the cluster and all nodes, requires ansible
.PHONY: ansible/teardown
ansible/teardown:
	ansible-playbook k3s.orchestration.reset

## ansible/node-setup: installs docker and tailscale to the node
.PHONY: ansible/server-setup
ansible/server-setup:
	ansible-playbook ansible/playbooks/scripts/install-docker.yml
	ansible-playbook ansible/playbooks/scripts/tailscale-container.yml \
	  -e @./ansible/secrets.yml

## util/brew-install-requirements: installs kubectl, ansible, cilium, and helm with brew
.PHONY: util/brew-install-requirements
util/brew-install-requirements:
	@command -v brew >/dev/null 2>&1 || { echo "Homebrew not found. Install from https://brew.sh and re-run."; exit 1; }
	@brew list kubernetes-cli >/dev/null 2>&1 || brew install kubernetes-cli
	@brew list helm >/dev/null 2>&1 || brew install helm
	@brew list ansible >/dev/null 2>&1 || brew install ansible
	@brew list cilium-cli >/dev/null 2>&1 || brew install cilium-cli
	@echo "kubectl: $$(kubectl version --client 2>/dev/null | grep 'Client Version' | awk '{print $$3}' || echo not installed)"
	@echo "helm:    $$(helm version --short 2>/dev/null || echo not installed)"
	@echo "ansible: $$(ansible --version 2>/dev/null | head -n1 | grep -o '\[core [^]]*\]' || echo not installed)"
	@echo "cilium:  $$(cilium version --client 2>/dev/null | grep 'cilium image (stable):' | awk '{print $$4}' || echo not installed)"

## cilium/cluster-install: installs cilium to the cluster
# Due to raspberry pi's lack of support of tcmalloc 1GB aligned chunk as described in
# https://github.com/envoyproxy/envoy/issues/23339, the installation wont support the envoy/L7 proxy
# features.
.PHONY: cilium/cluster-install
cilium/cluster-install:
	cilium install \
	  --set ipam.operator.clusterPoolIPv4PodCIDRList="10.42.0.0/16" \
	  --set ingressController.enabled=false \
	  --set l7Proxy=false \
	  --set hubble.relay.enabled=false \
	  --set hubble.ui.enabled=false

## k3s/k-token: creates an access token for the kubernetes-dashboard
.PHONY: k3s/k-token
k3s/k-token:
	@k3s kubectl -n kubernetes-dashboard create token admin-user --duration=1000h
	kubectl -n kubernetes-dashboard create token admin-user --duration=1000h

## app: installs an application to the cluster
.PHONY: k3s/app
k3s/app:
	$(call check_vars, AP DOMAIN)
	./cluster/scripts/setup_application.sh $${AP} $${DOMAIN}

.PHONY: tailscale/expose
tailscale/expose:
	$(call check_vars NAMESPACE SERVICE HOSTNAME)
	@kubectl annotate service -n $(NAMESPACE) $(SERVICE) tailscale.com/hostname="$(HOSTNAME)"
	@kubectl annotate service -n $(NAMESPACE) $(SERVICE) tailscale.com/expose="true"

.PHONY: tailscale/unexpose
tailscale/unexpose:
	$(call check_vars NAMESPACE SERVICE)
	@kubectl annotate service -n $(NAMESPACE) $(SERVICE) tailscale.com/hostname-
	@kubectl annotate service -n $(NAMESPACE) $(SERVICE) tailscale.com/expose-
