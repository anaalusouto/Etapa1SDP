#!/usr/bin/env bash
set -euo pipefail

RUNS="${1:-5}"
WORKERS="${2:-4}"

echo "== Gerando baseline sequencial =="
python3 sequential.py

for i in $(seq 1 "$RUNS"); do
    echo ""
    echo "== Rodada paralela $i/$RUNS (workers=$WORKERS) =="
    python3 parallel.py --workers "$WORKERS"
    python3 verify.py
done

echo ""
echo "Todas as $RUNS rodadas produziram resultado idêntico à sequencial."
