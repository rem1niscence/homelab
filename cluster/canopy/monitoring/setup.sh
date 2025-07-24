#!/bin/bash

NAMESPACE="canopy"

helm repo add grafana https://grafana.github.io/helm-charts
helm repo add vm https://victoriametrics.github.io/helm-charts/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install loki grafana/loki --namespace $NAMESPACE -f loki.yml

helm upgrade --install promtail grafana/promtail --namespace $NAMESPACE -f promtail.yml

helm upgrade --install vms vm/victoria-metrics-single --namespace $NAMESPACE -f victoria_metrics.yml

helm upgrade --install black --namespace $NAMESPACE prometheus-community/prometheus-blackbox-exporter --values blackbox.yml
