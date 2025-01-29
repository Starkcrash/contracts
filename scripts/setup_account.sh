#!/bin/bash

# Load environment variables
source ../.env

echo "Importing account..."
IMPORT_OUTPUT=$(sncast account import \
    --url "$RPC_URL" \
    --name "$ACCOUNT_NAME" \
    --address "$ADDRESS" \
    --private-key "$PK" \
    --type argent)

echo "Account imported successfully!"