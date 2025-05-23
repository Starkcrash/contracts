#!/bin/bash
source ../.env

# Run declare script
./crashgame_script/declare.sh

echo "Waiting 15 seconds before upgrading..."
sleep 15

# Run upgrade script
./crashgame_script/upgrade_contract.sh
