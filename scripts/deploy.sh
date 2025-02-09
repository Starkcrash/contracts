#!/bin/bash

# Load environment variables
source ../.env

# Deploy contract
echo "Deploying contract..."
DEPLOY_OUTPUT=$(sncast --account $ACCOUNT_NAME deploy \
  --url "$RPC_URL" \
  --fee-token "$FEE_TOKEN" \
  --class-hash $CLASS_HASH \
  --constructor-calldata $OPERATOR_ADDRESS $CASINO_ADDRESS)

# Extract contract address
CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "contract_address:" | awk '{print $2}')

echo "Contract deployed at address: $CONTRACT_ADDRESS"

# Save deployment info with history
if [ -f deploy-info.json ]; then
    # File exists, read existing deployments
    DEPLOYMENTS=$(cat deploy-info.json)
    echo "{
      \"deployments\": [
        {
          \"classHash\": \"$CLASS_HASH\",
          \"contractAddress\": \"$CONTRACT_ADDRESS\",
          \"deployedAt\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
        },
        $DEPLOYMENTS
      ]
    }" > deploy-info.json
else
    # First deployment
    echo "{
      \"deployments\": [
        {
          \"classHash\": \"$CLASS_HASH\",
          \"contractAddress\": \"$CONTRACT_ADDRESS\",
          \"deployedAt\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
        }
      ]
    }" > deploy-info.json
fi

echo "Deployment info saved to deploy-info.json"