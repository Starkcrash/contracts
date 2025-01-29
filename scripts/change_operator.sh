#!/bin/bash

# Load environment variables
source ../.env

echo "Setting new operator..."
INVOKE_OUTPUT=$(sncast --account $ACCOUNT_NAME invoke \
    --url "$RPC_URL" \
    --contract-address "$CONTRACT_ADDRESS" \
    --function "set_operator" \
    --calldata "$OPERATOR_ADDRESS" \
    --fee-token eth)

# Extract transaction hash
TX_HASH=$(echo "$INVOKE_OUTPUT" | grep "transaction_hash:" | awk '{print $2}')

echo "Set operator transaction hash: $TX_HASH"