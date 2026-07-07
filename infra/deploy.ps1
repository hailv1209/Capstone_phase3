param(
  [string]$TerraformVarsFile = ".\terraform.tfvars",
  [string]$BuildScript = "..\deploy\build-push-images.sh",
  [switch]$SkipBuild,
  [switch]$SkipRelease
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Resolve-BashExecutable {
  $gitBashCandidates = @(
    "D:\Program Files\Git\bin\bash.exe",
    "C:\Program Files\Git\bin\bash.exe"
  )

  foreach ($candidate in $gitBashCandidates) {
    if (Test-Path $candidate) {
      return $candidate
    }
  }

  $bashCommand = Get-Command bash -ErrorAction SilentlyContinue
  if ($bashCommand) {
    return $bashCommand.Source
  }

  throw "Required command not found: bash"
}

function Wait-ForDocker {
  param([int]$TimeoutSeconds = 180)

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    try {
      docker version --format '{{.Server.Version}}' | Out-Null
      return
    }
    catch {
      Start-Sleep -Seconds 5
    }
  }

  throw "Docker daemon is not ready after $TimeoutSeconds seconds."
}

function Invoke-External {
  param(
    [scriptblock]$Command,
    [string]$Description
  )

  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Description failed with exit code $LASTEXITCODE."
  }
}

function Wait-ForWorkloads {
  param(
    [string]$Namespace,
    [string[]]$Resources,
    [int]$TimeoutSeconds = 900
  )

  foreach ($resource in $Resources) {
    Write-Host "==> wait for rollout $resource"
    kubectl -n $Namespace rollout status $resource --timeout="${TimeoutSeconds}s" | Out-Host
  }
}

function Ensure-HelmReleaseImported {
  param(
    [string]$TerraformVarsFile,
    [string]$Namespace,
    [string]$ReleaseName
  )

  $stateListOutput = terraform state list
  if ($LASTEXITCODE -ne 0) {
    throw "terraform state list failed while checking Helm release state."
  }

  if ($stateListOutput | Select-String -SimpleMatch "helm_release.techx_corp[0]") {
    return
  }

  $helmSecrets = kubectl -n $Namespace get secret -l "owner=helm,name=$ReleaseName" --no-headers
  if ($LASTEXITCODE -ne 0) {
    throw "kubectl get secret failed while checking existing Helm release $ReleaseName."
  }

  if ([string]::IsNullOrWhiteSpace($helmSecrets)) {
    return
  }

  Write-Host "==> import existing Helm release into Terraform state: $Namespace/$ReleaseName"
  terraform import -var-file $TerraformVarsFile -var "deploy_release=true" 'helm_release.techx_corp[0]' "$Namespace/$ReleaseName" | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "terraform import failed for existing Helm release $Namespace/$ReleaseName."
  }
}

function Reset-PendingHelmRelease {
  param(
    [string]$Namespace,
    [string]$ReleaseName
  )

  $pendingSecrets = kubectl -n $Namespace get secret -l "owner=helm,name=$ReleaseName" `
    -o jsonpath="{range .items[*]}{.metadata.name}{'|'}{.metadata.labels.status}{'\n'}{end}"
  if ($LASTEXITCODE -ne 0) {
    throw "kubectl get secret failed while checking Helm release status for $ReleaseName."
  }

  if ([string]::IsNullOrWhiteSpace($pendingSecrets)) {
    return
  }

  $hasPendingRelease = $false
  foreach ($line in ($pendingSecrets -split "`r?`n")) {
    if ($line -match "\|pending-") {
      $hasPendingRelease = $true
      break
    }
  }

  if (-not $hasPendingRelease) {
    return
  }

  Write-Host "==> reset Helm release stuck in pending state: $Namespace/$ReleaseName"
  helm uninstall $ReleaseName -n $Namespace | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "helm uninstall failed for pending release $Namespace/$ReleaseName."
  }

  $stateListOutput = terraform state list
  if ($LASTEXITCODE -ne 0) {
    throw "terraform state list failed while resetting pending Helm release."
  }

  if ($stateListOutput | Select-String -SimpleMatch "helm_release.techx_corp[0]") {
    terraform state rm 'helm_release.techx_corp[0]' | Out-Host
    if ($LASTEXITCODE -ne 0) {
      throw "terraform state rm failed for helm_release.techx_corp[0]."
    }
  }
}

function Login-Ecr {
  param(
    [string]$Region,
    [string]$Registry
  )

  $loginCommand = "aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $Registry"
  cmd.exe /c $loginCommand | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "docker login failed for registry $Registry."
  }
}

function Assert-EcrImageExists {
  param(
    [string]$RepositoryName,
    [string]$ImageTag,
    [string]$Region
  )

  Write-Host "==> verify ECR image exists: ${RepositoryName}:${ImageTag}"
  $imageQueryResult = aws ecr batch-get-image `
    --repository-name $RepositoryName `
    --region $Region `
    --image-ids "imageTag=$ImageTag" `
    --query "images[0].imageId.imageTag" `
    --output text

  $imageQueryResult | Out-Host

  if ($LASTEXITCODE -ne 0) {
    throw "Failed to query ECR image ${RepositoryName}:${ImageTag}."
  }

  if ([string]::IsNullOrWhiteSpace($imageQueryResult) -or $imageQueryResult -eq "None") {
    throw "ECR image ${RepositoryName}:${ImageTag} does not exist yet."
  }
}

function Assert-EcrImagesExist {
  param(
    [string]$RepositoryName,
    [string]$Region,
    [string[]]$ImageTags
  )

  foreach ($imageTag in $ImageTags) {
    Assert-EcrImageExists -RepositoryName $RepositoryName -ImageTag $imageTag -Region $Region
  }
}

Require-Command terraform
Require-Command aws
Require-Command kubectl
if (-not $SkipBuild) {
  Require-Command docker
}

Push-Location $scriptRoot
try {
  $resolvedVarsFile = Resolve-Path $TerraformVarsFile
  if (-not $SkipBuild) {
    $null = Resolve-Path $BuildScript
    $buildScriptRelative = $BuildScript -replace "\\", "/"
    $bashExe = Resolve-BashExecutable
  }

  if (-not $SkipBuild) {
    Write-Host "==> wait for docker daemon"
    Wait-ForDocker
  }

  Write-Host "==> terraform init"
  Invoke-External -Description "terraform init" -Command { terraform init }

  Write-Host "==> phase 1: provision EKS + ECR + generated env file"
  Invoke-External -Description "terraform apply phase 1" -Command {
    terraform apply -auto-approve -var-file $resolvedVarsFile -var "deploy_release=false"
  }

  $outputs = terraform output -json | ConvertFrom-Json
  $clusterName = $outputs.cluster_name.value
  $awsRegion = $outputs.aws_region.value
  $namespace = $outputs.namespace.value
  $releaseName = $outputs.release_name.value
  $ecrRepositoryUrl = $outputs.ecr_repository_url.value
  $envOverrideFile = $outputs.env_override_file.value
  $ecrRegistry = ($ecrRepositoryUrl -split "/")[0]
  $ecrRepositoryName = ($ecrRepositoryUrl -split "/")[1]
  $demoVersion = (Get-Content $envOverrideFile | Where-Object { $_ -like "DEMO_VERSION=*" } | Select-Object -First 1).Split("=")[1]
  $defaultImageRepository = terraform output -raw default_image_repository
  $defaultImageTag = terraform output -raw default_image_tag
  $shippingImageTag = terraform output -raw shipping_image_tag
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($shippingImageTag)) {
    $shippingImageTag = "${demoVersion}-shipping"
  }
  $shippingImageRef = "${ecrRepositoryUrl}:${shippingImageTag}"
  $sourceBuiltServiceNames = @(
    "accounting",
    "ad",
    "cart",
    "checkout",
    "currency",
    "email",
    "flagd-ui",
    "fraud-detection",
    "frontend",
    "frontend-proxy",
    "image-provider",
    "kafka",
    "llm",
    "load-generator",
    "payment",
    "product-catalog",
    "product-reviews",
    "quote",
    "recommendation",
    "shipping"
  )

  Write-Host "==> update kubeconfig for $clusterName"
  Invoke-External -Description "aws eks update-kubeconfig" -Command {
    aws eks update-kubeconfig --name $clusterName --region $awsRegion
  }

  if (-not $SkipBuild) {
    Write-Host "==> docker login to $ecrRegistry"
    Login-Ecr -Region $awsRegion -Registry $ecrRegistry

    Write-Host "==> build and push images via $BuildScript"
    Invoke-External -Description "build and push images via $BuildScript" -Command {
      & $bashExe $buildScriptRelative
    }

    Write-Host "==> verify shipping manifest includes linux/amd64"
    $inspectOutput = docker buildx imagetools inspect $shippingImageRef
    if ($LASTEXITCODE -ne 0) {
      throw "docker buildx imagetools inspect failed for $shippingImageRef."
    }
    $inspectOutput | Out-Host
    if ($inspectOutput -notmatch "linux/amd64") {
      throw "Shipping image manifest does not include linux/amd64: $shippingImageRef"
    }
  }
  else {
    if ($defaultImageRepository -eq $ecrRepositoryUrl) {
      $requiredImageTags = $sourceBuiltServiceNames | ForEach-Object { "${defaultImageTag}-$_" }
      if ($shippingImageTag -notin $requiredImageTags) {
        $requiredImageTags += $shippingImageTag
      }
      Assert-EcrImagesExist -RepositoryName $ecrRepositoryName -ImageTags $requiredImageTags -Region $awsRegion
    }
    else {
      Assert-EcrImageExists -RepositoryName $ecrRepositoryName -ImageTag $shippingImageTag -Region $awsRegion
    }
  }

  if (-not $SkipRelease) {
    Reset-PendingHelmRelease -Namespace $namespace -ReleaseName $releaseName
    Ensure-HelmReleaseImported -TerraformVarsFile $resolvedVarsFile -Namespace $namespace -ReleaseName $releaseName

    Write-Host "==> phase 2: deploy Helm release"
    Invoke-External -Description "terraform apply phase 2" -Command {
      terraform apply -auto-approve -var-file $resolvedVarsFile -var "deploy_release=true"
    }

    Wait-ForWorkloads -Namespace $namespace -Resources @(
      "deployment/frontend-proxy",
      "deployment/frontend",
      "deployment/checkout",
      "deployment/cart",
      "deployment/quote",
      "deployment/product-catalog",
      "deployment/product-reviews",
      "deployment/shipping"
    )

    Write-Host "==> current pods in namespace $namespace"
    Invoke-External -Description "kubectl get pods" -Command {
      kubectl -n $namespace get pods
    }

    Write-Host "==> release $releaseName is ready for verification"
  }

  Write-Host "==> completed"
}
finally {
  Pop-Location
}
