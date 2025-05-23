#!/usr/bin/env bash
set -euo pipefail

source ../.env

if [[ -n "${COINFLIP_CLASS_HASH//\"/}" ]]; then
  echo "ℹ️  COINFLIP_CLASS_HASH is already set in .env:"
  echo "   $COINFLIP_CLASS_HASH"
  NEW_CLASS_HASH="$COINFLIP_CLASS_HASH"
else
  echo "📝 COINFLIP_CLASS_HASH not set—declaring CoinFlipGame contract..."
  DECLARE_OUTPUT=$(
    sncast --account "$ACCOUNT_NAME" declare \
      --url "$RPC_URL" \
      --contract-name CoinFlipGame
  )
  NEW_CLASS_HASH=$(printf "%s\n" "$DECLARE_OUTPUT" | grep "class_hash:" | awk '{print $2}')
  echo "→ Declared new class hash: $NEW_CLASS_HASH"

  # Write it back to COINFLIP_CLASS_HASH in .env
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "s|COINFLIP_CLASS_HASH=.*|COINFLIP_CLASS_HASH=\"$NEW_CLASS_HASH\"|" ../.env
  else
    sed -i "s|COINFLIP_CLASS_HASH=.*|COINFLIP_CLASS_HASH=\"$NEW_CLASS_HASH\"|" ../.env
  fi
  echo "✓ Updated COINFLIP_CLASS_HASH in .env"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [[ -f coinflip-declare-info.json ]]; then
  jq \
    --arg ch "$NEW_CLASS_HASH" --arg dt "$TIMESTAMP" \
    '.declarations = [ {classHash:$ch,declaredAt:$dt} ] + .declarations' \
    coinflip-declare-info.json > tmp.$$.json && mv tmp.$$.json coinflip-declare-info.json
else
  cat > coinflip-declare-info.json <<EOF
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
