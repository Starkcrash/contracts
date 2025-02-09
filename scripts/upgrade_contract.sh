#!/bin/bash

# Exit on error
set -e

source ../.env

# Check if NEW_CLASS_HASH is set
if [ -z "$CLASS_HASH" ]; then
    echo "Error: CLASS_HASH is not set in .env"
    exit 1
fi

echo "Upgrading contract..."
INVOKE_OUTPUT=$(sncast --account $ACCOUNT_NAME invoke \
    --url "$RPC_URL" \
    --contract-address "$CONTRACT_ADDRESS" \
    --function "upgrade" \
    --calldata "$CLASS_HASH" \
    --fee-token "$FEE_TOKEN")

# Extract transaction hash
TX_HASH=$(echo "$INVOKE_OUTPUT" | grep "transaction_hash:" | awk '{print $2}')

if [ -z "$TX_HASH" ]; then
    echo "Error: Failed to extract transaction hash from output"
    exit 1
fi

echo "New upgrade transaction hash: $TX_HASH"