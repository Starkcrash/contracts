#!/bin/bash

# Load environment variables
source ../.env

echo "Whitelisting coinflip game..."
INVOKE_OUTPUT=$(sncast --account $ACCOUNT_NAME invoke \
    --url "$RPC_URL" \
    --contract-address "$CONTROLLER_CONTRACT_ADDRESS" \
    --function "whitelist_game" \
    --calldata "$COINFLIP_CONTRACT_ADDRESS" "$COINFLIP_MINBET 0" "$COINFLIP_MAXBET 0"\
    )

# Extract transaction hash
TX_HASH=$(echo "$INVOKE_OUTPUT" | grep "transaction_hash:" | awk '{print $2}')

echo "Whitelisting game transaction hash: $TX_HASH"