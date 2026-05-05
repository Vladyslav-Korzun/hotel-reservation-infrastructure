param(
    [string]$ResourceGroup = "rg-fsa-korzunv",
    [string]$AksName = "aks-fsa-korzunv",
    [string]$AcrName = "acrfsakorzunv"
)

$ErrorActionPreference = "Stop"

$acr = az acr credential show --name $AcrName --query "{username:username,password:passwords[0].value}" -o json | ConvertFrom-Json
az aks get-credentials --resource-group $ResourceGroup --name $AksName --admin --overwrite-existing | Out-Null

$kubeConfigPath = Join-Path $env:USERPROFILE ".kube\config"
$kubeConfigBase64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($kubeConfigPath))

Write-Host "Create these CI/CD variables in both backend and frontend GitLab projects:"
Write-Host ""
Write-Host "DOCKER_USERNAME"
Write-Host $acr.username
Write-Host ""
Write-Host "DOCKER_PASSWORD"
Write-Host $acr.password
Write-Host ""
Write-Host "KUBECONFIG_BASE64"
Write-Host $kubeConfigBase64
Write-Host ""
Write-Host "Required runner tag: fsa"

