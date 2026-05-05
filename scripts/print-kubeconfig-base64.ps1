param(
    [string]$ResourceGroup = "rg-fsa-korzunv",
    [string]$AksName = "aks-fsa-korzunv"
)

$ErrorActionPreference = "Stop"

az aks get-credentials --resource-group $ResourceGroup --name $AksName --admin --overwrite-existing
$kubeConfigPath = Join-Path $env:USERPROFILE ".kube\config"
$bytes = [System.IO.File]::ReadAllBytes($kubeConfigPath)
[Convert]::ToBase64String($bytes)

