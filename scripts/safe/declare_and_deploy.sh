#!/usr/bin/env bash
set -euo pipefail


source ../.env

echo "🚀 Starting Safe rollout…"
./safe/declare.sh

echo "⏳ Waiting 20s for network to index the class…"
sleep 20

./safe/deploy.sh
