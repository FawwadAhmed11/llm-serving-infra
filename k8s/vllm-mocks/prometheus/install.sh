#!/bin/bash

# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update


# Install Prometheus stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Grafana is included in kube-prometheus-stack by default
# Access via port-forward:
# kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
# Default credentials: admin / prom-operator
