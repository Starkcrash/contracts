#!/usr/bin/env bash
set -euo pipefail

# Load environment variables
source ../.env

# Check if CRASH_CLASS_HASH is already set
if [[ -n "${CRASH_CLASS_HASH//\"/}" ]]; then
  echo "ℹ️  CRASH_CLASS_HASH is already set in .env:"
  echo "   $CRASH_CLASS_HASH"
  NEW_CLASS_HASH="$CRASH_CLASS_HASH"
else
  echo "📝 CRASH_CLASS_HASH not set—declaring CrashGame contract..."
  # Declare contract
  DECLARE_OUTPUT=$(sncast --account "$ACCOUNT_NAME" declare \
    --url "$RPC_URL" \
    --contract-name CrashGame)

  # Extract class hash
  NEW_CLASS_HASH=$(printf "%s\n" "$DECLARE_OUTPUT" | grep "class_hash:" | awk '{print $2}')

  echo "→ Declared new class hash: $NEW_CLASS_HASH"

  # Update the class hash in .env
  if [ -n "$NEW_CLASS_HASH" ]; then
      if [[ "$OSTYPE" == "darwin"* ]]; then
          # macOS
          sed -i '' "s|CRASH_CLASS_HASH=.*|CRASH_CLASS_HASH=\"$NEW_CLASS_HASH\"|" ../.env
      else
          # Linux and others
          sed -i "s|CRASH_CLASS_HASH=.*|CRASH_CLASS_HASH=\"$NEW_CLASS_HASH\"|" ../.env
      fi
      echo "✓ Updated CRASH_CLASS_HASH in .env"
  fi
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [[ -f crash-declare-info.json ]]; then
  jq \
    --arg ch "$NEW_CLASS_HASH" --arg dt "$TIMESTAMP" \
    '.declarations = [ {classHash:$ch,declaredAt:$dt} ] + .declarations' \
    crash-declare-info.json > tmp.$$.json && mv tmp.$$.json crash-declare-info.json
else
  cat > crash-declare-info.json <<EOF
{
  "declarations": [
    {
      "classHash": "$NEW_CLASS_HASH",
      "declaredAt": "$TIMESTAMP"
    }
  ]
}
EOF
fi

echo "✅ declare.sh for CrashGame complete (class hash = $NEW_CLASS_HASH)"