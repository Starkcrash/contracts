#!/bin/bash

# Load environment variables
source ../.env

echo "Whitelisting game..."
INVOKE_OUTPUT=$(sncast --account $ACCOUNT_NAME invoke \
    --url "$RPC_URL" \
    --contract-address "$CONTROLLER_CONTRACT_ADDRESS" \
    --function "whitelist_game" \
    --calldata "$ROULETTE_CONTRACT_ADDRESS" "$ROULETTE_MINBET 0" "$ROULETTE_MAXBET 0"\
    )

# Extract transaction hash
TX_HASH=$(echo "$INVOKE_OUTPUT" | grep "transaction_hash:" | awk '{print $2}')

echo "Whitelisting game transaction hash: $TX_HASH"