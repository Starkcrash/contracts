#!/bin/bash

# Load environment variables
source ../.env

# Declare contract
echo "Declaring contract..."
DECLARE_OUTPUT=$(sncast --account $ACCOUNT_NAME declare \
  --url "$RPC_URL" \
  --fee-token "$FEE_TOKEN" \
  --contract-name CrashGame)

# Extract class hash
NEW_CLASS_HASH=$(echo "$DECLARE_OUTPUT" | grep "class_hash:" | awk '{print $2}')

echo "Contract declared with class hash: $NEW_CLASS_HASH"

# Update the class hash in .env
if [ -n "$NEW_CLASS_HASH" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|CLASS_HASH=.*|CLASS_HASH=\"$NEW_CLASS_HASH\"|" ../.env
    else
        # Linux and others
        sed -i "s|CLASS_HASH=.*|CLASS_HASH=\"$NEW_CLASS_HASH\"|" ../.env
    fi
    echo "Updated class hash in .env"
fi

if [ -f declare-info.json ]; then
    # File exists, read existing declarations
    DECLARATIONS=$(cat declare-info.json)
    echo "{
      \"declarations\": [
        {
          \"classHash\": \"$NEW_CLASS_HASH\",
          \"declaredAt\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
        },
        $DECLARATIONS
      ]
    }" > declare-info.json
else
    # First declaration
    echo "{
      \"declarations\": [
        {
          \"classHash\": \"$NEW_CLASS_HASH\",
          \"declaredAt\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
        }
      ]
    }" > declare-info.json
fi

echo "Declaration info saved to declare-info.json"