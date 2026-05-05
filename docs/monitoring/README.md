# Monitoring

This project uses Grafana Alloy as a student-cluster telemetry agent.

Alloy runs in the AKS cluster, discovers pods in the `app` namespace, collects:

- Prometheus metrics from pods annotated with `prometheus.io/scrape: "true"`
- Kubernetes pod logs from frontend, backend, and Keycloak

The collected data is forwarded to the Fullstack Academy monitoring stack:

```text
AKS app pods
  -> Alloy student agent
  -> Prometheus remote_write: https://prometheus.fullstackacademy.sk/api/v1/write
  -> Loki push: https://alloy.fullstackacademy.sk/loki/api/v1/push
  -> Grafana: https://grafana.fullstackacademy.sk
```

## Install

```powershell
$helm = "$env:TEMP\helm-v3.15.4\windows-amd64\helm.exe"

& $helm repo add grafana https://grafana.github.io/helm-charts
& $helm repo update

& $helm upgrade --install alloy-student grafana/alloy `
  --namespace monitoring `
  --create-namespace `
  -f kubernetes\helm\helm-values\grafana-alloy\student-override.yaml `
  --kubeconfig "$env:USERPROFILE\.kube\config"
```

## Verify

```powershell
kubectl --kubeconfig "$env:USERPROFILE\.kube\config" -n monitoring get pods
kubectl --kubeconfig "$env:USERPROFILE\.kube\config" -n monitoring logs -l app.kubernetes.io/name=alloy -c alloy --tail=100
```

Expected pod:

```text
alloy-student-...   2/2   Running
```

## Grafana Queries

Open:

```text
https://grafana.fullstackacademy.sk
```

Prometheus:

```promql
up{student="korzunv"}
```

Loki:

```logql
{student="korzunv"}
```

## Dashboard

Import the dashboard from:

```text
docs/monitoring/grafana-dashboard.json
```

Grafana path:

```text
Dashboards -> New -> Import -> Upload JSON
```

During import, select the central Prometheus and Loki data sources.
