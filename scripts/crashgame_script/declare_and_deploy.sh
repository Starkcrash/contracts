#!/bin/bash
source ../.env

# Run declare script
./crashgame_script/declare.sh

echo "Waiting 30 seconds before deploying..."
sleep 30

# Run upgrade script
./crashgame_script/deploy.sh


echo "⏳ Waiting 20s for network to index the deployment…"
sleep 20

./crashgame_script/whitelist_game.sh