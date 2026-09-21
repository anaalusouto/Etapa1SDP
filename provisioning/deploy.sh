#!/usr/bin/env bash
set -euo pipefail

if [ ! -f instance_info.env ]; then
    echo "instance_info.env não encontrado. Rode aws_provision.sh primeiro." >&2
    exit 1
fi
source instance_info.env

echo "== Copiando projeto para a instância =="
scp -i "${KEY_NAME}.pem" -o StrictHostKeyChecking=no -r \
    ../*.py ../requirements.txt ../run_stability_check.sh \
    "ec2-user@${PUBLIC_IP}:~/"

echo "== Instalando dependências na instância =="
ssh -i "${KEY_NAME}.pem" -o StrictHostKeyChecking=no "ec2-user@${PUBLIC_IP}" bash -s <<'REMOTE'
    set -e
    sudo dnf install -y -q python3-pip
    python3 -m venv venv
    source venv/bin/activate
    pip install -q -r requirements.txt
    echo "vCPUs disponíveis: $(nproc)"
REMOTE

echo ""
echo "Deploy concluído. Para rodar o benchmark na instância:"
echo "  ssh -i ${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
echo "  source venv/bin/activate"
echo "  python3 generate_dataset.py --n 600 --size 800x600"
echo "  python3 benchmark.py --workers-list 1,2"
