#!/bin/bash

source ../.env

echo "Setting new max bet..."
INVOKE_OUTPUT=$(sncast --account $ACCOUNT_NAME invoke \
    --url "$RPC_URL" \
    --contract-address "$CONTROLLER_CONTRACT_ADDRESS" \
    --function "set_max_bet" \
    --calldata "$CRASH_CONTRACT_ADDRESS $MAX_BET 0" \
    --fee-token "$FEE_TOKEN")

TX_HASH=$(echo "$INVOKE_OUTPUT" | grep "transaction_hash:" | awk '{print $2}')

echo "✓ Set max bet transaction hash: $TX_HASH"