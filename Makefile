define check_vars
	$(foreach var,$1,$(if $(value $(var)),,$(error ERROR: $(var) is not set)))
endef

## help: print each command's help message
.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

.PHONY: ansible/inventory
ansible/inventory:
	ansible-inventory  --graph --vars

## ansible/requirements: installs the requirements for the ansible playbook, requires ansible
.PHONY: ansible/requirements
ansible/requirements:
	ansible-galaxy collection install -r ./ansible/requirements.yml
	ansible-galaxy role install -r ./ansible/requirements.yml -p ./ansible/vendor/roles

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
	ansible all -m ping

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
		--set MTU=1450

## k3s/k-token: creates an access token for the kubernetes-dashboard
.PHONY: k3s/k-token
k3s/k-token:
	@k3s kubectl -n kubernetes-dashboard create token admin-user --duration=1000h
	@kubectl -n kubernetes-dashboard create token admin-user --duration=1000h

## k3s/app: installs an application to the cluster
.PHONY: k3s/app
k3s/app:
	$(call check_vars, AP DOMAIN)
	@./cluster/scripts/setup_application.sh $${AP} $${DOMAIN}

## k3s/k-app: installs an application to the cluster using kustomize
.PHONY: k3s/k-app
k3s/k-app:
	$(call check_vars, AP DOMAIN)
	@# expand J2 into -D KEY=VALUE flags inline
	@kubectl kustomize ${AP} | jinja2 -S - \
	$(foreach kv,$(J2),-D $(kv)) -D DOMAIN=${DOMAIN} | kubectl apply -f -

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

# kubectl kustomize ./cluster/service/canopy/nodes/overlays/main/node-2 | jinja2 -S - -D DOMAIN=rvserver.online -D VALIDATOR_KEY={pk} | kubectl apply -f -

# ------- v2 ------

SECRETS := $(shell find . -name "secrets.yaml" -not -path "*/.terraform/*")
SOPS_AGE_KEY_FILE = $(HOME)/.config/sops/age/homelab.txt
SEAL_CERT = k8s/sealed-secrets/pub-sealed-secrets.pem

seal-manifests:
	@for f in $(shell find k8s -name "secrets.yml"); do \
		kubeseal --cert $(SEAL_CERT) --format yaml < $$f > $$(dirname $$f)/sealed-secrets.yml; \
		echo "sealed $$f -> $$(dirname $$f)/sealed-secrets.yml"; \
	done

sops/encrypt:
	@for f in $(SECRETS); do \
		sops --encrypt $$f > $${f%.yaml}.enc.yaml; \
		echo "encrypted $$f -> $${f%.yaml}.enc.yaml"; \
	done

sops/decrypt:
	@for f in $(shell find . -name "secrets.enc.yaml" -not -path "*/.terraform/*"); do \
		SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops --decrypt $$f > $${f%.enc.yaml}.yaml; \
		echo "decrypted $$f -> $${f%.enc.yaml}.yaml"; \
	done

# --- Terraform init Setup ---
TF_INFRA = terraform/infra
TF_K8S   = terraform/k8s

.PHONY: tf/init tf/infra-init tf/k8s-init
tf/init: tf/infra-init tf/k8s-init

tf/infra-init:
	export SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE)
	terraform -chdir=${TF_INFRA} init -backend-config=../backend.hcl

tf/k8s-init:
	SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE)
	terraform -chdir=${TF_K8S} init -backend-config=../backend.hcl

# --- Infrastructure (runs without a cluster) ---
.PHONY: tf/infra tf/infra-plan
tf/infra:
	SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) terraform -chdir=$(TF_INFRA) apply

tf/infra-plan:
	SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) terraform -chdir=$(TF_INFRA) plan

# ---- Kubernetes (requires a running cluster) ----
.PHONY: tf/k8s tf/k8s-plan
tf/k8s:
	SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) terraform -chdir=$(TF_K8S) apply

tf/k8s-plan:
	SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) terraform -chdir=$(TF_K8S) plan

# --- Sealed secrets ---
SEAL_CERT  = k8s/sealed-secrets/pub-sealed-secrets.pem

.PHONY: seal-fetch-cert
seal-fetch-cert:
	kubeseal --fetch-cert \
		--controller-name=sealed-secrets \
		--controller-namespace=sealed-secrets \
		> $(SEAL_CERT)

LONGHORN_VERSION = v1.11.1
NAMESPACE = longhorn-system

.PHONY: longhorn/preflight
longhorn/preflight:
	longhornctl --kubeconfig ~/.kube/config \
		--image longhornio/longhorn-cli:$(LONGHORN_VERSION) \
		--namespace $(NAMESPACE) \
		install preflight

# --- ArgoCD ---
ARGOCD_PROJECT = default
ARGOCD_NAMESPACE = argocd
DENY_WINDOW = '{"spec":{"syncWindows":[{"kind":"deny","schedule":"* * * * *","duration":"24h","applications":["*"],"namespaces":["*"],"clusters":["*"],"manualSync":true}]}}'
CLEAR_WINDOW = '{"spec":{"syncWindows":[]}}'

.PHONY: argocd/pause argocd/unpause
argocd/pause:
	@kubectl patch appproject $(ARGOCD_PROJECT) -n $(ARGOCD_NAMESPACE) --type=merge -p $(DENY_WINDOW)
	@echo "⏸️  ArgoCD syncing paused."

argocd/resume:
	@kubectl patch appproject $(ARGOCD_PROJECT) -n $(ARGOCD_NAMESPACE) --type=merge -p $(CLEAR_WINDOW)
	@echo "▶️  ArgoCD syncing resumed."
