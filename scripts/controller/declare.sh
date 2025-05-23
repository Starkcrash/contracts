#!/usr/bin/env bash
set -euo pipefail

source ../.env

if [[ -n "${CONTROLLER_CLASS_HASH//\"/}" ]]; then
  echo "ℹ️  CONTROLLER_CLASS_HASH is already set in .env:"
  echo "   $CONTROLLER_CLASS_HASH"
  NEW_CLASS_HASH="$CONTROLLER_CLASS_HASH"
else
  echo "📝 CONTROLLER_CLASS_HASH not set—declaring Controller contract..."
  DECLARE_OUTPUT=$(
    sncast --account "$ACCOUNT_NAME" declare \
      --url "$RPC_URL" \
      --contract-name Controller
  )
  NEW_CLASS_HASH=$(printf "%s\n" "$DECLARE_OUTPUT" | grep "class_hash:" | awk '{print $2}')
  echo "→ Declared new class hash: $NEW_CLASS_HASH"

  # Write it back to CLASS_HASH in .env
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "s|CONTROLLER_CLASS_HASH=.*|CONTROLLER_CLASS_HASH=\"$NEW_CLASS_HASH\"|" ../.env
  else
    sed -i "s|CONTROLLER_CLASS_HASH=.*|CONTROLLER_CLASS_HASH=\"$NEW_CLASS_HASH\"|" ../.env
  fi
  echo "✓ Updated CONTROLLER_CLASS_HASH in .env"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [[ -f controller-declare-info.json ]]; then
  jq \
    --arg ch "$NEW_CLASS_HASH" --arg dt "$TIMESTAMP" \
    '.declarations = [ {classHash:$ch,declaredAt:$dt} ] + .declarations' \
    controller-declare-info.json > tmp.$$.json && mv tmp.$$.json controller-declare-info.json
else
  cat > controller-declare-info.json <<EOF
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

echo "✅ Controller declaration complete (class hash = $NEW_CLASS_HASH)"
