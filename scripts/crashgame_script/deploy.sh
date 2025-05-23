#!/usr/bin/env bash
set -euo pipefail

# Load environment variables
source ../.env

# Ensure CRASH_CLASS_HASH is available from .env
: "${CRASH_CLASS_HASH:?CRASH_CLASS_HASH is not set in .env. Please run the declare script first.}"

echo "🔨 Deploying CrashGame contract..."
DEPLOY_OUTPUT=$(
  sncast --account "$ACCOUNT_NAME" deploy \
    --url "$RPC_URL" \
    --class-hash "$CRASH_CLASS_HASH" \
    --constructor-calldata "$OPERATOR_ADDRESS" "$CONTROLLER_CONTRACT_ADDRESS"
)

# Extract contract address
NEW_CRASH_ADDRESS=$(printf "%s\n" "$DEPLOY_OUTPUT" | grep "contract_address:" | awk '{print $2}')

echo "→ Contract deployed at address: $NEW_CRASH_ADDRESS"

# Update the contract address in .env
if [ -n "$NEW_CRASH_ADDRESS" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|CRASH_CONTRACT_ADDRESS=.*|CRASH_CONTRACT_ADDRESS=\"$NEW_CRASH_ADDRESS\"|" ../.env
    else
        # Linux and others
        sed -i "s|CRASH_CONTRACT_ADDRESS=.*|CRASH_CONTRACT_ADDRESS=\"$NEW_CRASH_ADDRESS\"|" ../.env
    fi
    echo "✓ Updated CRASH_CONTRACT_ADDRESS in .env"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [[ -f crash-deploy-info.json ]]; then
  jq \
    --arg ch "$CRASH_CLASS_HASH" \
    --arg ca "$NEW_CRASH_ADDRESS" \
    --arg dt "$TIMESTAMP" \
    '.deployments = [ {classHash:$ch,contractAddress:$ca,deployedAt:$dt} ] + .deployments' \
    crash-deploy-info.json > tmp.$$.json && mv tmp.$$.json crash-deploy-info.json
else
  cat > crash-deploy-info.json <<EOF
{
  "deployments": [
    {
      "classHash": "$CRASH_CLASS_HASH",
      "contractAddress": "$NEW_CRASH_ADDRESS",
      "deployedAt": "$TIMESTAMP"
    }
  ]
}
EOF
fi

echo "✅ Deployment of CrashGame complete. Contract address: $NEW_CRASH_ADDRESS"