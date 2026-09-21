#!/usr/bin/env bash
set -euo pipefail

REGION="us-east-1"
INSTANCE_TYPE="t2.medium"
KEY_NAME="sd-etapa1-key"
SG_NAME="sd-etapa1-sg"
TAG_NAME="sd-etapa1-benchmark"

echo "== Descobrindo IP público de origem (a equipe) =="
MY_IP="$(curl -s https://checkip.amazonaws.com)/32"
echo "  origem restrita a: $MY_IP"

echo "== Buscando a AMI mais recente do Amazon Linux 2023 (owned by amazon) =="
AMI_ID="$(aws ec2 describe-images --owners amazon --region "$REGION" \
    --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
    --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)"
echo "  AMI: $AMI_ID"

echo "== Criando key pair (se ainda não existir) =="
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" >/dev/null 2>&1; then
    aws ec2 create-key-pair --key-name "$KEY_NAME" --region "$REGION" \
        --query 'KeyMaterial' --output text > "${KEY_NAME}.pem"
    chmod 400 "${KEY_NAME}.pem"
    echo "  chave salva em ${KEY_NAME}.pem"
else
    echo "  key pair '$KEY_NAME' já existe, reaproveitando"
fi

echo "== Descobrindo VPC padrão =="
VPC_ID="$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
    --region "$REGION" --query 'Vpcs[0].VpcId' --output text)"

echo "== Criando Security Group =="
SG_ID="$(aws ec2 describe-security-groups --region "$REGION" \
    --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" \
    --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")"

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
    SG_ID="$(aws ec2 create-security-group --region "$REGION" \
        --group-name "$SG_NAME" \
        --description "SSH restrito a origem da equipe - Etapa 1 SD" \
        --vpc-id "$VPC_ID" --query 'GroupId' --output text)"
    echo "  SG criado: $SG_ID"
else
    echo "  SG já existe, reaproveitando: $SG_ID"
fi

aws ec2 authorize-security-group-ingress --region "$REGION" \
    --group-id "$SG_ID" --protocol tcp --port 22 --cidr "$MY_IP" \
    2>/dev/null || echo "  regra de SSH já existia"

echo "== Lançando instância EC2 ($INSTANCE_TYPE) =="
USE_UNLIMITED_CREDITS=false
CREDIT_ARGS=()
if [[ "$USE_UNLIMITED_CREDITS" == "true" && "$INSTANCE_TYPE" =~ ^t[23]\. ]]; then
    CREDIT_ARGS=(--credit-specification CpuCredits=unlimited)
fi

INSTANCE_ID="$(aws ec2 run-instances --region "$REGION" \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]" \
    "${CREDIT_ARGS[@]}" \
    --query 'Instances[0].InstanceId' --output text)"

echo "  aguardando instância ficar 'running'..."
aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"

PUBLIC_IP="$(aws ec2 describe-instances --region "$REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"

cat > instance_info.env <<EOF
INSTANCE_ID=$INSTANCE_ID
PUBLIC_IP=$PUBLIC_IP
KEY_NAME=$KEY_NAME
SG_ID=$SG_ID
REGION=$REGION
EOF

echo ""
echo "== Pronto =="
echo "  Instance ID : $INSTANCE_ID"
echo "  Tipo        : $INSTANCE_TYPE ($(python3 -c "print('8 vCPUs' if '2xlarge' in '$INSTANCE_TYPE' else '4 vCPUs')"))"
echo "  IP público  : $PUBLIC_IP"
echo "  Região/zona : $REGION"
echo "  SG          : $SG_ID (porta 22 restrita a $MY_IP)"
echo ""
echo "Conectar via SSH (aguarde ~30s pro boot terminar):"
echo "  ssh -i ${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
echo ""
echo "Dados salvos em instance_info.env para uso em deploy.sh e teardown.sh"
