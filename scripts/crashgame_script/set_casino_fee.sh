#!/bin/bash

source ../.env

echo "Setting new casino fee..."
INVOKE_OUTPUT=$(sncast --account $ACCOUNT_NAME invoke \
    --url "$RPC_URL" \
    --contract-address "$CRASH_CONTRACT_ADDRESS" \
    --function "set_casino_fee_basis_points" \
    --calldata "500 0" \
    --fee-token "$FEE_TOKEN")

TX_HASH=$(echo "$INVOKE_OUTPUT" | grep "transaction_hash:" | awk '{print $2}')

echo "Set casino fee transaction hash: $TX_HASH"