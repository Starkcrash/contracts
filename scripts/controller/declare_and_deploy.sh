#!/usr/bin/env bash
set -euo pipefail


source ../.env

echo "🚀 Starting controller declaration and deployment..."
./controller/declare.sh

echo "⏳ Waiting 25s for network to index the class…"
sleep 25

./controller/deploy.sh

echo "🚀 Controller declaration and deployment completed successfully!"
