$ErrorActionPreference = "Continue"

$REGION = "us-east-1"
$INSTANCE_TYPE = "t2.medium"
$KEY_NAME = "sd-etapa1-key"
$SG_NAME = "sd-etapa1-sg"
$TAG_NAME = "sd-etapa1-benchmark"

function Invoke-Aws {
    param([string[]]$CliArgs)
    $out = & aws @CliArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERRO ao rodar: aws $($CliArgs -join ' ')" -ForegroundColor Red
        Write-Host ($out | Out-String) -ForegroundColor Red
        exit 1
    }
    return $out
}

Write-Host "== Buscando a AMI mais recente do Amazon Linux 2023 (owned by amazon) =="
$AMI_ID = Invoke-Aws @("ec2", "describe-images", "--owners", "amazon", "--region", $REGION,
    "--filters", "Name=name,Values=al2023-ami-*-x86_64", "Name=state,Values=available",
    "--query", "sort_by(Images,&CreationDate)[-1].ImageId", "--output", "text")
Write-Host "  AMI: $AMI_ID"

Write-Host "== Descobrindo IP público de origem (a equipe) =="
$MY_IP = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim() + "/32"
Write-Host "  origem restrita a: $MY_IP"

Write-Host "== Criando key pair (se ainda não existir) =="
$null = & aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION 2>&1
if ($LASTEXITCODE -ne 0) {
    $keyMaterial = Invoke-Aws @("ec2", "create-key-pair", "--key-name", $KEY_NAME, "--region", $REGION, "--query", "KeyMaterial", "--output", "text")
    $keyText = (($keyMaterial -join "`n") -replace "`r", "") + "`n"
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) "$KEY_NAME.pem"), $keyText, [System.Text.Encoding]::ASCII)
    Write-Host "  chave salva em $KEY_NAME.pem"
} else {
    Write-Host "  key pair '$KEY_NAME' já existe, reaproveitando"
}

Write-Host "== Descobrindo VPC padrão =="
$VPC_ID = Invoke-Aws @("ec2", "describe-vpcs", "--filters", "Name=isDefault,Values=true", "--region", $REGION, "--query", "Vpcs[0].VpcId", "--output", "text")
if (-not $VPC_ID -or $VPC_ID -eq "None") {
    Write-Host "ERRO: nenhuma VPC padrão encontrada nessa conta/região." -ForegroundColor Red
    exit 1
}
Write-Host "  VPC: $VPC_ID"

Write-Host "== Criando Security Group =="
$SG_ID = & aws ec2 describe-security-groups --region $REGION --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[0].GroupId' --output text 2>$null

if ($LASTEXITCODE -ne 0 -or -not $SG_ID -or $SG_ID -eq "None") {
    $SG_ID = Invoke-Aws @("ec2", "create-security-group", "--region", $REGION, "--group-name", $SG_NAME, "--description", "SSH restrito a origem da equipe - Etapa 1 SD", "--vpc-id", $VPC_ID, "--query", "GroupId", "--output", "text")
    Write-Host "  SG criado: $SG_ID"
} else {
    Write-Host "  SG já existe, reaproveitando: $SG_ID"
}

$null = & aws ec2 authorize-security-group-ingress --region $REGION --group-id $SG_ID --protocol tcp --port 22 --cidr $MY_IP 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  regra de SSH já existia (ok)"
}

Write-Host "== Lançando instância EC2 ($INSTANCE_TYPE) =="
$USE_UNLIMITED_CREDITS = $false
$creditSpec = if ($USE_UNLIMITED_CREDITS -and $INSTANCE_TYPE -match "^t[23]\.") { "CpuCredits=unlimited" } else { $null }
$runArgs = @(
    "ec2", "run-instances", "--region", $REGION,
    "--image-id", $AMI_ID,
    "--instance-type", $INSTANCE_TYPE,
    "--key-name", $KEY_NAME,
    "--security-group-ids", $SG_ID,
    "--tag-specifications", "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]",
    "--query", "Instances[0].InstanceId", "--output", "text"
)
if ($creditSpec) { $runArgs += @("--credit-specification", $creditSpec) }

$INSTANCE_ID = Invoke-Aws $runArgs

Write-Host "  aguardando instância ficar 'running'..."
Invoke-Aws @("ec2", "wait", "instance-running", "--region", $REGION, "--instance-ids", $INSTANCE_ID) | Out-Null

$PUBLIC_IP = Invoke-Aws @("ec2", "describe-instances", "--region", $REGION, "--instance-ids", $INSTANCE_ID, "--query", "Reservations[0].Instances[0].PublicIpAddress", "--output", "text")

@"
INSTANCE_ID=$INSTANCE_ID
PUBLIC_IP=$PUBLIC_IP
KEY_NAME=$KEY_NAME
SG_ID=$SG_ID
REGION=$REGION
"@ | Out-File -FilePath "instance_info.env" -Encoding ascii

Write-Host ""
Write-Host "== Pronto ==" -ForegroundColor Green
Write-Host "  Instance ID : $INSTANCE_ID"
Write-Host "  Tipo        : $INSTANCE_TYPE"
Write-Host "  IP público  : $PUBLIC_IP"
Write-Host "  Região      : $REGION"
Write-Host "  SG          : $SG_ID (porta 22 restrita a $MY_IP)"
Write-Host ""
Write-Host "Conectar via SSH (aguarde ~30s pro boot terminar):"
Write-Host "  ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP"
Write-Host ""
Write-Host "Dados salvos em instance_info.env para uso em deploy.ps1 e teardown.ps1"
