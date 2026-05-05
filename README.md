# Hotel Reservation DevOps

DevOps project for the Hotel Reservation application. The stack is deployed to Azure AKS and uses GitLab CI/CD to build Docker images, push them to Azure Container Registry, and deploy the frontend and backend to Kubernetes.

## What Was Completed

- Azure infrastructure is prepared for the student environment:
  - Resource Group: `rg-fsa-korzunv`
  - AKS: `aks-fsa-korzunv`
  - ACR: `acrfsakorzunv.azurecr.io`
  - PostgreSQL Flexible Server: `psql-fsa-korzunv.postgres.database.azure.com`
  - Public ingress IP: `98.71.77.25`
- Kubernetes workload is deployed in namespace `app`:
  - Backend deployment: `fsa-be`
  - Frontend deployment: `fsa-fe`
  - Keycloak: `fsa-keycloak`
  - Ingress for app, API, and Keycloak
- GitLab CI/CD is configured for both application repositories:
  - builds Docker images
  - pushes images to ACR
  - deploys new image tags to AKS
  - uses runner tag `fsa-korzun`
- CI/CD variables were added in both GitLab projects:
  - `DOCKER_USERNAME`
  - `DOCKER_PASSWORD`
  - `KUBECONFIG_BASE64`
- Monitoring is configured:
  - Prometheus metrics
  - Loki logs
  - Grafana Alloy collection
  - Grafana dashboard JSON is included in `docs/monitoring/grafana-dashboard.json`
- Rolling update strategy was adjusted for the small AKS node:
  - `maxSurge: 0`
  - `maxUnavailable: 1`

This prevents failed rollouts caused by `Insufficient cpu` when Kubernetes tries to run an old and a new pod at the same time.

## Repositories

GitHub:

- Backend: `https://github.com/Vladyslav-Korzun/hotel-reservation-backend`
- Frontend: `https://github.com/Vladyslav-Korzun/hotel-reservation-frontend`
- Infrastructure: `https://github.com/Vladyslav-Korzun/hotel-reservation-infrastructure`

GitLab:

- Backend: `https://gitlab.fullstackacademy.sk/korzunv1/hotel-reservation-backend`
- Frontend: `https://gitlab.fullstackacademy.sk/korzunv1/hotel-reservation-frontend`
- Infrastructure: `https://gitlab.fullstackacademy.sk/korzunv1/hotel-reservation-infrastructure`

## Public URLs

Application:

- Frontend: `https://korzunv.98.71.77.25.nip.io`
- Backend health through ingress: `https://korzunv.98.71.77.25.nip.io/api/actuator/health`
- Keycloak through app ingress: `https://korzunv.98.71.77.25.nip.io/auth`
- Keycloak realm metadata: `https://korzunv.98.71.77.25.nip.io/auth/realms/hotel-reservation/.well-known/openid-configuration`

Platform services:

- GitLab: `https://gitlab.fullstackacademy.sk`
- Keycloak admin ingress: `https://keycloak.fullstackacademy.sk/auth`
- Grafana: `https://grafana.fullstackacademy.sk`
- Prometheus: `https://prometheus.fullstackacademy.sk`
- Alloy Loki gateway: `https://alloy.fullstackacademy.sk/loki/api/v1/push`

## Access

Keycloak admin:

```text
URL:      https://korzunv.98.71.77.25.nip.io/auth/admin
Username: admin
Password: admin
Realm:    hotel-reservation
```

Application test users in Keycloak:

```text
admin@posam.sk / admin123
staff          / staff123
user           / user123
```

The users are visible in Keycloak Admin Console under the `hotel-reservation` realm. Their emails are:

```text
admin@posam.sk -> admin@posam.sk
staff          -> staff@gmail.com
user           -> user@gmail.com
```

Grafana:

```text
URL: https://grafana.fullstackacademy.sk
```

Preferred login is Azure AD. If local Grafana admin login is required, retrieve the password from the Kubernetes secret:

```powershell
kubectl --kubeconfig "$env:USERPROFILE\.kube\config" `
  -n monitoring get secret grafana-secret `
  -o jsonpath="{.data.username}{' '}{.data.password}"
```

Then decode the values:

```powershell
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("<base64-value>"))
```

GitLab:

Use the FullStack Academy GitLab account. The CI runner used by this project is visible in GitLab with tag:

```text
fsa-korzun
```

## How To Verify

Connect local kubectl to AKS:

```powershell
az aks get-credentials `
  --resource-group rg-fsa-korzunv `
  --name aks-fsa-korzunv `
  --admin `
  --overwrite-existing
```

Check application pods:

```powershell
kubectl --kubeconfig "$env:USERPROFILE\.kube\config" -n app get pods,deploy,svc,ingress
```

Expected result:

```text
deployment.apps/fsa-be   1/1
deployment.apps/fsa-fe   1/1
pod/fsa-keycloak-0       1/1
```

Check backend health:

```powershell
Invoke-WebRequest `
  -Uri "https://korzunv.98.71.77.25.nip.io/api/actuator/health" `
  -UseBasicParsing
```

Expected response body:

```json
{"status":"UP","groups":["liveness","readiness"]}
```

Check frontend:

```powershell
Invoke-WebRequest `
  -Uri "https://korzunv.98.71.77.25.nip.io" `
  -UseBasicParsing
```

Expected status code: `200`.

Check current deployed images:

```powershell
kubectl --kubeconfig "$env:USERPROFILE\.kube\config" `
  -n app get deploy fsa-fe fsa-be `
  -o jsonpath="{range .items[*]}{.metadata.name}{' image='}{.spec.template.spec.containers[0].image}{' ready='}{.status.readyReplicas}{'/'}{.status.replicas}{'\n'}{end}"
```

Check monitoring:

```powershell
kubectl --kubeconfig "$env:USERPROFILE\.kube\config" -n monitoring get pods,svc,ingress
```

In Grafana, useful queries are:

Prometheus:

```promql
up
```

Loki:

```logql
{namespace="app"}
```

## How CI/CD Works

Both application repositories have `.gitlab-ci.yml` with two stages:

```text
build -> deploy
```

Build stage:

- uses `docker:27.4.0`
- starts Docker-in-Docker
- logs in to `acrfsakorzunv.azurecr.io`
- builds image with two tags:
  - commit tag: `$CI_COMMIT_SHORT_SHA`
  - `latest`
- pushes both tags to ACR

Deploy stage:

- uses `alpine/k8s:1.30.5`
- decodes `KUBECONFIG_BASE64`
- patches deployment strategy to avoid surge on the small AKS node
- updates Kubernetes deployment image
- waits for rollout

Backend deployment command used by CI:

```sh
kubectl -n app set image deployment/fsa-be fsa-be="$ACR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
```

Frontend deployment command used by CI:

```sh
kubectl -n app set image deployment/fsa-fe fsa-fe="$ACR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
```

## Important Files

- Backend Kubernetes deployment: `kubernetes/workload/03-app-backend/deployment.yaml`
- Frontend Kubernetes deployment: `kubernetes/workload/04-app-frontend/deployment.yaml`
- Application ingress: `kubernetes/workload/05-ingress/app-ingress.yaml`
- Keycloak ingress: `kubernetes/workload/05-ingress/keycloak-ingress.yaml`
- Grafana ingress: `kubernetes/workload/05-ingress/grafana-ingress.yaml`
- Prometheus ingress: `kubernetes/workload/05-ingress/prometheus-ingress.yaml`
- Keycloak values: `kubernetes/helm/helm-values/keycloak/override.yaml`
- Keycloak realm import: `kubernetes/helm/helm-values/keycloak/realm-fsa-configmap.yaml`
- Monitoring notes: `docs/monitoring/README.md`
- Grafana dashboard: `docs/monitoring/grafana-dashboard.json`

## Known Notes

- The AKS node is small. During CI jobs, GitLab may show temporary `Insufficient cpu` messages while waiting for a job pod. This is acceptable if the job eventually starts.
- The app deployments intentionally use `maxSurge: 0` to avoid scheduling two app versions at the same time.
- `KUBECONFIG_BASE64` and ACR credentials are stored only as GitLab CI/CD variables, not in this README.
- The infrastructure repository itself does not build Docker images, so Docker CI variables are needed only in frontend and backend GitLab projects.
