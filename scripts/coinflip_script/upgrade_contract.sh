#!/bin/bash

# Exit on error
set -e

source ../.env

# Check if NEW_CLASS_HASH is set
if [ -z "$COINFLIP_CLASS_HASH" ]; then
    echo "Error: COINFLIP_CLASS_HASH is not set in .env"
    exit 1
fi

echo "Upgrading contract..."
INVOKE_OUTPUT=$(sncast --account $ACCOUNT_NAME invoke \
    --url "$RPC_URL" \
    --contract-address "$COINFLIP_CONTRACT_ADDRESS" \
    --function "upgrade" \
    --calldata "$COINFLIP_CLASS_HASH")

# Extract transaction hash
TX_HASH=$(echo "$INVOKE_OUTPUT" | grep "transaction_hash:" | awk '{print $2}')

if [ -z "$TX_HASH" ]; then
    echo "Error: Failed to extract transaction hash from output"
    exit 1
fi

echo "✓ New upgrade transaction hash: $TX_HASH"