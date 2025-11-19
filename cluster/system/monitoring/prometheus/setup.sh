helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack  --namespace monitoring -f values.yml
