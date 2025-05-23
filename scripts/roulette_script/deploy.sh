#!/usr/bin/env bash
set -euo pipefail

# Load env
source ../.env

: "${ROULETTE_CLASS_HASH:=$CLASS_HASH}"

echo "🔨 Deploying RouletteGame contract..."
DEPLOY_OUTPUT=$(
  sncast --account "$ACCOUNT_NAME" deploy \
    --url "$RPC_URL" \
    --class-hash "$ROULETTE_CLASS_HASH" \
    --constructor-calldata "$OPERATOR_ADDRESS" "$CONTROLLER_CONTRACT_ADDRESS"
)

NEW_ADDRESS=$(printf "%s\n" "$DEPLOY_OUTPUT" | grep "contract_address:" | awk '{print $2}')
echo "→ contract address: $NEW_ADDRESS"

if [[ -n "$NEW_ADDRESS" ]]; then
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "s|ROULETTE_CONTRACT_ADDRESS=.*|ROULETTE_CONTRACT_ADDRESS=\"$NEW_ADDRESS\"|" ../.env
  else
    sed -i "s|ROULETTE_CONTRACT_ADDRESS=.*|ROULETTE_CONTRACT_ADDRESS=\"$NEW_ADDRESS\"|" ../.env
  fi
  echo "✓ Updated ROULETTE_CONTRACT_ADDRESS in .env"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [[ -f roulette-deploy-info.json ]]; then
  jq \
    --arg ch "$ROULETTE_CLASS_HASH" \
    --arg ca "$NEW_ADDRESS" \
    --arg dt "$TIMESTAMP" \
    '.deployments = [ {classHash:$ch,contractAddress:$ca,deployedAt:$dt} ] + .deployments' \
    roulette-deploy-info.json > tmp.$$.json && mv tmp.$$.json roulette-deploy-info.json
else
  cat > roulette-deploy-info.json <<EOF
{
  "deployments": [
    {
      "classHash": "$ROULETTE_CLASS_HASH",
      "contractAddress": "$NEW_ADDRESS",
      "deployedAt": "$TIMESTAMP"
    }
  ]
}
EOF
fi

echo "✅ Deployment complete."
