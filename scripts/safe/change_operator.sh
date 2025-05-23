#!/bin/bash

# Load environment variables
source ../.env

echo "Setting new operator..."
INVOKE_OUTPUT=$(sncast --account $ACCOUNT_NAME invoke \
    --url "$RPC_URL" \
    --contract-address "$SAFE_CONTRACT_ADDRESS" \
    --function "transfer_ownership" \
    --calldata "$OPERATOR_ADDRESS" \
    --fee-token "$FEE_TOKEN")

# Extract transaction hash
TX_HASH=$(echo "$INVOKE_OUTPUT" | grep "transaction_hash:" | awk '{print $2}')

echo "Set operator transaction hash: $TX_HASH"