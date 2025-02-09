#!/bin/bash
source ../.env

# Run declare script
./declare.sh

echo "Waiting 15 seconds before upgrading..."
sleep 15

# Run upgrade script
./upgrade_contract.sh
