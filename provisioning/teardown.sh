#!/usr/bin/env bash
set -euo pipefail

if [ ! -f instance_info.env ]; then
    echo "instance_info.env não encontrado, nada para desmontar." >&2
    exit 1
fi
source instance_info.env

echo "== Terminando instância $INSTANCE_ID =="
aws ec2 terminate-instances --region "$REGION" --instance-ids "$INSTANCE_ID" >/dev/null
aws ec2 wait instance-terminated --region "$REGION" --instance-ids "$INSTANCE_ID"
echo "  instância terminada"

echo "== Removendo Security Group $SG_ID =="
sleep 5
aws ec2 delete-security-group --region "$REGION" --group-id "$SG_ID" \
    2>/dev/null || echo "  (SG ainda em uso por outro recurso — apague manualmente depois)"

rm -f instance_info.env
echo "Tudo desmontado."
