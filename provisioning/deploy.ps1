$ErrorActionPreference = "Continue"

if (-not (Test-Path "instance_info.env")) {
    Write-Error "instance_info.env não encontrado. Rode aws_provision.ps1 primeiro."
    exit 1
}

$envVars = @{}
Get-Content "instance_info.env" | ForEach-Object {
    if ($_ -match "^(.+?)=(.*)$") { $envVars[$matches[1]] = $matches[2] }
}
$KEY_NAME = $envVars["KEY_NAME"]
$PUBLIC_IP = $envVars["PUBLIC_IP"]

Write-Host "== Copiando projeto para a instância =="
$files = Get-ChildItem -Path "..\*.py", "..\requirements.txt", "..\run_stability_check.sh" |
    Select-Object -ExpandProperty FullName
scp -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no @files "ec2-user@${PUBLIC_IP}:~/"

Write-Host "== Instalando dependências na instância =="
$remoteScript = @'
set -e
sudo dnf install -y -q python3-pip
python3 -m venv venv
source venv/bin/activate
pip install -q -r requirements.txt
echo "vCPUs disponíveis: $(nproc)"
'@

$remoteScript | ssh -i "$KEY_NAME.pem" -o StrictHostKeyChecking=no "ec2-user@$PUBLIC_IP" "bash -s"

Write-Host ""
Write-Host "Deploy concluído. Para rodar o benchmark na instância:"
Write-Host "  ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP"
Write-Host "  source venv/bin/activate"
Write-Host "  python3 generate_dataset.py --n 600 --size 800x600"
Write-Host "  python3 benchmark.py --workers-list 1,2"
