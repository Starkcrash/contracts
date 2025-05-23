#!/usr/bin/env bash
set -euo pipefail

source ../.env

cat <<'EOF'
 ██████╗ ██████╗ ██╗███╗   ██╗███████╗██╗     ██╗██████╗ 
██╔════╝██╔═══██╗██║████╗  ██║██╔════╝██║     ██║██╔══██╗
██║     ██║   ██║██║██╔██╗ ██║█████╗  ██║     ██║██████╔╝
██║     ██║   ██║██║██║╚██╗██║██╔══╝  ██║     ██║██╔═══╝ 
╚██████╗╚██████╔╝██║██║ ╚████║██║     ███████╗██║██║     
 ╚═════╝ ╚═════╝ ╚═╝╚═╝  ╚═══╝╚═╝     ╚══════╝╚═╝╚═╝     
                                                         
██╗      █████╗ ██╗   ██╗███╗   ██╗ ██████╗██╗  ██╗      
██║     ██╔══██╗██║   ██║████╗  ██║██╔════╝██║  ██║      
██║     ███████║██║   ██║██╔██╗ ██║██║     ███████║      
██║     ██╔══██║██║   ██║██║╚██╗██║██║     ██╔══██║      
███████╗██║  ██║╚██████╔╝██║ ╚████║╚██████╗██║  ██║      
╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝                
EOF

echo "🚀 Starting CoinFlipGame rollout…"
./coinflip_script/declare.sh

echo "⏳ Waiting 30s for network to index the class…"
sleep 30

./coinflip_script/deploy.sh

echo "⏳ Waiting 20s for network to index the deployment…"
sleep 20

./coinflip_script/whitelist_game.sh