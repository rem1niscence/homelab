.PHONY: tailscale

tailscale:
	@echo "setting up tailscale"
	@bash -c 'set -o allexport; source ./tailscale/.env; set +o allexport; envsubst < ./tailscale/operator.yml > ./tailscale/operator-processed.yml'
	@kubectl annotate service -n kube-system traefik tailscale.com/expose=true
	@echo "done ✅"
