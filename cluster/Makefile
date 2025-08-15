define check_vars
	$(foreach var,$1,$(if $(value $(var)),,$(error ERROR: $(var) is not set)))
endef

# TODO: Remake
# .PHONY: monitoring
# monitoring:
# 	$(call check_vars, DOMAIN)
# 	@kubectl create -f ./monitoring/prometheus-operator.yml
# 	@kubectl apply -f ./monitoring/service-monitors
# 	@kubectl apply -f ./monitoring/prometheus

.PHONY: tailscale
tailscale:
	$(call check_vars, OAUTH_CLIENT_ID OAUTH_CLIENT_SECRET)
	@echo "setting up tailscale"
	@./tailscale/setup.sh $(OAUTH_CLIENT_ID) $(OAUTH_CLIENT_SECRET)
	@echo "done ✅"

.PHONY: tailscale-expose
tailscale-expose:
	$(call check_vars NAMESPACE SERVICE HOSTNAME)
	@kubectl annotate service -n $(NAMESPACE) $(SERVICE) tailscale.com/hostname="$(HOSTNAME)"
	@kubectl annotate service -n $(NAMESPACE) $(SERVICE) tailscale.com/expose="true"

.PHONY: tailscale-unexpose
tailscale-unexpose:
	$(call check_vars NAMESPACE SERVICE)
	@kubectl annotate service -n $(NAMESPACE) $(SERVICE) tailscale.com/hostname-
	@kubectl annotate service -n $(NAMESPACE) $(SERVICE) tailscale.com/expose-

.PHONY: tailscale-k3s-auth
tailscale-k3s-auth:
	$(call check_vars, SERVER)
	@./tailscale/tailscale-k3s-auth.sh $${SERVER}


.PHONY: traefik
traefik:
	$(call check_vars, DOMAIN)
	@echo "setting up traefik"
	@kubectl apply -f ./traefik/dashboard-service.yml
	@sed -e "s;{{DOMAIN}};$${DOMAIN};g" ./traefik/ingress-routes.yml | kubectl apply -f -
	@echo "done ✅, remember to enable insecure api on the traefik deployment, check ./traefik/dashboard-service.yaml"

.PHONY: change-domain
change-domain:
	$(call check_vars, APP_PATH DOMAIN)
	@./scripts/change-domain.sh $${APP_PATH} $${DOMAIN}

.PHONY: tls
tls:
	$(call check_vars, DOMAIN CLOUDFLARE_TOKEN EMAIL ZONE_ID)
	@kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml
	@echo "wait 10 seconds for cert-manager to be installed"
	@ sleep 10
	@sed -e "s;{{CLOUDFLARE_TOKEN}};$(CLOUDFLARE_TOKEN);g" ./tls/tls.yml | \
		sed -e "s;{{EMAIL}};$(EMAIL);g" | \
		sed -e "s;{{DOMAIN}};$(DOMAIN);g" | kubectl apply -f -
	@echo "done ✅. Bear in mind that the certificate validation may take several minutes, after that, restart the pods behind traefik's reverse proxy in order for this to take effect"

.PHONY: dashboard
dashboard:
	@echo "setting up the kubernetes dashboard"
	$(call check_vars, DOMAIN)
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
	./scripts/setup_application.sh dashboard $${DOMAIN}
	@k3s kubectl -n kubernetes-dashboard create token admin-user --duration=1000h
	@echo "done ✅. Use the token to log in into the dashboard"

.PHONY: app
app:
	$(call check_vars, AP DOMAIN)
	./scripts/setup_application.sh $${AP} $${DOMAIN}
	@make APP_PATH=$${AP} DOMAIN=$${DOMAIN} change-domain

.PHONY: rm-app
rm-app:
	$(call check_vars, APP_PATH)
	for file in $(APP_PATH)/*.yml; do \
		sudo kubectl delete -f "$$file"; \
	done

.PHONY: rancher
rancher:
	$(call check_vars, HOSTNAME)
	./rancher/setup.sh $${HOSTNAME}

.PHONY: iptables
iptables:
	@sudo apt update && sudo apt upgrade -y
	@echo sudo apt install iptables
	@iptables -F
	@update-alternatives --set iptables /usr/sbin/iptables-legacy
	@update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
	@reboot

.PHONY: install-helm
install-helm:
	@curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

.PHONY: ipv6_reload
ipv6_reload:
	systemctl stop k3s
	modprobe ip6table_filter
	systemctl start k3s

.PHONY: k-token
k-token:
	@k3s kubectl -n kubernetes-dashboard create token admin-user --duration=1000h

.PHONY: add-coredns-record
add-coredns-record:
	$(call check_vars, REGISTRY_IP REGISTRY_DOMAIN)
	@./scripts/add_core_dns_record.sh $${REGISTRY_IP} $${REGISTRY_DOMAIN}
	@echo "CoreDNS record added. Remember to also add $${REGISTRY_IP} $${REGISTRY_DOMAIN} to your hosts file ✅"

.PHONY: argocd
argocd:
	kubectl create namespace argocd
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
