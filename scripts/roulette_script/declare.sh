#!/usr/bin/env bash
set -euo pipefail

source ../.env

if [[ -n "${ROULETTE_CLASS_HASH//\"/}" ]]; then
  echo "ℹ️  CLASS_HASH is already set in .env:"
  echo "   $ROULETTE_CLASS_HASH"
  NEW_CLASS_HASH="$ROULETTE_CLASS_HASH"
else
  echo "📝 CLASS_HASH not set—declaring RouletteGame contract..."
  DECLARE_OUTPUT=$(
    sncast --account "$ACCOUNT_NAME" declare \
      --url "$RPC_URL" \
      --contract-name RouletteGame
  )
  NEW_CLASS_HASH=$(printf "%s\n" "$DECLARE_OUTPUT" | grep "class_hash:" | awk '{print $2}')
  echo "→ Declared new class hash: $NEW_CLASS_HASH"

  # Write it back to CLASS_HASH in .env
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "s|ROULETTE_CLASS_HASH=.*|ROULETTE_CLASS_HASH=\"$NEW_CLASS_HASH\"|" ../.env
  else
    sed -i "s|ROULETTE_CLASS_HASH=.*|ROULETTE_CLASS_HASH=\"$NEW_CLASS_HASH\"|" ../.env
  fi
  echo "✓ Updated ROULETTE_CLASS_HASH in .env"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [[ -f roulette-declare-info.json ]]; then
  jq \
    --arg ch "$NEW_CLASS_HASH" --arg dt "$TIMESTAMP" \
    '.declarations = [ {classHash:$ch,declaredAt:$dt} ] + .declarations' \
    roulette-declare-info.json > tmp.$$.json && mv tmp.$$.json roulette-declare-info.json
else
  cat > roulette-declare-info.json <<EOF
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

echo "✅ declare.sh complete (class hash = $NEW_CLASS_HASH)"
