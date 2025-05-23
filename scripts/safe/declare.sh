#!/usr/bin/env bash
set -euo pipefail

source ../.env

if [[ -n "${SAFE_CLASS_HASH//\"/}" ]]; then
  echo "ℹ️  CLASS_HASH is already set in .env:"
  echo "   $SAFE_CLASS_HASH"
  NEW_CLASS_HASH="$SAFE_CLASS_HASH"
else
  echo "📝 CLASS_HASH not set—declaring Safe contract..."
  DECLARE_OUTPUT=$(
    sncast --account "$ACCOUNT_NAME" declare \
      --url "$RPC_URL" \
      --contract-name Safe
  )
  NEW_CLASS_HASH=$(printf "%s\n" "$DECLARE_OUTPUT" | grep "class_hash:" | awk '{print $2}')
  echo "→ Declared new class hash: $NEW_CLASS_HASH"

  # Write it back to CLASS_HASH in .env
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "s|SAFE_CLASS_HASH=.*|SAFE_CLASS_HASH=\"$NEW_CLASS_HASH\"|" ../.env
  else
    sed -i "s|SAFE_CLASS_HASH=.*|SAFE_CLASS_HASH=\"$NEW_CLASS_HASH\"|" ../.env
  fi
  echo "✓ Updated SAFE_CLASS_HASH in .env"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [[ -f safe-declare-info.json ]]; then
  jq \
    --arg ch "$NEW_CLASS_HASH" --arg dt "$TIMESTAMP" \
    '.declarations = [ {classHash:$ch,declaredAt:$dt} ] + .declarations' \
    safe-declare-info.json > tmp.$$.json && mv tmp.$$.json safe-declare-info.json
else
  cat > safe-declare-info.json <<EOF
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
