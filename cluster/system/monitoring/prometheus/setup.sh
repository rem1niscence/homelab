helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm repo update
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack  -n monitoring \
  -f values.yml --create-namespace --version 80.4.1
