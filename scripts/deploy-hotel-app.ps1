param(
    [string]$BackendPath = "C:\Users\Vlad\Desktop\start\Academy_Backend-main",
    [string]$FrontendPath = "C:\Users\Vlad\Desktop\start\Academy_Frontend-main",
    [string]$ResourceGroup = "rg-fsa-korzunv",
    [string]$AksName = "aks-fsa-korzunv",
    [string]$AcrName = "acrfsakorzunv",
    [string]$Namespace = "app",
    [switch]$SkipBuild,
    [switch]$RestartKeycloak
)

$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

Require-Command az
Require-Command docker
Require-Command kubectl

$repoRoot = Split-Path -Parent $PSScriptRoot
$registry = "$AcrName.azurecr.io"
$backendImage = "$registry/hotel-backend:latest"
$frontendImage = "$registry/hotel-frontend:latest"
$KubeConfigPath = Join-Path $env:USERPROFILE ".kube\config"

Write-Host "Checking Azure authentication..."
az account get-access-token --resource https://management.core.windows.net/ --output none
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Azure session requires MFA. Run this command, finish browser login, then rerun this script:"
    Write-Host 'az logout'
    Write-Host 'az login --tenant "3590242b-a92d-4bb9-9ff9-eb7a1183f511" --scope "https://management.core.windows.net//.default" --use-device-code'
    throw "Azure Management token is not available."
}

Write-Host "Connecting kubectl to AKS '$AksName'..."
Invoke-Native -Description "Getting AKS credentials" -Command {
    az aks get-credentials --resource-group $ResourceGroup --name $AksName --admin --overwrite-existing
}
kubectl --kubeconfig $KubeConfigPath config current-context

Write-Host "Logging in to ACR '$AcrName'..."
Invoke-Native -Description "ACR login" -Command {
    az acr login --name $AcrName
}

if (-not $SkipBuild) {
    Write-Host "Building and pushing backend image: $backendImage"
    Invoke-Native -Description "Backend Docker build" -Command {
        docker build -t $backendImage $BackendPath
    }
    Invoke-Native -Description "Backend Docker push" -Command {
        docker push $backendImage
    }

    Write-Host "Building and pushing frontend image: $frontendImage"
    Invoke-Native -Description "Frontend Docker build" -Command {
        docker build -t $frontendImage $FrontendPath
    }
    Invoke-Native -Description "Frontend Docker push" -Command {
        docker push $frontendImage
    }
}

Write-Host "Applying namespace and secrets..."
kubectl --kubeconfig $KubeConfigPath apply -f (Join-Path $repoRoot "kubernetes\workload\01-namespace.yaml")
kubectl --kubeconfig $KubeConfigPath apply -f (Join-Path $repoRoot "kubernetes\workload\02-secrets.yaml")

Write-Host "Applying Keycloak import ConfigMaps..."
kubectl --kubeconfig $KubeConfigPath apply -f (Join-Path $repoRoot "kubernetes\helm\helm-values\keycloak\keycloak-java-config.yaml")
kubectl --kubeconfig $KubeConfigPath apply -f (Join-Path $repoRoot "kubernetes\helm\helm-values\keycloak\realm-fsa-configmap.yaml")

if ($RestartKeycloak) {
    Write-Host "Restarting Keycloak so it can read updated mounted config..."
    kubectl --kubeconfig $KubeConfigPath -n $Namespace rollout restart statefulset/fsa-keycloak 2>$null
    if ($LASTEXITCODE -eq 0) {
        kubectl --kubeconfig $KubeConfigPath -n $Namespace rollout status statefulset/fsa-keycloak --timeout=300s
    } else {
        kubectl --kubeconfig $KubeConfigPath -n $Namespace rollout restart deployment/fsa-keycloak
        kubectl --kubeconfig $KubeConfigPath -n $Namespace rollout status deployment/fsa-keycloak --timeout=300s
    }
}

Write-Host "Applying application workloads..."
kubectl --kubeconfig $KubeConfigPath apply -f (Join-Path $repoRoot "kubernetes\workload\03-app-backend")
kubectl --kubeconfig $KubeConfigPath apply -f (Join-Path $repoRoot "kubernetes\workload\04-app-frontend")
kubectl --kubeconfig $KubeConfigPath apply -f (Join-Path $repoRoot "kubernetes\workload\05-ingress\app-ingress.yaml")

Write-Host "Waiting for application rollouts..."
kubectl --kubeconfig $KubeConfigPath -n $Namespace rollout status deployment/fsa-be --timeout=240s
kubectl --kubeconfig $KubeConfigPath -n $Namespace rollout status deployment/fsa-fe --timeout=180s

Write-Host "Current app status:"
kubectl --kubeconfig $KubeConfigPath -n $Namespace get pods,svc,ingress
