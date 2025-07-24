#!/bin/bash

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install loki grafana/loki --namespace canopy -f loki.yml

helm upgrade --install promtail grafana/promtail --namespace=canopy -f promtail.yml
