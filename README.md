# Gateway API - Monitoring configuration

This repository is used to store Kube State Metrics configurations and dashboards for the Gateway API and Envoy Gateway custom resources.

## Gateway API

KSM configurations and dashboards are based on [Kuadrant/gateway-api-state-metrics](https://github.com/Kuadrant/gateway-api-state-metrics).

## Envoy Gateway

KSM configurations are our own develpment.

Dashboards are based on [envoyproxy/gateway dashboards](https://github.com/envoyproxy/gateway/tree/main/charts/gateway-addons-helm/dashboards).

# Apply changes

This repo is not directly deployed and applying the configurations to other repositories is required.

KSM configs: https://github.com/giantswarm/observability-bundle/tree/main/helm/observability-bundle/ksm-configurations

Dashboards: https://github.com/giantswarm/dashboards
