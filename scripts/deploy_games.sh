
source ../.env


# 1 . DEPLOY CRASH
echo "🚀 Declaring and deploying Crash..."
./crashgame_script/declare_and_deploy.sh

#2. DEPLOY COINFLIP
echo "🚀 Declaring and deploying Coinflip..."
./coinflip_script/declare_and_deploy.sh

#3 DEPLOY ROULETTE
echo "🚀 Declaring and deploying Roulette..."
./roulette_script/declare_and_deploy.sh

