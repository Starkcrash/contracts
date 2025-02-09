#!/bin/bash
source ../.env

# Run declare script
./declare.sh

# Wait 15 seconds between declare and deploy
echo "Waiting 15 seconds before deploying..."
sleep 15

# Run upgrade script
./deploy.sh