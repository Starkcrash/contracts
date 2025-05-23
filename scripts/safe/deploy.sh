#!/usr/bin/env bash
set -euo pipefail

# Load env
source ../.env

: "${SAFE_CLASS_HASH:=$SAFE_CLASS_HASH}"

echo "🔨 Deploying Safe contract..."
DEPLOY_OUTPUT=$(
  sncast --account "$ACCOUNT_NAME" deploy \
    --url "$RPC_URL" \
    --class-hash "$SAFE_CLASS_HASH" \
    --constructor-calldata "$OPERATOR_ADDRESS" "$MULTISIG_ADDRESS"
)

NEW_ADDRESS=$(printf "%s\n" "$DEPLOY_OUTPUT" | grep "contract_address:" | awk '{print $2}')
echo "→ contract address: $NEW_ADDRESS"

if [[ -n "$NEW_ADDRESS" ]]; then
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "s|SAFE_CONTRACT_ADDRESS=.*|SAFE_CONTRACT_ADDRESS=\"$NEW_ADDRESS\"|" ../.env
  else
    sed -i "s|SAFE_CONTRACT_ADDRESS=.*|SAFE_CONTRACT_ADDRESS=\"$NEW_ADDRESS\"|" ../.env
  fi
  echo "✓ Updated SAFE_CONTRACT_ADDRESS in .env"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [[ -f safe-deploy-info.json ]]; then
  jq \
    --arg ch "$SAFE_CLASS_HASH" \
    --arg ca "$NEW_ADDRESS" \
    --arg dt "$TIMESTAMP" \
    '.deployments = [ {classHash:$ch,contractAddress:$ca,deployedAt:$dt} ] + .deployments' \
    safe-deploy-info.json > tmp.$$.json && mv tmp.$$.json safe-deploy-info.json
else
  cat > safe-deploy-info.json <<EOF
{
  "deployments": [
    {
      "classHash": "$SAFE_CLASS_HASH",
      "contractAddress": "$NEW_ADDRESS",
      "deployedAt": "$TIMESTAMP"
    }
  ]
}
EOF
fi

echo "✅ Deployment complete."
