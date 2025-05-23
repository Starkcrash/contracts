#!/usr/bin/env bash
set -euo pipefail

# Load env
source ../.env

: "${CONTROLLER_CLASS_HASH:=$CONTROLLER_CLASS_HASH}"

echo "🔨 Deploying Controller contract..."

DEPLOY_OUTPUT=$(
  sncast --account "$ACCOUNT_NAME" deploy \
    --url "$RPC_URL" \
    --class-hash "$CONTROLLER_CLASS_HASH" \
    --constructor-calldata "$OPERATOR_ADDRESS" "$SAFE_CONTRACT_ADDRESS"
)

NEW_ADDRESS=$(printf "%s\n" "$DEPLOY_OUTPUT" | grep "contract_address:" | awk '{print $2}')
echo "→ contract address: $NEW_ADDRESS"

if [[ -n "$NEW_ADDRESS" ]]; then
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "s|CONTROLLER_CONTRACT_ADDRESS=.*|CONTROLLER_CONTRACT_ADDRESS=\"$NEW_ADDRESS\"|" ../.env
  else
    sed -i "s|CONTROLLER_CONTRACT_ADDRESS=.*|CONTROLLER_CONTRACT_ADDRESS=\"$NEW_ADDRESS\"|" ../.env
  fi
  echo "✓ Updated CONTROLLER_CONTRACT_ADDRESS in .env"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [[ -f controller-deploy-info.json ]]; then
  jq \
    --arg ch "$CONTROLLER_CLASS_HASH" \
    --arg ca "$NEW_ADDRESS" \
    --arg dt "$TIMESTAMP" \
    '.deployments = [ {classHash:$ch,contractAddress:$ca,deployedAt:$dt} ] + .deployments' \
    controller-deploy-info.json > tmp.$$.json && mv tmp.$$.json controller-deploy-info.json
else
  cat > controller-deploy-info.json <<EOF
{
  "deployments": [
    {
      "classHash": "$CONTROLLER_CLASS_HASH",
      "contractAddress": "$NEW_ADDRESS",
      "deployedAt": "$TIMESTAMP"
    }
  ]
}
EOF
fi

echo "✅ Controller deployment complete."
