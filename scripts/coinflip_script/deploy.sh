#!/usr/bin/env bash
set -euo pipefail

# Load env
source ../.env

: "${COINFLIP_CLASS_HASH:=$CLASS_HASH}"

echo "🔨 Deploying CoinFlipGame contract..."
DEPLOY_OUTPUT=$(
  sncast --account "$ACCOUNT_NAME" deploy \
    --url "$RPC_URL" \
    --class-hash "$COINFLIP_CLASS_HASH" \
    --constructor-calldata "$OPERATOR_ADDRESS" "$CONTROLLER_CONTRACT_ADDRESS"
)

NEW_ADDRESS=$(printf "%s\n" "$DEPLOY_OUTPUT" | grep "contract_address:" | awk '{print $2}')
echo "→ contract address: $NEW_ADDRESS"

if [[ -n "$NEW_ADDRESS" ]]; then
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "s|COINFLIP_CONTRACT_ADDRESS=.*|COINFLIP_CONTRACT_ADDRESS=\"$NEW_ADDRESS\"|" ../.env
  else
    sed -i "s|COINFLIP_CONTRACT_ADDRESS=.*|COINFLIP_CONTRACT_ADDRESS=\"$NEW_ADDRESS\"|" ../.env
  fi
  echo "✓ Updated COINFLIP_CONTRACT_ADDRESS in .env"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [[ -f coinflip-deploy-info.json ]]; then
  jq \
    --arg ch "$COINFLIP_CLASS_HASH" \
    --arg ca "$NEW_ADDRESS" \
    --arg dt "$TIMESTAMP" \
    '.deployments = [ {classHash:$ch,contractAddress:$ca,deployedAt:$dt} ] + .deployments' \
    coinflip-deploy-info.json > tmp.$$.json && mv tmp.$$.json coinflip-deploy-info.json
else
  cat > coinflip-deploy-info.json <<EOF
{
  "deployments": [
    {
      "classHash": "$COINFLIP_CLASS_HASH",
      "contractAddress": "$NEW_ADDRESS",
      "deployedAt": "$TIMESTAMP"
    }
  ]
}
EOF
fi

echo "✅ Deployment complete."