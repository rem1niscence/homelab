define check_vars
	$(foreach var,$1,$(if $(value $(var)),,$(error ERROR: $(var) is not set)))
endef

.PHONY: tailscale
tailscale:
	$(call check_vars, OAUTH_CLIENT_ID OAUTH_CLIENT_SECRET)
	@echo "setting up tailscale"
	@sed -e "s;{{OAUTH_CLIENT_ID}};$(OAUTH_CLIENT_ID);g" ./tailscale/operator.yml \
	| sed -e "s;{{OAUTH_CLIENT_SECRET}};$(OAUTH_CLIENT_SECRET);g" | kubectl apply -f -
	sleep 5
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

.PHONY: traefik
traefik:
	$(call check_vars, DOMAIN)
	@echo "setting up traefik"
	@kubectl apply -f ./traefik/secrets.yml
	@kubectl apply -f ./traefik/middleware.yml
	@sed -e "s;{{DOMAIN}};$${DOMAIN};g" ./traefik/ingress-routes.yml | kubectl apply -f -
	@kubectl patch ingressroute/traefik-dashboard-secure --type=json --patch-file ./traefik/patch-dashboard-service.yml
	@echo "done ✅"

.PHONY: change-domain
change-domain:
	$(call check_vars, APP_PATH DOMAIN)
	@sed -e "s;{{DOMAIN}};$(DOMAIN);g" "./$(APP_PATH)/ingress-routes.yml" | kubectl apply -f -

.PHONY: tls
tls:
	$(call check_vars, DOMAIN CLOUDFARE_TOKEN EMAIL)
	@kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.7.0/cert-manager.yaml
	@echo "wait 10 seconds for cert-manager to be installed"
	@ sleep 10
	@sed -e "s;{{CLOUDFARE_TOKEN}};$(CLOUDFARE_TOKEN);g" ./traefik/tls.yml | \
		sed -e "s;{{EMAIL}};$(EMAIL);g" | \
		sed -e "s;{{DOMAIN}};$(DOMAIN);g" | kubectl apply -f -
	@echo "done ✅. Bear in mind that the certificate validation may take several minutes, after that, restart the pods behind traefik's reverse proxy in order for this to take effect"

.PHONY: dashboard
dashboard:
	@echo "setting up the kubernetes dashboard"
	$(call check_vars, DOMAIN)
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
	./setup_application.sh dashboard $${DOMAIN}
	@k3s kubectl -n kubernetes-dashboard create token admin-user --duration=1000h
	@echo "done ✅. Use the token to log in into the dashboard"

.PHONY: app
app:
	$(call check_vars, APP_PATH DOMAIN)
	./setup_application.sh $${APP_PATH} $${DOMAIN}
	@make APP_PATH=$${APP_PATH} change-domain

.PHONY: rm-app
rm-app:
	$(call check_vars, APP_PATH)
	for file in $(APP_PATH)/*.yml; do \
		sudo kubectl delete -f "$$file"; \
	done

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
