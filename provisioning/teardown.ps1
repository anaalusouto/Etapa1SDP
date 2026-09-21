$ErrorActionPreference = "Continue"

if (-not (Test-Path "instance_info.env")) {
    Write-Error "instance_info.env não encontrado, nada para desmontar."
    exit 1
}

$envVars = @{}
Get-Content "instance_info.env" | ForEach-Object {
    if ($_ -match "^(.+?)=(.*)$") { $envVars[$matches[1]] = $matches[2] }
}
$INSTANCE_ID = $envVars["INSTANCE_ID"]
$SG_ID = $envVars["SG_ID"]
$REGION = $envVars["REGION"]

Write-Host "== Terminando instância $INSTANCE_ID =="
aws ec2 terminate-instances --region $REGION --instance-ids $INSTANCE_ID | Out-Null
aws ec2 wait instance-terminated --region $REGION --instance-ids $INSTANCE_ID
Write-Host "  instância terminada"

Write-Host "== Removendo Security Group $SG_ID =="
Start-Sleep -Seconds 5
$null = & aws ec2 delete-security-group --region $REGION --group-id $SG_ID 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  (SG ainda em uso por outro recurso — apague manualmente depois)"
}

Remove-Item "instance_info.env" -ErrorAction SilentlyContinue
Write-Host "Tudo desmontado."
