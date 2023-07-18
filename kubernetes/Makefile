define check_vars
	$(foreach var,$1,$(if $(value $(var)),,$(error ERROR: $(var) is not set)))
endef

.PHONY: tailscale
tailscale:
	$(call check_vars, OAUTH_CLIENT_ID OAUTH_CLIENT_SECRET)
	@echo "setting up tailscale"
	@sed -e "s;{{OAUTH_CLIENT_ID}};$(OAUTH_CLIENT_ID);g" ./tailscale/operator.yml \
	| sed -e "s;{{OAUTH_CLIENT_SECRET}};$(OAUTH_CLIENT_SECRET);g" | kubectl apply -f -
	sleep 15
	@kubectl annotate service traefik tailscale.com/hostname="k3s-traefik" -n kube-system
	@kubectl annotate service traefik tailscale.com/expose="true" -n kube-system
	@echo "done ✅"

.PHONY: traefik
traefik:
	$(call check_vars, DOMAIN CLOUDFARE_TOKEN EMAIL)
	@echo "setting up traefik"
	@kubectl apply -f ./traefik/secrets.yml
	@kubectl apply -f ./traefik/middleware.yml
	@sed -e "s;{{DOMAIN}};$${DOMAIN};g" ./traefik/ingress-routes.yml | kubectl apply -f -
	@kubectl patch ingressroute/traefik-dashboard-secure --type=json --patch-file ./traefik/patch-dashboard-service.yml
	@sed -e "s;{{CLOUDFARE_TOKEN}};$(CLOUDFARE_TOKEN);g" ./traefik/tls.yml \
	@sed -e "s;{{EMAIL}};$(EMAIL);g" ./traefik/tls.yml \
	@sed -e "s;{{DOMAIN}};$(DOMAIN);g" ./traefik/tls.yml | kubectl apply -f -
	@echo "done ✅. Bear in mind that the certificate validation may take several minutes, after that, restart the pods behind traefik's reverse proxy in order for this to take effect"

.PHONY: paperless
paperless:
	$(call check_vars, DOMAIN)
	./setup_application.sh paperless $${DOMAIN} true

.PHONY: dashboard
dashboard:
	@echo "setting up the kubernetes dashboard"
	$(call check_vars, DOMAIN)
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
	@sed -e "s;{{DOMAIN}};$(DOMAIN);g" ./dashboard/ingress-routes.yml | kubectl apply -f -
	@k3s kubectl create -f ./dashboard/rbac.yml
	k3s kubectl -n kubernetes-dashboard create token admin-user
	@echo "done ✅. Use the token to log in into the dashboard"

.PHONY: iptables
iptables:
	@sudo apt update && sudo apt upgrade -y
	@echo sudo apt install iptables
	@iptables -F
	@update-alternatives --set iptables /usr/sbin/iptables-legacy
	@update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
	@reboot 
